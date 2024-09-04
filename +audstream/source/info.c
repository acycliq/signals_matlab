#include "reoml.h"

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
  unsigned freeSlots, usedSlots;
  PaError err;
  if (nrhs>0) {
    unsigned streamIdx = (unsigned)mxGetScalar(prhs[0]);
    PacketStream *stream = &packetStreams[streamIdx];
    
    freeSlots = PaUtil_GetRingBufferWriteAvailable(&stream->incomingPackets);
    usedSlots = PaUtil_GetRingBufferReadAvailable(&stream->incomingPackets);
    
    
    plhs[0] = mxCreateDoubleScalar(usedSlots);
    if (nlhs>1) {
      plhs[1] = mxCreateDoubleScalar(freeSlots);
    }
  }
  return;
  
  error:
    mexErrMsgIdAndTxt("reo:PortAudioError", Pa_GetErrorText(err));
}