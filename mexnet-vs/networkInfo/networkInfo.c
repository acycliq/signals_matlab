// networkInfo.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include <math.h>

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	if (nrhs == 1) {
		int netid = (int)mxGetScalar(prhs[0]);
		sqDispNetwork(netid);
	}
	else if (nrhs == 2) {
		int netid = (int)mxGetScalar(prhs[0]);
		size_t nodeid = (size_t)roundl(mxGetScalar(prhs[1]));
		sqDispNode(netid, nodeid);
	}
	else {
		mexErrMsgIdAndTxt("sq:notEnoughArgs", "Not enough input arguments");
	}
}