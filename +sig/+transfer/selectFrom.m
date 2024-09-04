function [val, valset] = selectFrom(net, inputs, node, ~)
% SIG.TRANSFER.SELECTFROM Summary of this function goes here
%   Detailed explanation goes here

% asumme inputs are [indexer,option1,option2,...];
nOptions = numel(inputs) - 1;

% get latest indexer value
[idx, idxwvset] = workingNodeValue(net, inputs(1));
if ~idxwvset
  [idx, idxcvset] = currNodeValue(net, inputs(1));
end

% if no indexer value -> new output unset
if ~idxwvset && ~idxcvset
  val = [];
  valset = false;
  return;
end

if idx <= nOptions
  [selval, selwvvalset] = workingNodeValue(net, inputs(idx+1));
  if ~selwvvalset
    [selval, selcvvalset] = currNodeValue(net, inputs(idx+1));
  end
  if (selwvvalset || selcvvalset) ... a selected option value is available
      && (idxwvset || selwvvalset) % either the indexer OR selected option changed
    val = selval;
    valset = true;
    return
  end
end
val = [];
valset = false;


end