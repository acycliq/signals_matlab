function R = rotRadZ(rad)
% ROTRADZ Returns transform matrix for rotating a given amount in radians
% along z-axis
%   Returns a 4x4 transformation matrix for performing rotation of rad
%   radians along the z-axis in hetrogrneous coordinates.
%
% See also VIS.PLANEPROJECTION, VIS.DRAW

R = [
  cos(rad) -sin(rad) 0 0
  sin(rad) cos(rad) 0 0
  0 0 1 0
  0 0 0 1
  ];

end