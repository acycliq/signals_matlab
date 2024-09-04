// open.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	int stream;
	int nChans = 2; // default to stereo
	int paDevIdx = -1; // default audio device
	double suggestedLatency = 0.020f; // default suggested latency of 20ms
	mexCallMATLAB(0, NULL, 0, NULL, "InitializePsychSound");
	mexAtExit(reoCloseAll);
	if (nrhs >= 2) {
		nChans = (int)mxGetScalar(prhs[1]);
	}
	if (nrhs >= 3) {
		paDevIdx = (int)mxGetScalar(prhs[2]);
	}
	if (nrhs >= 4) {
		suggestedLatency = mxGetScalar(prhs[3]);
	}
	if ((nrhs >= 1) && (nrhs <= 4)) {
		stream = reoOpen(mxGetScalar(prhs[0]), nChans, paDevIdx, suggestedLatency);
		if (stream >= 0) {
			plhs[0] = mxCreateDoubleScalar(stream);
		}
		else {
			plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
		}
	}
	else {
		mexErrMsgIdAndTxt("reo:incorrectArgs", "Incorrect number of input arguments.");
	}
	
}