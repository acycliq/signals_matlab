classdef Value < expr.Expr
  %UNTITLED9 Summary of this class goes here
  %   Detailed explanation goes here
  
  properties (SetAccess = protected)
    Val
    StrRepr
  end
  
  methods
    function obj = Value(val)
      obj.Val = val;
      if exist('mupadmex','file') == 3
        if isscalar(val)
          obj.StrRepr = strrep(mupadmex(' ', val, 3), 'pi', char(960));
        else
          warning('TODO: implement better repr of non-scalar');
          obj.StrRepr = num2str(val);
%           elems = mapToCell(@(v) mupadmex(' ', v, 3), val);
        end
      else
        obj.StrRepr = num2str(val);
      end
    end

    function var = resolve(obj, scope)
      var = obj.Val;
    end
    
    function s = str(obj)
      s = obj.StrRepr;
    end
  end
  
end

