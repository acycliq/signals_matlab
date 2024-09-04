// applyNodes.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include <math.h>



void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	if (nrhs == 2) {
		int netid = (int)mxGetScalar(prhs[0]);
		plhs[0] = sqApply(netid, prhs[1], nlhs > 0);
	}
	else {
		mexErrMsgIdAndTxt("sq:notEnoughArgs", "Not enough input arguments");
	}
}