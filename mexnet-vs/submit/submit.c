// submit.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include <math.h>

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	if (nrhs == 3) {
		int netid = (int)mxGetScalar(prhs[0]);
		size_t nodeid = (size_t)roundl(mxGetScalar(prhs[1]));
		size_t i;
		mxArray *updatedNodes = (mxArray *)NULL;
		for (i = 0; i < 1; i++) {
			mxArray *val = mxDuplicateArray(prhs[2]);
			mexMakeArrayPersistent(val);
			updatedNodes = sqTransact(netid, nodeid, val);
		}
		if (updatedNodes)
			plhs[0] = updatedNodes;
	}
	else {
		mexErrMsgIdAndTxt("sq:notEnoughArgs", "Not enough input arguments");
	}
}