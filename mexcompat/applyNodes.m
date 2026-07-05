function applied = applyNodes(netId, nodeIdxs)
%APPLYNODES Pure MATLAB drop-in replacement for the mexnet applyNodes
%   In the mex pair, submit propagated and applyNodes committed. The
%   mexcompat submit runs the whole transaction itself, so by the time
%   this is called the work is already done. This validates the network
%   id and returns, keeping the old call sites working unchanged.
%
%   If an output is requested, the input ids are echoed back. The mex
%   returned the subset of nodes whose working values were actually
%   applied; after a fused submit that distinction no longer exists, so
%   callers relying on the returned set (only the legacy Signals_test.m
%   plumbing tests) should not use this adapter.
%
% See also submit, sig.Net/byId

sig.Net.byId(netId); % errors like the mex complained on a bad id

if nargout
  applied = nodeIdxs(:);
end

end
