// deleteNetwork.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	if (nrhs == 1) {
		int netid = (int)mxGetScalar(prhs[0]);
		sqDeleteNetwork(netid);
	} else if (nrhs == 0) { // delete all active networks
		sqDeleteNetworks();
	}
	else {
		mexErrMsgIdAndTxt("sq:notEnoughArgs", "Not enough input arguments");
	}
}