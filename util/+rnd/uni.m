function r = uni(bounds, sz)
%RND.UNI Samples from a continuous uniform distribution
%   Returns sample(s), r, from a uniform distribution between given bounds.
%   An array of samples are returned of the size given by `sz`.  By
%   default a single value returned.
%
% See also RND.EXP, RND.SAMPLE
if nargin < 2; sz = [1,1]; end
r = bounds(1) + (bounds(end) - bounds(1))*rand(sz);

