classdef Option
  %OPTION Summary of this class goes here
  %   Detailed explanation goes here
  
  methods (Abstract)
    b = or(a, b)
  end
  
  methods (Static)
    function n = none()
      persistent singleton;
      if isempty(singleton)
        singleton = fun.None();
      end
      n = singleton;
    end
  end
  
end

