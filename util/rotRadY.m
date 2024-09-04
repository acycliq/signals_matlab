function R = rotRadY(rad)
% ROTRADY Returns transform matrix for rotating a given amount in radians
% along y-axis
%   Returns a 4x4 transformation matrix for performing rotation of rad
%   radians along the y-axis in hetrogrneous coordinates.
%
% See also VIS.PLANEPROJECTION, VIS.DRAW

R = [
  cos(rad) 0 sin(rad) 0
  0 1 0 0
  -sin(rad) 0 cos(rad) 0
  0 0 0 1
  ];

end

