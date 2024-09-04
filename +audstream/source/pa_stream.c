#include <stdio.h>

#include "Reo.h"

#include "windows.h"
#include "mex.h"

#define NUM_SECONDS   (1)
#define FREQ   (1000.0f)
#define NCHANS (2)
#define NELEMS(x)  (sizeof(x) / sizeof(x[0]))
#define SAMPLE_RATE   (44100)
#define FRAMES_PER_BUFFER  (64)

#ifndef M_PI
#define M_PI  (3.14159265)
#endif

// typedef struct
// {
//   unsigned pos;
//   unsigned len;
//   float* buffer;
// }
// Packet;
// 
// typedef struct
// {
//   Packet current;
//   PaUtilRingBuffer rBufToRT;
//   void* rBufToRTData;
//   PaUtilRingBuffer rBufFromRT;
//   void* rBufFromRTData;
//   unsigned callCount;
// }
// PaTestData;

int done(Packet packet);

static float vals[] = {.1f, .2f, .3f, .4f, .5f, .6f};

static int patestCallback(
        const void*                     inputBuffer,
        void*                           outputBuffer,
        unsigned long                   framesPerBuffer,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags           statusFlags,
        void*                           userData)
{
  PacketStream *data = (PacketStream*)userData;
  float *out = (float*)outputBuffer;
  int i;
  
  data->callCount++;
  
  // zero out the buffer
  memset(out, 0, framesPerBuffer*NCHANS*sizeof(float));
  
  if (done(data->current) && PaUtil_GetRingBufferReadAvailable(&data->incomingPackets))
  {
    Packet in;
    mexPrintf("new packet\n");
    PaUtil_ReadRingBuffer(&data->incomingPackets, &in, 1);
    data->current = in;
  } else { /*mexPrintf("no new packets\n");*/ }
  
  if (!done(data->current)) // current packet still working
  {
    int count = min(NCHANS*framesPerBuffer, data->current.len - data->current.pos);
    for (i = 0; i < count; i++)
    {
//       mexPrintf("storing %f\n", data->current.buffer[data->current.pos]);
      (*out++) = data->current.buffer[data->current.pos++];
    }
    if (done(data->current))
    {
      mexPrintf("done with packet, posting for cleanup\n");
      PaUtil_WriteRingBuffer(&data->usedPackets, &(data->current), 1);
    }
  }
  
  return  paContinue;
}

int done(Packet packet)
{
//   mexPrintf("%d >= %d\n", packet.pos, packet.len);
  return (packet.pos >= packet.len);
}

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
  PacketStream data = {0};
  Packet out = {0};
  Packet in = {0};
  
  PaStreamParameters outputParameters;
  PaStream *stream;
  PaError err;
  
  unsigned i, c, nSamples;
  float* buffer;
  const unsigned buffsize = 3;
  
  LoadLibrary("portaudio_x86.dll");
  
  // initialise buffering system
  data.incomingPacketsData = mxMalloc(sizeof(Packet) * 256);
  PaUtil_InitializeRingBuffer(&data.incomingPackets, sizeof(Packet), 256, data.incomingPacketsData);
  data.usedPacketsData = mxMalloc(sizeof(Packet) * 256);
  PaUtil_InitializeRingBuffer(&data.usedPackets, sizeof(Packet), 256, data.usedPacketsData);
  
  // create a sine wave packet
  nSamples = SAMPLE_RATE*NUM_SECONDS;
  out.len = NCHANS*nSamples;
  out.buffer = mxMalloc(out.len*sizeof(float));
  for( i=0; i<nSamples; i++ ) {
    float t = (float)i/(float)SAMPLE_RATE;
    for( c=0; c<NCHANS; c++ ) {
      out.buffer[i*NCHANS+c] = (float)(0.5f*sin(2.0f*M_PI*t*FREQ));
    }
  }
  
  // open a stream
  err = Pa_Initialize();
  if( err != paNoError ) goto error;
  
  outputParameters.device = Pa_GetDefaultOutputDevice(); /* default output device */
  if (outputParameters.device == paNoDevice) {
    mexErrMsgIdAndTxt("reo:NoAudioDevices", "No default audio devices");
    return;
  }
  outputParameters.channelCount = NCHANS;       /* stereo output */
  outputParameters.sampleFormat = paFloat32; /* 32 bit floating point output */
  outputParameters.suggestedLatency = Pa_GetDeviceInfo( outputParameters.device )->defaultLowOutputLatency;
  outputParameters.hostApiSpecificStreamInfo = NULL;
  
  err = Pa_OpenStream(
          &stream,
          NULL, /* no input */
          &outputParameters,
          SAMPLE_RATE,
          FRAMES_PER_BUFFER,
          paNoFlag, 
          patestCallback,
          &data );
  if( err != paNoError ) goto error;
  
  mexPrintf("sizeof(*PaStream) = %u\n", sizeof(PaStream*));
  
  err = Pa_StartStream( stream ); if( err != paNoError ) goto error;
  
  
  
  Pa_Sleep( 500*NUM_SECONDS );
  
  PaUtil_WriteRingBuffer(&data.incomingPackets, &out, 1);
  
  Pa_Sleep( 1200*NUM_SECONDS );
  
  err = Pa_StopStream( stream ); if( err != paNoError ) goto error;
  
  err = Pa_CloseStream( stream ); if( err != paNoError ) goto error;
  
  Pa_Terminate();
  // do cleanup
  if (data.incomingPacketsData) mxFree(data.incomingPacketsData);
  if (data.usedPacketsData) mxFree(data.usedPacketsData);
  
  while (PaUtil_GetRingBufferReadAvailable(&data.usedPackets)) {
    PaUtil_ReadRingBuffer(&data.usedPackets, &in, 1);
    mexPrintf("[%.1f %.1f %.1f ... ]\n", in.buffer[0], in.buffer[1], in.buffer[2]);
    mexPrintf("clearing %u\n", in.buffer);
    mxFree(in.buffer);
  }
  
  mexPrintf("callCount = %u\n", data.callCount);
  
  return;
