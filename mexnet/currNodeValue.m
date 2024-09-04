% currNodeValue.m Help file for currNodeValue MEX-file.
%  currNodeValue.mex64 - Compiled C MEX
%
%  Retrieves current value of a given node
%    
%  Inputs: 
%    network id (int)
%    node id (int)
%
%  Outputs:
%    current value (*)
%
%  The calling syntax is:
% 		value = currNodeValue(netID, nodeID)
%
%  Examples:
%     % Retrieve current value set for node 1 in network 0
%     v = currNodeValue(0, 1)
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
