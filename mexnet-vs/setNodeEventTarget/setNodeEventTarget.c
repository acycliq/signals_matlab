// setNodeEventTarget.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include <math.h>


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	if (nrhs == 3) {
		int netid = (int)mxGetScalar(prhs[0]);
		size_t nodeid = (size_t)roundl(mxGetScalar(prhs[1]));
		mxArray *target = (mxArray *)NULL;
		if (!mxIsEmpty(prhs[2])) {
			target = mxDuplicateArray(prhs[2]);
			mexMakeArrayPersistent(target);
		}
		
		sqSetNodeEventsTarget(netid, nodeid, target);
	}
	else {
		mexErrMsgIdAndTxt("sq:notEnoughArgs", "Not enough input arguments");
	}
}