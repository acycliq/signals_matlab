function f = fileFunction(functionPath, mfile)
%FILEFUNCTION Creates a function handle and adds it too the MATLAB paths
%   Outputs a function handle to the function 'call', which itself contains
%   the input function path as a variable.  This function when called, adds
%   the function to the MATLAB paths and then evaluates the function once,
%   before restoring the previous MATLAB paths.
%
%   This is useful for one-shot function calls that are not in the MATLAB
%   search path.  Used by Signals to execute experiment definition files.
%
%   See also EXP.SIGNALSEXP, EXP.INFERPARAMETERS

if nargin < 2
  [functionPath, mfile] = fileparts(functionPath);
else
  [~, mfile] = fileparts(mfile);
end

f = @call;

  function varargout = call(varargin)
    origpath = addpath(functionPath);
    try
      f = str2func(['@' mfile]);
      [varargout{1:nargout}] = f(varargin{:});
    catch ex
      clear(mfile);
      path(origpath);
      rethrow(ex);
    end
    clear(mfile);
    path(origpath);
  end

end

