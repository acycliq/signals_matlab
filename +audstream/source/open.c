#include "reoml.h"

int done(Packet *packet);
static int paCallback(
        const void*                     inputBuffer,
        void*                           outputBuffer,
        unsigned long                   framesPerBuffer,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags           statusFlags,
        void*                           userData);

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
  PaError err;
  PaStreamParameters outputParameters;
  PacketStream *stream = &packetStreams[nStreams];
  Packet emptyPacket = {0};
  
  if ( !portAudioInitialized ) {
    LoadLibrary("portaudio_x86.dll");
    err = Pa_Initialize();
    if( err != paNoError ) goto error;
    portAudioInitialized = TRUE;
    mexPrintf("Initialised PortAudio\n");
  }
  
  // initialise buffering system
  stream->incomingPacketsData = mxMalloc(sizeof(Packet) * RING_BUFFER_SIZE);
  PaUtil_InitializeRingBuffer(&stream->incomingPackets, sizeof(Packet), 
          RING_BUFFER_SIZE, stream->incomingPacketsData);
  mexMakeMemoryPersistent(stream->incomingPacketsData);
  
  stream->usedPacketsData = mxMalloc(sizeof(Packet) * RING_BUFFER_SIZE);
  PaUtil_InitializeRingBuffer(&stream->usedPackets, sizeof(Packet), 
          RING_BUFFER_SIZE, stream->usedPacketsData);
  mexMakeMemoryPersistent(stream->usedPacketsData);
  
  /*
  // put an empty packet into incoming
  emptyPacket.buffer = mxMalloc(0);
  mexMakeMemoryPersistent(emptyPacket.buffer);
  PaUtil_WriteRingBuffer(&stream->incomingPackets, &emptyPacket, 1);
  //todo: use mxatexit to free memory allocated above
  */
  
  /* default output device */
  outputParameters.device = Pa_GetDefaultOutputDevice();
  if (outputParameters.device == paNoDevice) {
    mexErrMsgIdAndTxt("reo:NoPortAudioDevices", "No default audio devices");
    return;
  }
  
  outputParameters.channelCount = NCHANS;       /* stereo output */
  outputParameters.sampleFormat = paFloat32; /* 32 bit floating point output */
  outputParameters.suggestedLatency =
          Pa_GetDeviceInfo( outputParameters.device )->defaultLowOutputLatency;
  outputParameters.hostApiSpecificStreamInfo = NULL;
  
  err = Pa_OpenStream(
          &stream->paStream,
          NULL, /* no input */
          &outputParameters,
          SAMPLE_RATE,
          FRAMES_PER_BUFFER,
          paNoFlag,
          paCallback,
          stream);
  if( err != paNoError ) goto error;
  mexPrintf("Stream id = %u, ptr = %u\n", nStreams, stream->paStream);
  
  plhs[0] = mxCreateDoubleScalar(nStreams++);
  
  mexPrintf("done\n");
  return;
  
  error:
    Pa_Terminate();
    mexErrMsgIdAndTxt("reo:PortAudioError", Pa_GetErrorText(err));
}

static int paCallback(
        const void*                     inputBuffer,
        void*                           outputBuffer,
        unsigned long                   framesPerBuffer,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags           statusFlags,
        void*                           userData)
{
  PacketStream *data = (PacketStream*)userData;
  float *out = (float*)outputBuffer;
  unsigned i, count;
  
  // zero the audio buffer
  memset(out, 0, framesPerBuffer*NCHANS*sizeof(float));
    
  count = NCHANS*framesPerBuffer;
  for (i = 0; i < count; i++) {
    if (done(&data->current)) {
      if (PaUtil_GetRingBufferReadAvailable(&data->incomingPackets)) {
        // put previous packet into used, take next incoming one
        PaUtil_WriteRingBuffer(&data->usedPackets, &data->current, 1);
        PaUtil_ReadRingBuffer(&data->incomingPackets, &data->current, 1);
      }
      if (done(&data->current)) { // still nothing new, so break
        break;
      }
    }
    (*out++) = data->current.buffer[data->current.pos++];
  }
  
  return  paContinue;
}
