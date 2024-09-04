% networkInfo.m Help file for networkInfo MEX-file.
%  networkInfo.mex64 - Compiled C MEX
%
%  Prints information on a given network or node id to the command window. 
%  Inputs: 
%    network id (int)
%    - Optional -
%    node id (int)
%
%  Outputs:
%    N/A
%
%  The calling syntax is:
% 	 networkInfo(netID[, nodeID])
%
%  Examples:
%     >> networkInfo(0)
%     Net 0 with 3/4000 active nodes
%
%     >> networkInfo(0,4)
%     {#3,value:10,inputs:[0,1],targets:[4],transferer{funName:@sig.transfer.mapn,opCode:4}}
%
%  Errors:
%     Not enough input arguments
%     Not a valid network id
%     Not a valid node id
%     
%  Created with:
%  MATLAB (R2019a)
%  Platform: mexw64 (win64)
%  Microsoft Visual C++ 2019 (C)
%
%  This is a MEX file function for Signals.
%
% See also mexnet-vs folder for source code