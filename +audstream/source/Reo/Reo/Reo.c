// Reo.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "Reo.h"

#include "mex.h"

#define END(packet) ((packet)->pos >= (packet)->len)

Output* outputs = NULL;
PacketStream packetStreams[MAX_STREAMS] = { 0 };

BOOL portAudioInitialized = FALSE;

PaError initializeOutput(Output* out);

static int paCallback(
	const void*                     inputBuffer,
	void*                           outputBuffer,
	unsigned long                   framesPerBuffer,
	const PaStreamCallbackTimeInfo* timeInfo,
	PaStreamCallbackFlags           statusFlags,
	void*                           userData);

REO_API int reoOpen(double sampleRate, int nChans, int paDevIdx, double suggestedLatency)
{
	PaError err;
	PacketStream *stream;
	//Packet emptyPacket = { 0 };
	// checks and initialisation
	int streamIdx = firstFreeStream();
	if (streamIdx < 0) {
		mexErrMsgIdAndTxt("reo:NoFreeStreams", "No free stream slots");
		return -1;
	}	
	if (!portAudioInitialized) { // todo: handle this better
		//LoadLibrary("portaudio_x64.dll");
		err = Pa_Initialize();
		if (err != paNoError) goto error;
		portAudioInitialized = TRUE;
		mexPrintf("Initialised PortAudio\n");
	}
	if (paDevIdx < 0) {
		/* default output device */
		paDevIdx = Pa_GetDefaultOutputDevice();
		if (paDevIdx == paNoDevice) {
			mexErrMsgIdAndTxt("reo:NoPortAudioDevices", "No default audio devices");
			return -1;
		}
	}
	// find an output with same device/number of channels/sample rate/suggested latency
	Output* out = outputs;
	while (out != NULL) {
		if ((out->devId == paDevIdx) &&
			(out->nChans == nChans) &&
			(out->sampleRate == sampleRate) &&
			(out->suggestedLatency == suggestedLatency)) {
			break;
		}
		out = out->next;
	}
	if (!out) { // no matching output exists, so create a new one
		out = mxCalloc(1, sizeof(Output));
		out->devId = paDevIdx;
		out->nChans = nChans;
		out->sampleRate = sampleRate;
		out->suggestedLatency = suggestedLatency;
		err = initializeOutput(out);
		if (err != paNoError) { mxFree(out); goto error; }
		mexMakeMemoryPersistent(out);
		// prepend this output to the list
		if (outputs) {
			out->next = outputs;
			outputs->previous = out;
		}
		outputs = out;
		mexPrintf("Started output device (port audio id = %u)\n", streamIdx, out->devId);
	}
	stream = &packetStreams[streamIdx];
	stream->output = out;
	// initialise buffering system
	stream->incomingPacketsData = mxMalloc(sizeof(Packet)*RING_BUFFER_SIZE);
	PaUtil_InitializeRingBuffer(&stream->incomingPackets, sizeof(Packet),
		RING_BUFFER_SIZE, stream->incomingPacketsData);	
	stream->usedPacketsData = mxMalloc(sizeof(Packet)*RING_BUFFER_SIZE);
	PaUtil_InitializeRingBuffer(&stream->usedPackets, sizeof(Packet),
		RING_BUFFER_SIZE, stream->usedPacketsData);
	mexMakeMemoryPersistent(stream->incomingPacketsData);
	mexMakeMemoryPersistent(stream->usedPacketsData);
	// prepend this stream to output's stream list
	if (out->streams) {
		stream->next = out->streams;
		out->streams->previous = stream;
	}
	out->streams = stream; // should be atomic as streams is declared volatile
	stream->active = TRUE;
	mexPrintf("Stream id = %u, ptr = %u\n", streamIdx, stream->output->paOutputStream);
	mexPrintf("done\n");
	return streamIdx;

error:
	Pa_Terminate();
	mexErrMsgIdAndTxt("reo:PortAudioError", Pa_GetErrorText(err));
	return -1;
}

REO_API void reoCloseAll(void) {
	int i;

	for (i = 0; i < MAX_STREAMS; i++) {
		if (packetStreams[i].active) reoClose(i);
	}
}

REO_API void reoClose(int streamIdx)
{
	PaError err = paNoError;
	PacketStream *stream = &packetStreams[streamIdx];
	Output* out = stream->output;
	//mexPrintf("Stream id = %u, ptr = %u\n", streamIdx, out->paOutputStream);
	stream->playing = FALSE;// stop the stream playing
	// eliminate this stream from the output stream list
	if (stream->previous) {
		stream->previous->next = stream->next; // link previous to next
	}
	if (stream->next) {
		stream->next->previous = stream->previous; // link next back to previous
	}
	if (stream == out->streams) {
		out->streams = stream->next; // change head of list to next
	}
	// if it was the last stream of the output, close the output
	if (!out->streams) { // no streams left on this output
		// remove the output from the list and close
		if (out->previous) {
			out->previous->next = out->next; // link previous to next
		}
		if (out->next) {
			out->next->previous = out->previous; // link next back to previous
		}
		if (out == outputs) {
			outputs = out->next; // change head of list to next
		}
		err = Pa_CloseStream(out->paOutputStream); //close the PortAudio stream
		mexPrintf("Closed output device (port audio id = %u)\n", streamIdx, out->devId);
		mxFree(out); // free the memory for the output struct
	}
	
	//put current packet into the used queue, then cleanup all used
	PaUtil_WriteRingBuffer(&stream->usedPackets, &stream->current, 1);
	cleanupUsedPackets(streamIdx);
	//free the memory for the queues
	mxFree(stream->incomingPacketsData);
	mxFree(stream->usedPacketsData);
	memset(stream, 0, sizeof(*stream)); // zero the stream struct
	if (err != paNoError) goto error;
	mexPrintf("Cleaned up %d\n", streamIdx);

	if (portAudioInitialized && !anyStreamsActive()) {
		Pa_Terminate();
		portAudioInitialized = FALSE;
		mexPrintf("PortAudio shut down\n");
	}
	//mexPrintf("done\n");
	return;

error:
	mexErrMsgIdAndTxt("reo:PortAudioError", Pa_GetErrorText(err));
}

