% workingNodeValue.m Help file for workingNodeValue MEX-file.
%  workingNodeValue.mex64 - Compiled C MEX
%
%  Retrieves working value of a given node
%    
%  Inputs: 
%    network id (int)
%    node id (int)
%
%  Outputs:
%    working value (*)
%
%  The calling syntax is:
% 		value = workingNodeValue(netID, nodeID)
%
%  Examples:
%     % Retrieve working value set for node 1 in network 0
%     v = workingNodeValue(0, 1)
%
%  Errors:
%     sq:notEnoughArgs - Incorrect number of input arguments
%     sq:tooManyArgs - Too many input arguments
%
%  TODO:
%     - assert 2 input args
%     - remove old if statements
%     - edit sig.node.Node/get.CurrValue to call with 2 args
%     - OR allow 3 input args and have copyValue false by default?
%     
%  Created with:
%  MATLAB (R2019a)
%  Platform: mexw64 (win64)
%  Microsoft Visual C++ 2019 (C)
%
%  This is a MEX file function for Signals.
%
% See also mexnet-vs folder for source code, sig.node.Node/get.CurrValue