//   
//   buffer = mxMalloc(sizeof(float)*NCHANS*buffsize);
//   
//   out.len = NELEMS(vals);
// //   out.buffer = vals;
//   // first packet
//   out.buffer = mxMalloc(sizeof(vals));
//   memcpy(out.buffer, vals, sizeof(vals));
//   mexPrintf("out.buffer is %u\n", out.buffer);
//   PaUtil_WriteRingBuffer(&data.rBufToRT, &out, 1);
//   // second packet
// //   out.buffer = mxMalloc(sizeof(vals));
// //   memcpy(out.buffer, vals, sizeof(vals));
// //   mexPrintf("out.buffer is %u\n", out.buffer);
// //   PaUtil_WriteRingBuffer(&data.rBufToRT, &out, 1);
//   // now process them
//   patestCallback((void*)0, (void*)buffer, 2, 0, 0, (void*)&data);
//   patestCallback((void*)0, (void*)buffer, 4, 0, 0, (void*)&data);
//   
//   
// //   mexPrintf("%d\n", PaUtil_GetRingBufferReadAvailable(&data.rBufToRT));
// //   mexPrintf("%d in\n", in.len);
// //   PaUtil_ReadRingBuffer(&data.rBufToRT, &in, 1);
// //   mexPrintf("%d\n", PaUtil_GetRingBufferReadAvailable(&data.rBufToRT));
// //   mexPrintf("%d in\n", in.len);
//   for (i = 0; i < NCHANS*buffsize; i++)
//   {
//     mexPrintf("%.1f", buffer[i]);
//     if (i+1 < NCHANS*buffsize) { mexPrintf(","); }
//     else { mexPrintf("\n"); }
//   }
//   
//   // do cleanup
//   if (data.rBufToRTData) mxFree(data.rBufToRTData);
//   if (data.rBufFromRTData)mxFree(data.rBufFromRTData);
//   
//   while (PaUtil_GetRingBufferReadAvailable(&data.rBufFromRT)) {
//     PaUtil_ReadRingBuffer(&data.rBufFromRT, &in, 1);
//     mexPrintf("[%.1f %.1f %.1f ... ]\n", in.buffer[0], in.buffer[1], in.buffer[2]);
//     mexPrintf("clearing %u\n", in.buffer);
//     mxFree(in.buffer);
//   }
//   
//   mxFree(buffer);
//   mexPrintf("done\n");
//   return;
  
  error:
    Pa_Terminate();
    mexErrMsgIdAndTxt("reo:PortAudioError", Pa_GetErrorText(err));
}
/*void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])*/
/*
 * void fun()
 * {
 * PaTestData data = {0};
 * Packet out = {0};
 * Packet in = {0};
 * data.rBufToRTData = PaUtil_AllocateMemory(sizeof(Packet) * 256);
 * PaUtil_InitializeRingBuffer(&data.rBufToRT, sizeof(Packet), 256, data.rBufToRTData);
 *
 * PaUtil_WriteRingBuffer(&data.rBufToRT, &out, 1);
 *
 * PaUtil_ReadRingBuffer(&data.rBufToRT, &in, 1);
 *
 * if (data.rBufToRTData)
 * {
 * PaUtil_FreeMemory(data.rBufToRTData);
 * }
 * if (data.rBufFromRTData)
 * {
 * PaUtil_FreeMemory(data.rBufFromRTData);
 * }
 * }
 */