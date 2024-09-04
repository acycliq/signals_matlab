function [val, valset] = at(net, inputs, node, ~)
% SIG.TRANSFER.AT Summary of this function goes here
%   Detailed explanation goes here

% always assumes two inputs: [what, when]

% get working 'when' value
[when, whenset] = workingNodeValue(net, inputs(2));
% we gate on the working value existing and being truthy
if whenset
  if when % if 'when' is truthy (i.e. not false or zero)...
    % ...get latest 'what' value
    [what, whatset] = workingNodeValue(net, inputs(1));
    if ~whatset
      [what, whatset] = currNodeValue(net, inputs(1));
    end
    % has any 'what' value been set?
    if whatset % if so, set working output to it
      val = what;
      valset = true;
      return % only code path that sets a working output value
    end
  end
end
%all codepaths end here, but one
% no output
val = [];
valset = false;

end