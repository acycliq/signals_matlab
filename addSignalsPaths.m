function addSignalsPaths(savePaths)
%addSignalsPaths Adds the folders required for signals to MATLAB path
%   Detailed explanation goes here

if nargin < 1
  savePaths = true;
end

root = fileparts(mfilename('fullpath'));

addpath(...
  root,...
  fullfile(root, 'util'),...
  fullfile(root, 'mexnet')...
  );

if savePaths
  assert(savepath == 0, 'Failed to save changes to MATLAB path');
end

end

