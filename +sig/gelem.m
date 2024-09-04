function h = gelem(parent)
%ELEM Summary of this function goes here
%   Detailed explanation goes here

azirange = [-180 180];
altrange = [-90 90];

azi = linspace(azirange(1), azirange(2), 500);
alt = linspace(altrange(1), altrange(2), 250);

[~, gauss, grate] = vis.gabor(azi, alt, 15, 15, 20, 0, 0, 0);
grate = 0.5*(grate + 1);


set(parent,'NextPlot','replacechildren');
h1 = image(azirange, altrange, repmat(grate, [1 1 3]), 'Parent', parent,...
  'Visible', 'off');
set(parent,'NextPlot','add');
h2 = image(azirange, altrange, 0.5*ones([size(gauss) 3]), 'Parent', parent,...
  'Visible', 'off');
set(parent,'NextPlot','replacechildren');
set(h2, 'AlphaData', 1-gauss);
h = [h1;h2];

end

