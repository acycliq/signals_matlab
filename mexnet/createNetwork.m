% createNetwork.m Help file for createNetwork MEX-file.
%  createNetwork.mex64 - Compiled C MEX
%
%  Creates a new network and returns its id
%    
%  Inputs: 
%    network size (int)
%    delete callback (function_handle)
%
%  Outputs:
%    net id (int)
%
%  The calling syntax is:
% 		id = createNetwork(nNodes)
%
%  Examples:
%     % Create a network with maximum of 4000 nodes
%     id = createNetwork(4000)
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
% See also mexnet-vs folder for source code, sig.Net
