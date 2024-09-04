classdef Option
  %UNTITLED Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
  end
  
  enumeration
    None
  end
  
  methods
    function c = or_(a, b)
      if (a == Option.None)
        c = b;
      else
        c = a;
      end
    end
  end
  
end

