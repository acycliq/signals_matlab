// close.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	if (nrhs==1) {
		int streamIdx = (int)mxGetScalar(prhs[0]);
		if (reoValidStream(streamIdx))
			reoClose(streamIdx);
		else
			mexErrMsgIdAndTxt("reo:invalidStream", "Not a valid stream id");
	}
	else if (nrhs == 0) {
		reoCloseAll();
	}
	else {
		mexErrMsgIdAndTxt("reo:notEnoughArgs", "Not enough input arguments");
	}
}