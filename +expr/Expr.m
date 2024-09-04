classdef Expr
  %UNTITLED8 Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
  end
  
  methods
    function var = resolve(obj, scope)
    end
  end
  methods (Sealed)
    function b = colon(j, i, k)
      switch nargin
        case 2
          b = expr.BinaryOp(j, i, @colon, '%s:%s');
        case 3
          b = expr.TernaryOp(j, i, k, @colon, '%s:%s:%s');
        otherwise
          error('colon must be called with 2 or three arguments');
      end
    end
    
    function c = mod(a, b)
      c = expr.BinaryOp(a, b, @mod, '%s%%s');
    end

    function c = plus(a, b)
      c = expr.BinaryOp(a, b, @plus, '(%s + %s)');
    end
    
    function c = minus(a, b)
      c = expr.BinaryOp(a, b, @minus, '(%s - %s)');
    end
    
    function c = mtimes(a, b)
      c = expr.BinaryOp(a, b, @mtimes, '%s*%s');
    end
    
    function c = times(a, b)
      c = expr.BinaryOp(a, b, @times, '%s.*%s');
    end
    
    function c = mrdivide(a, b)
      c = expr.BinaryOp(a, b, @mrdivide, '%s/%s');
    end
    
    function c = rdivide(a, b)
      c = expr.BinaryOp(a, b, @rdivide, '%s./%s');
    end
  end
  
end

