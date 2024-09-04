// post.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	if (nrhs == 2) {
		int streamIdx = (int)mxGetScalar(prhs[0]);

		if (reoValidStream(streamIdx)) {
			double *inData = mxGetPr(prhs[1]);
			size_t count = mxGetM(prhs[1])*mxGetN(prhs[1]);
			unsigned i;
			float *data = mxMalloc(sizeof(float)*count);

			// cast samples and copy into data buffer
			for (i = 0; i < count; i++)
				data[i] = (float)inData[i];

			mexMakeMemoryPersistent(data); //persist data buffer

			reoPost(streamIdx, data, count);
		}
		else
			mexErrMsgIdAndTxt("reo:invalidStream", "Not a valid stream id");
	}
	else {
		mexErrMsgIdAndTxt("reo:notEnoughArgs", "Not enough input arguments");
	}
}
