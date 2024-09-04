classdef Mappable < handle
  %MAPPABLE Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
  end

  methods
    function b = floor(a)
      b = map(a, @floor, 'floor(%s)');
    end
    
    function a = abs(x)
      a = map(x, @abs, '|%s|');
    end
    
    function a = sign(x)
      a = map(x, @sign, 'sgn(%s)');
    end

    function c = sin(a)
      c = map(a, @sin, 'sin(%s)');
    end
    
    function c = cos(a)
      c = map(a, @cos, 'cos(%s)');
    end

    function c = uminus(a)
      c = map(a, @uminus, '-%s');
    end
    
    function c = not(a)
      c = map(a, @not, '~%s');
    end

    function c = plus(a, b)
      c = map2(a, @plus, b, '(%s + %s)');
    end
    
    function c = minus(a, b)
      c = map2(a, @minus, b, '(%s - %s)');
    end
    
    function c = mtimes(a, b)
      c = map2(a, @mtimes, b, '%s*%s');
    end
    
    function c = times(a, b)
      c = map2(a, @times, b, '%s.*%s');
    end
    
    function c = mrdivide(a, b)
      c = map2(a, @mrdivide, b, '%s/%s');
    end
    
    function c = rdivide(a, b)
      c = map2(a, @rdivide, b, '%s./%s');
    end
    
    function c = power(a, b)
      c = map2(a, @power, b, '%s.^%s');
    end
    
    function c = mod(a, b)
      c = map2(a, @mod, b, '%s %% %s');
    end
    
    function c = le(a, b)
      c = map2(a, @le, b, '%s <= %s');
    end
    
    function c = lt(a, b)
      c = map2(a, @lt, b, '%s < %s');
    end
    
    function c = ge(a, b)
      c = map2(a, @ge, b, '%s >= %s');
    end
    
    function c = gt(a, b)
      c = map2(a, @gt, b, '%s > %s');
    end
    
    function c = and(a, b)
      c = map2(a, @and, b, '%s & %s');
    end
    
    function x = str2double(strSig)
      x = map(strSig, @str2double, 'str2double(%s)');
    end
    
    function x = str2num(strSig)
      x = map(strSig, @str2num, 'str2num(%s)');
    end
  end
  
  methods (Abstract)
    new = map(this, f, varargin)
    new = map2(this, f, other, varargin)
  end
  
end

