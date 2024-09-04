#include "reoml.h"

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
  PaError err;
  
  if (nrhs>0) {
    unsigned streamIdx = (unsigned)mxGetScalar(prhs[0]);
    PacketStream *stream = &packetStreams[streamIdx];
    mexPrintf("Stream id = %u, ptr = %u\n", streamIdx, stream->paStream);
    err = Pa_CloseStream(stream->paStream); //close the PortAudio stream
    //put current packet into the used queue, then cleanup all used
    PaUtil_WriteRingBuffer(&stream->usedPackets, &stream->current, 1);
    cleanupUsedPackets(streamIdx);
    //free the memory for the queues
    mxFree(stream->incomingPacketsData);
    mxFree(stream->usedPacketsData);
    stream->paStream = NULL;
    if( err != paNoError ) goto error;
    mexPrintf("Cleaned up %d\n", streamIdx);
  }
  
  if ( portAudioInitialized ) {    
    Pa_Terminate();
    portAudioInitialized = FALSE;
    mexPrintf("PortAudio shut down\n");
  }
  mexPrintf("done\n");
  return;
  
  error:
    mexErrMsgIdAndTxt("reo:PortAudioError", Pa_GetErrorText(err));
}