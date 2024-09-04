classdef End < expr.Expr
  %UNTITLED Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    Index
    NumIndices
  end
  
  methods (Sealed)
    function obj = End(k, n)
      obj.Index = k;
      obj.NumIndices = n;
    end
    
    function var = resolve(obj, scope)
      sz = size(scope);
      n = obj.NumIndices;
      k = obj.Index;
      if n < length(sz) && k==n
        sz(n) = prod(sz(n:end));
      end
      var = sz(k);
    end
    
    function s = str(~)
      s = 'end';
    end
  end
  
end

