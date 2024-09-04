function [val, valset] = skipRepeats(net, inputs, node, ~)
% SIG.TRANSFER.SKIPREPEATS Summary of this function goes here
%   Detailed explanation goes here

% assumes one input

% get new value
[wv, wvset] = workingNodeValue(net, inputs);
if wvset
  [cv, cvset] = currNodeValue(net, node);
  if ~cvset || ~isequal(wv, cv)
    val = wv;
    valset = true;
    return;
  end
end
%all codepaths end here, but one
% no output
val = [];
valset = false;

end