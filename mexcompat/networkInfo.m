function networkInfo(netId, nodeId)
%NETWORKINFO Pure MATLAB drop-in replacement for the mexnet networkInfo
%   Prints debug information about a network or one of its nodes, with
%   the same output the mex produced:
%
%     networkInfo(netId)          summary of the whole net
%       Net 0 with 3/4000 active nodes
%     networkInfo(netId, nodeId)  one node's value, wiring and transferer
%       {#2,value:9,inputs:[1],targets:[4],transferer{funName:@sig.transfer.mapn,opCode:4}}
%
%   Like the mex (networkInfo.c, sqDispNetwork/sqDispNode in network.c
%   L270-316), a bad id prints a message instead of erroring. Node ids
%   here are the pure engine's 1 based ids.
%
% See also sig.Net/byId, submit, applyNodes

reg = sig.Net.registry();
if ~isKey(reg, netId) || ~isvalid(reg(netId))
  fprintf('%d is not a valid network id\n', netId);
  return
end
net = reg(netId);

if nargin < 2
  % net summary, network.c L272-273
  fprintf('Net %d with %d/%d active nodes\n', netId, net.nNodes, numel(net.nodes));
  return
end

if nodeId < 1 || nodeId > numel(net.nodes) || isempty(net.nodes{nodeId})
  fprintf('%d is not a valid node id\n', nodeId);
  return
end
node = net.nodes{nodeId};

% node dump, network.c L289-315
fprintf('{#%d,value:', node.Id);
v = node.CurrValue;
if node.CurrValueSet
  if isnumeric(v)
    fprintf('%s', mat2str(v));
  else
    fprintf('{...}');
  end
else
  fprintf('NULL');
end
fprintf(',inputs:[%s]', strjoin(arrayfun(@(n) num2str(n.Id), ...
  node.Inputs, 'uni', false), ','));
fprintf(',targets:[%s]', strjoin(cellfun(@(n) num2str(n.Id), ...
  node.Targets, 'uni', false), ','));
fprintf(',transferer{funName:@%s,opCode:%d}}\n', node.transFun, node.opCode);

end