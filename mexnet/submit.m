% submit.m Help file for submit MEX-file.
%  submit.mex64 - Compiled C MEX
%
%  Apply a value to a given node
%    
%  Inputs: 
%    network id (int)
%    node id (int)
%    value (*)
%
%  Outputs:
%    affected ids (numerical)
%
%  The calling syntax is:
%    submit(netID, nodeID, value)
%
%  Examples:
%     % Update value of node 1 in network 0 to pi
%     ids = submit(0, 1, pi)
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
