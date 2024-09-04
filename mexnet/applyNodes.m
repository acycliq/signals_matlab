% applyNodes.m Help file for applyNodes MEX-file.
%  applyNodes.mex64 - Compiled C MEX
%
%  Computes values of all dependent nodes using node working value
%    
%  Inputs: 
%    network id (int)
%    node ids (numerical)
%
%  Outputs:
%    affected ids (numerical)
%
%  The calling syntax is:
% 	 applyNodes(netID, nodeID)
%
%  Examples:
%     % Propogate changes of node 1 in network 0 to all dependent nodes
%     ids = applyNodes(0, 1)
%
%  Errors:
%     sq:notEnoughArgs - Incorrect number of input arguments
%     
%  Created with:
%  MATLAB (R2019a)
%  Platform: mexw64 (win64)
%  Microsoft Visual C++ 2019 (C)
%
%  This is a MEX file function for Signals.
%
% See also mexnet-vs folder for source code, sig.node.OriginSignal/post
