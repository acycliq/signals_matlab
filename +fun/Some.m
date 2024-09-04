classdef Some
  %FUN.SOME Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    Value
  end
  
  methods
    function this = Some(value)
      this.Value = value;
    end
    
    function c = or(a, b)
      if isa(a, 'fun.Some')
        c = a.Value;
      else
        if ~isa(a, 'fun.None')
          
        else
        end
      end
    end
  end
  
end

