classdef (Sealed) None < fun.Option
  %NONE Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
  end
  
  methods (Sealed)
    function c = eq(a, b)
      if isa(a, 'fun.None') && isa(b, 'fun.None')
        c = true;
      else
        c = false;
      end
    end

    function c = or(a, b)
      if isa(a, 'fun.None')
        c = b;
      else
        c = a;
      end
    end
  end
  
end

