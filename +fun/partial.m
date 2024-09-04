function fout = partial(f, varargin)
%FUN.PARTIAL Partial function application
%   Takes a function f and the first one or more normal arguments to f and
%   returns a new function that takes the remaining arguments to call f
%   with the full complement.
%

applied = varargin;
clear varargin;

fout = @do;

  function varargout = do(varargin)
    [varargout{1:nargout}] = f(applied{:}, varargin{:});
  end

end

