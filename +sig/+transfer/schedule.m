function [val, valset] = schedule(net, input, node, ~)
% SIG.TRANSFER.SCHEDULE Returns the input's current value and it's
% scheduled delay in a cell array, 'val'.
%   net = id of the parent network
%   input is assumed to be [what, delay]:
%     input(1) = id of the node whose value is to be transferred after the
%     delay.
%     input(2) = id of the root node carrying the delay duration
%   node = scheduler node, i.e. the node whose input nodes are 'input' and
%   whose transfer function is this

%% get latest value from 'delay' input
[delay, delayset] = workingNodeValue(net, input(2));
if ~delayset
  [delay, delayset] = currNodeValue(net, input(2));
end
%% working value from 'what' input
[what, whatset] = workingNodeValue(net, input(1)); % assumes one input only
%% if new 'what' and any 'delay' values are available, set output
if whatset && delayset
  val = {what delay}; % a schedule 'packet'
  valset = true;
else
  val = [];
  valset = false;
end

end