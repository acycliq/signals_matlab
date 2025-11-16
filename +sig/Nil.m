classdef Nil < handle
  % My take on a 'nothing' or 'not set' value for the signals framework.
  % It's a singleton, and I've tried to make it as fast as possible.

  methods (Access = private)
    function this = Nil()
      % Have to make the constructor private, hence noone
      % will accidentally create more than one of these.
    end
  end

  methods (Static)
    function obj = instance()
      % Provide access to the single, shared instance of the Nil class.
      persistent uniqueInstance;
      % Hmm, it seems I get a nice performance boost by ditching the `isvalid()` 
      % check. It's a persistent handle, so it shouldn't ever become invalid 
      % during a session anyway. Feels like a safe bet.
      if isempty(uniqueInstance)
        uniqueInstance = sig.Nil();
      end
      obj = uniqueInstance;
    end
  end

  methods
    function result = eq(obj1, obj2)
      % I really need to overload the `==` operator. This is the key to making
      % it feel like a real null/sentinel value and keeps comparisons quite fast.
      % It should only ever be equal to itself.
      result = isa(obj1, 'sig.Nil') && isa(obj2, 'sig.Nil');
    end

    function result = ne(obj1, obj2)
      % ok, ~= is just the opposite of the equality I defined above.
      result = ~eq(obj1, obj2);
    end
  end
end