// currNodeValue.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include <math.h>

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	if (nrhs < 2) {
		mexErrMsgIdAndTxt("sq:notEnoughArgs", "Not enough input arguments.");
	}
	else if (nrhs > 4) {
		mexErrMsgIdAndTxt("sq:tooManyArgs", "Too many input arguments.");
	}
	else {
		int netid = (int)mxGetScalar(prhs[0]);
		size_t nodeid = (size_t)roundl(mxGetScalar(prhs[1]));
		bool appendValue = false;
		bool copyValue = true; // default to making a duplicate of returned values
		if (nrhs >= 3) {
			copyValue = mxIsLogicalScalarTrue(prhs[2]);
		}
		if (nlhs > 0 || nrhs < 4) {
			mxArray *v = sqGetNodeCurrValue(netid, nodeid);
			bool vset = true;
			if (v) {
				if (copyValue) {
					v = mxDuplicateArray(v);
				}
			}
			else { // no value set, so return empty
				v = mxCreateDoubleMatrix(0, 0, mxREAL);
				vset = false;
			}
			plhs[0] = v;
			if (nlhs == 2) {
				plhs[1] = mxCreateLogicalScalar(vset);
			}
		}
		if (nrhs == 4) {
			/*
			if (nrhs >= 5) {
			appendValue = mxIsLogicalScalarTrue(prhs[3]);
			}*/
			mxArray* newv = mxDuplicateArray(prhs[3]);
			mexMakeArrayPersistent(newv);
			sqSetNodeCurrValue(netid, nodeid, newv, appendValue);
		}
	}
}