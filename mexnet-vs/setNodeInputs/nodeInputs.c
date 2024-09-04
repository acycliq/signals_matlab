// setNodeInputs.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include <math.h>


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	if (nrhs < 2) {
		mexErrMsgIdAndTxt("sq:notEnoughArgs", "Not enough input arguments.");
	}
	else if (nrhs > 3) {
		mexErrMsgIdAndTxt("sq:tooManyArgs", "Too many input arguments.");
	}
	else {
		int netid = (int)roundl(mxGetScalar(prhs[0]));
		size_t nodeid = (size_t)roundl(mxGetScalar(prhs[1]));
		if (nrhs == 2) {
			mxArray* inputs = sqGetNodeInputs(netid, nodeid);
			if (nlhs >= 1) {
				plhs[0] = inputs;
				if (nlhs >= 2) {
					plhs[1] = sqGetTransfererCustomArg(netid, nodeid);
				}
			}
		}
		else { // nrhs == 3
			sqSetNodeInputs(netid, nodeid, prhs[2]);
		}
	}
}