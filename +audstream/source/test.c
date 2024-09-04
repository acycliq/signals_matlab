#include <windows.h>
#include "mex.h"
#include "reo.h"

void mexFunction(int nlhs,mxArray *plhs[],int nrhs,const mxArray *prhs[])
{
  unsigned freeSlots, usedSlots;
  PaError err;
  if (nrhs>0) {
    freeSlots = PaUtil_GetRingBufferWriteAvailable(0);
    freeSlots = PaUtil_GetRingBufferReadAvailable(0);
  }
}