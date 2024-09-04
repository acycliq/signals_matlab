% nodeInputs.m Help file for nodeInputs MEX-file.
%  nodeInputs.mex64 - Compiled C MEX
%
%  Computes values of all dependent nodes using node working value
%    
%  Inputs: 
%    network id (int)
%    node id (int)
%    - Optional - 
%    node inputs (numerical)
%
%  Outputs:
%    affected ids (numerical)
%
%  The calling syntax is:
% 		nodeInputs(netID, nodeID[, inputIDs])
%
%  Examples:
%     % Retrieve input node ids for node 1 in network 0
%     inputs = nodeInputs(0, 1)
%
%     % Set input node ids for node 1 in network 0
%     nodeInputs(0, 1, [0, 3])
%
%  Errors:
%     sq:notEnoughArgs - Incorrect number of input arguments
%     sq:tooManyArgs - Too many input arguments
%     
%  Created with:
%  MATLAB (R2019a)
%  Platform: mexw64 (win64)
%  Microsoft Visual C++ 2019 (C)
%
%  This is a MEX file function for Signals.
%
% See also mexnet-vs folder for source code, sig.node.Node/setInputs
