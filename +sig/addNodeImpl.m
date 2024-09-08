function nodeId = addNodeImpl(netId, inputs, transferFun, appendValues)
    manager = sig.getNetworkManager();
    nodeId = manager.addNode(netId, inputs, transferFun, appendValues);
end

% Original C code from addNode.c:
%
% // addNode.c : Defines the exported functions for the DLL application.
% //
% 
% #include "stdafx.h"
% #include <math.h>
% 
% void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
% 	// function id = addNode(net, inputs, transFunName, transOpCode, [transArg])
% 	if (nrhs >= 4 && nrhs <= 6) {
% 		if (!mxIsDouble(prhs[0]) || !mxIsDouble(prhs[1]) || !mxIsDouble(prhs[3])) {
% 			mexErrMsgIdAndTxt("sq:invalidArgType", "Network id, input node ids & opCode should be doubles");
% 		}
% 		else {
% 			int netid = (int)mxGetScalar(prhs[0]);
% 			size_t nInputs = mxGetNumberOfElements(prhs[1]);
% 			double *dinputs = mxGetPr(prhs[1]);
% 			size_t nodeid, *inputs = mxMalloc(sizeof(size_t)*nInputs);
% 			char *funName = mxArrayToString(prhs[2]);
% 			mexMakeMemoryPersistent(funName);
% 			Transferer transferer = { 
% 				.funName = funName,
% 				.opCode = (int)mxGetScalar(prhs[3]),
% 				.args = 0 };
% 			bool appendValues = false;
% 			// transferer args are (net, inputs, node, custom). we just set custom if any
% 			if (nrhs >= 5) {
% 				transferer.args[TRANSFER_CUSTOM_ARG_IDX] = mxDuplicateArray(prhs[4]);
% 			}
% 			else {
% 				transferer.args[TRANSFER_CUSTOM_ARG_IDX] = mxCreateDoubleMatrix(0, 0, mxREAL);
% 			}
% 			mexMakeArrayPersistent(transferer.args[TRANSFER_CUSTOM_ARG_IDX]);
% 
% 			if (nrhs == 6) {
% 				appendValues = mxIsLogicalScalarTrue(prhs[5]);
% 			}
% 
% 			for (size_t i = 0; i < nInputs; i++)
% 				inputs[i] = (size_t)roundl(dinputs[i]);
% 			nodeid = sqAddNode(netid, inputs, nInputs, transferer, appendValues);
% 			mxFree(inputs); // free the list of input nodes
% 			plhs[0] = mxCreateDoubleScalar((double)nodeid);
% 		}
% 	}
% 	else { mexErrMsgIdAndTxt("sq:notEnoughArgs", "Incorrect number of input arguments."); }
% 	
% }