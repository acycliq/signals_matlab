function [val, valset] = indexOfFirst(net, inputs, node, ~)
% SIG.TRANSFER.FIRSTTRUE Summary of this function goes here
%   Detailed explanation goes here

n = numel(inputs);

noMatch = n + 1;

[currMatch, currset] = currNodeValue(net, node);
if ~currset % no current match, set currMatch to Inf
  currMatch = Inf;
end

firstNewInput = [];

for inp = 1:n

  % get latest predicate value
  [pred, predset] = workingNodeValue(net, inputs(inp));
  if ~predset % if no new predicate value then use current
    [pred, predset] = currNodeValue(net, inputs(inp));
  elseif isempty(firstNewInput)
    firstNewInput = inp;
    if firstNewInput > currMatch
      % first changed predicate must be after the current match, so we do not
      % evaluate any further -> no new output
      val = [];
      valset = false;
      return;
    end
  end
  % assess this input's predicate value
  if ~predset
    % predicate has no value, we can't evaluate further, so output should
    % be noMatch
    val = noMatch;
    valset = true;
    return;    
  end
  if pred % predicate truthy, return this input/level as match
    val = inp;
    valset = true;
    return
  end
end
% after checking all inputs, no matching predicate found:
val = noMatch;
valset = true;

end