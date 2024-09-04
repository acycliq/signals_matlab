% addNode.m Help file for addNode MEX-file.
%  addNode.mex64 - Compiled C MEX
%
%  Adds a node to a given network. 
%    
%  Inputs: 
%    network id (numerical)
%    input node ids (numerical)
%    transfer function (char)
%    operation code (numerical)
%    - Optional -
%    transfer function argument (*) - default: []
%    append values (bool) - default: false
%
%  Outputs:
%    node id (int)
%
%  The calling syntax is:
% 		addNode(netID, inputIDs, transFun, opCode[, transArg, appendValues])
%
%  Examples:
%     % Add empty node to network 0, e.g. origin node
%     id = addNode(0, [], 'sig.transfer.nop', 0)
%
%     % Add multiplier node
%     id = addNode(0, [0 1], 'sig.transfer.mapn', 4, @mtimes)
%
%     % Add node that accumulates values
%     id = addNode(0, 2, 'sig.transfer.identity', 0, [], true)
%
%  Errors:
%     sq:invalidArgType - Network id, input node ids & opCode should be
%                         doubles
%     sq:notEnoughArgs - Incorrect number of input arguments
%     
%  Created with:
%  MATLAB (R2019a)
%  Platform: mexw64 (win64)
%  Microsoft Visual C++ 2019 (C)
%
%  This is a MEX file function for Signals.
%
% See also mexnet-vs folder for source code, sig.node.Node