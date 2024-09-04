#include <windows.h>
#include "mex.h"

#include "reo.h"

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
  PaError err;
  
  if (nrhs>0) {
    unsigned streamIdx = (unsigned)mxGetScalar(prhs[0]);
    err = Pa_StopStream( packetStreams[streamIdx].paStream );
    if( err != paNoError ) goto error;
  } else {
    mexErrMsgIdAndTxt("reo:notEnoughArgs", "Not enough input arguments");
  }

  return;
  
  error:
    mexErrMsgIdAndTxt("reo:PortAudioError", Pa_GetErrorText(err));
}