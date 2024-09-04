function f = always(v)
%FUN.ALWAYS Return a function handle that always returns a given value 
%   When called with a value, v, returns a function handle that when called
%   with zero or one arguments returns the original value.
%   Example:
%     f = fun.always(5)
%     f(2) % 5
%

f = @fun;

  function res = fun(~)
    res = v;
  end

end

