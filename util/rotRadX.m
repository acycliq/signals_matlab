function R = rotRadX(rad)
% ROTRADX Returns transform matrix for rotating a given amount in radians
% along x-axis
%   Returns a 4x4 transformation matrix for performing rotation of rad
%   radians along the x-axis in hetrogrneous coordinates.
%
% See also VIS.PLANEPROJECTION, VIS.DRAW

R = [
  1 0 0 0
  0 cos(rad) -sin(rad) 0
  0 sin(rad) cos(rad) 0
  0 0 0 1
  ];

end

