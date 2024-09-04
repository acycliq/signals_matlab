function [val, valset] = subsref(net, inputs, node, type)
% SIG.TRANSFER.SUBSREF Summary of this function goes here
%   Detailed explanation goes here

% assumes inputs are: [what, sub1, subs2,...]
% with at least one subscript

n = numel(inputs);
inpvals = cell(n, 1);
wvset = false(n, 1);
for inp = 1:n
  [wv, wvset(inp)] = workingNodeValue(net, inputs(inp));
  if wvset(inp) % value follows working value first
    inpvals{inp} = wv;
  else % cvset % falls back to current value
    [cv, cvset] = currNodeValue(net, inputs(inp));
    if cvset
      inpvals{inp} = cv;
    else % finding an input with no value set -> no output
      val = [];
      valset = false;
      return
    end
  end
end

if any(wvset)
  what = inpvals{1};
  %% build a subscript struct for use with subsref
  if strcmp(type, '.')
    subs = inpvals{2};
    if isstruct(what) && ~isfield(what, subs)
      % if the reference is .name style, the value is a struct, dont set
      % output if the field doesn't exist
      val = [];
      valset = false;
      return
    else
      val = what.(subs);
      valset = true;
      return
    end
  else
    s = struct('type', type, 'subs', {inpvals(2:end)});
    %% resolve any deferred subscript ranges
    for kk = 1:length(s.subs)
      if isa(s.subs{kk}, 'expr.Expr')
        s.subs{kk} = resolve(s.subs{kk}, what);
      end
    end
  end
  %% compute the subscripted value and return
  val = subsref(what, s);
  valset = true;
end

end