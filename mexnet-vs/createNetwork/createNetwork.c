// createNetwork.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include <math.h>

static void closeNetworks(void)
{
	mexPrintf("Unloading sqNetwork\n");
	sqDeleteNetworks();
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	if (nrhs >= 1 && nrhs <= 2) {
		size_t networkSize = (size_t)roundl(mxGetScalar(prhs[0]));
		mxArray *deleteCallback = (mxArray *)NULL;
		if (nrhs >= 2) {
			mxArray *deleteCallback = mxDuplicateArray(prhs[1]);
		}
		int net = sqCreateNetwork(networkSize, deleteCallback);
		plhs[0] = mxCreateDoubleScalar(net);
		if (net >= 0 && deleteCallback)
			mexMakeArrayPersistent(deleteCallback);
		mexAtExit(closeNetworks);
	}
	else {
		mexErrMsgIdAndTxt("sq:notEnoughArgs", "Not enough input arguments");
	}
}