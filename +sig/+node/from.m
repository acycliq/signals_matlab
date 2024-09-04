function [nodes, isSignal] = from(srcs)
% sig.node.from Returns an array of nodes from a cell array of inputs
%   The input, srcs, must be a cell array which may contain signals and/or
%   values of another type.  The signals must be part of the same parent
%   network.  If a source value is not a signal, a root node is created to
%   hold that value.  This is useful for deriving a new node, whose inputs
%   are derived from one or more other signals.
%
% See also sig.Net.rootNode


isSignal = cellfun(@(s) isa(s, 'sig.node.Signal'), srcs);
sgl = srcs{find(isSignal, 1)};
net = sgl.Node.Net;
nodes = sig.node.Node.empty;
for i = 1:numel(srcs)
  src = srcs{i};
  if isSignal(i)
    nodes(i) = src.Node;
  else
    % If not a signal, create new node whose name and current value is the
    % source value.
    nodes(i) = rootNode(net, toStr(srcs{i}));
    nodes(i).CurrValue = srcs{i};
  end
end


end

