// info.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	if (nrhs == 1) {
		int streamIdx = (int)mxGetScalar(prhs[0]);
		if (reoValidStream(streamIdx)) {
			plhs[0] = mxCreateDoubleScalar(reoUsedSlots(streamIdx));
			if (nlhs > 1) {
				plhs[1] = mxCreateDoubleScalar(reoFreeSlots(streamIdx));
			}
		}
		else
			mexErrMsgIdAndTxt("reo:invalidStream", "Not a valid stream id");

	}
}