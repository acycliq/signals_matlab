function affectedIdxs = submit(netId, nodeId, value)
%SUBMIT Pure MATLAB drop-in replacement for the mexnet submit
%   Serves callers that still use the old mex call signature, most
%   notably Rigbox's exp.SignalsExp/quit, which forces a value into the
%   experiment stop node with submit followed by applyNodes.
%
%   Unlike the mex, which only propagated and left the commit to
%   applyNodes, this runs the WHOLE transaction (propagate and apply) in
%   one go through sig.node.Node/transact. For every known runtime
%   caller, submit and applyNodes are called back to back, so the fused
%   behaviour is indistinguishable. It is NOT equivalent for code that
%   inspects working values between the two calls (only the legacy
%   Signals_test.m plumbing tests do that, and they are kept as mex era
%   artifacts).
%
%   Inputs:
%     netId (int)  : network id as returned by sig.Net (0 based slots)
%     nodeId (int) : id of the node to force the value into
%     value (*)    : the value to submit
%
%   Output:
%     affectedIdxs : column of affected node ids in propagation order,
%       as sqTransact returned (network.c L329-335)
%
% See also sig.node.Node/transact, sig.Net/byId, applyNodes

net = sig.Net.byId(netId);
affectedIdxs = net.nodes{nodeId}.transact(value);

end
