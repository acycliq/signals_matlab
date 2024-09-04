function scr = screen(centreXYZ, viewAzimuth, dims, pxBounds)
%SCREEN Calculate projection matrix for given viewing dimentions
%  Returns a projection matrix given physical dimentions of the screen and
%  viewer location.
%
%  Works with the "line of sight" from the subject's view point that
%  intersects the screen perpendicularly (i.e. the normal line to it). Then
%  measures and specifies the following:
%
%  'centreXYZ' is the position of the screen's centre relative to the view
%  point (y-axis is up the screen, x-axis rightwards along the screen,
%  z-axis toward the screen).
%
%  'viewAzimuth' is the horizontal angle between straight ahead for the
%  subject, and the line of sight to the screen (where positive is
%  right-wards).
%
%  'dims' is the physical size of the screen, [w h], in cm
%
%  'pxBounds' is the pixel bounds of the screen, [left top right bottom].
%  This is usually [0 0 width height], in pixels of the screen/display.
%  However, when you have a single virtual display tiled from multiple
%  physical screens this will be the subset of the virtual display's pixels
%  spanned by the particular screen you're configuring.
%
% See also VIS.PLANEPROJECTION, VIS.INIT


scr.bounds = pxBounds;
[scr.w, scr.h] = RectSize(scr.bounds);
scr.projection = vis.planeProjection(centreXYZ, dims, [pi*(viewAzimuth-90)/180 0]);

end