REO_API void reoStart(int streamIdx) {
	packetStreams[streamIdx].playing = true;
}

REO_API void reoStop(int streamIdx) {
	packetStreams[streamIdx].playing = false;
}

REO_API void reoPost(int streamIdx, float* data, size_t count) {
	PacketStream* stream = &packetStreams[streamIdx];
	Packet packet = { 0 };

	packet.buffer = data;
	packet.len = count;

	// copy the packet into incoming
	PaUtil_WriteRingBuffer(&stream->incomingPackets, &packet, 1);

	Output* out = stream->output;
	//mexPrintf("output header stream = %u, next stream = %u\n", out->streams, out->streams->next);

	//     mexPrintf("Posted packet on %u with %u elems (%u slots left)\n", 
	//             streamIdx, count, PaUtil_GetRingBufferWriteAvailable(&stream->incomingPackets));
	// cleanup used packets
	cleanupUsedPackets(streamIdx);
	return;
}

REO_API long reoUsedSlots(int streamIdx) {
	unsigned usedSlots;

	PacketStream* stream = &packetStreams[streamIdx];

	usedSlots = PaUtil_GetRingBufferReadAvailable(&stream->incomingPackets);

	return usedSlots;
}

REO_API long reoFreeSlots(int streamIdx) {
	unsigned freeSlots;

	PacketStream* stream = &packetStreams[streamIdx];

	freeSlots = PaUtil_GetRingBufferWriteAvailable(&stream->incomingPackets);

	return freeSlots;
}

REO_API BOOL reoValidStream(int streamIdx) {
	return (streamIdx >= 0) && (streamIdx < MAX_STREAMS) && packetStreams[streamIdx].active;
}

static int paCallback(
	const void*                     inputBuffer,
	void*                           outputBuffer,
	unsigned long                   framesPerBuffer,
	const PaStreamCallbackTimeInfo* timeInfo,
	PaStreamCallbackFlags           statusFlags,
	void*                           userData)
{
	Output *data = (Output*)userData;
	PacketStream* stream = data->streams;
	int nChans = data->nChans;
	unsigned count = nChans*framesPerBuffer;

	// zero the audio output buffer
	memset(outputBuffer, 0, framesPerBuffer*nChans*sizeof(float));

	while (stream) {
		if (stream->playing) {
			float *out = (float*)outputBuffer;
			unsigned i;
			for (i = 0; i < count; i++) {
				if (END(&stream->current)) {
					if (PaUtil_GetRingBufferReadAvailable(&stream->incomingPackets)) {
						// put previous packet into used, take next incoming one
						PaUtil_WriteRingBuffer(&stream->usedPackets, &stream->current, 1);
						PaUtil_ReadRingBuffer(&stream->incomingPackets, &stream->current, 1);
					}
					if (END(&stream->current)) { // still nothing new, so break
						break;
					}
				}
				(*out++) += stream->current.buffer[stream->current.pos++];
			}
		}
		stream = stream->next;
	}

	return paContinue;
}

void cleanupUsedPackets(unsigned streamIdx) {
	PaUtilRingBuffer *usedPacketsPtr = &packetStreams[streamIdx].usedPackets;
	while (PaUtil_GetRingBufferReadAvailable(usedPacketsPtr)) {
		Packet in;
		PaUtil_ReadRingBuffer(usedPacketsPtr, &in, 1);
		//     mexPrintf("[%.1f %.1f %.1f ... ]\n", in.buffer[0], in.buffer[1], in.buffer[2]);
		mxFree(in.buffer);
		//     mexPrintf("cleared %u\n", in.buffer);
	}
}

int firstFreeStream() {
	int i;

	for (i = 0; i < MAX_STREAMS; i++) {
		if (!packetStreams[i].active) return i;
	}
	return -1;
}

BOOL anyStreamsActive() {
	int i;
	for (i = 0; i < MAX_STREAMS; i++) {
		if (packetStreams[i].active) return TRUE;
	}
	return FALSE;
}

PaError initializeOutput(Output* out) {
	PaError err;
	PaStreamParameters outputParameters;
	outputParameters.device = out->devId;
	outputParameters.channelCount = out->nChans;
	outputParameters.sampleFormat = paFloat32; /* 32 bit floating point samples */
	outputParameters.suggestedLatency = out->suggestedLatency;// Pa_GetDeviceInfo(out->devId)->defaultLowOutputLatency;
	outputParameters.hostApiSpecificStreamInfo = NULL;
	err = Pa_OpenStream( /* open the stream */
		&out->paOutputStream,
		NULL, /* no input stream */
		&outputParameters,
		out->sampleRate,
		paFramesPerBufferUnspecified,
		paNoFlag,
		paCallback,
		out);
	if (err == paNoError) {
		err = Pa_StartStream(out->paOutputStream); // start the stream
	}
	return err;
}