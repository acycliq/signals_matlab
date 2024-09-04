#include "reoml.h"

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
  PaError err;
  
  if (nrhs>0) {
    unsigned streamIdx = (unsigned)mxGetScalar(prhs[0]);
    PacketStream *stream = &packetStreams[streamIdx];
    double *inData = mxGetPr(prhs[1]);
    unsigned count = mxGetM(prhs[1])*mxGetN(prhs[1]);
    Packet out = {0};
    unsigned i;

    out.buffer = mxMalloc(sizeof(float)*count);
    out.len = count;

    // copy and cast the data into the packet's buffer
    for (i = 0; i < count; i++)
      out.buffer[i] = (float)inData[i];
    // copy the packet into incoming
    PaUtil_WriteRingBuffer(&stream->incomingPackets, &out, 1);
    mexMakeMemoryPersistent(out.buffer);//persist packet buffer memory
//     mexPrintf("Posted packet on %u with %u elems (%u slots left)\n", 
//             streamIdx, count, PaUtil_GetRingBufferWriteAvailable(&stream->incomingPackets));
    // cleanup used packets
    cleanupUsedPackets(streamIdx);
  }
  return;
  
  error:
    mexErrMsgIdAndTxt("reo:PortAudioError", Pa_GetErrorText(err));
}