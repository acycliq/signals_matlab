function tridx = quadToTriangles(quadVertices)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

nQuads = size(quadVertices, 2);
nVertices = 4; % a quad has four vertices

[v, q] = ndgrid([1 2 3], 0:nQuads-1);
picker1 = v + q*nVertices;
NEtridx = quadVertices(picker1);

[v, q] = ndgrid([1 3 4], 0:nQuads-1);
picker2 = v + q*nVertices;
SWtridx = quadVertices(picker2);

tridx = zeros(3, 2*nQuads);
tridx(:,1:2:end) = NEtridx;
tridx(:,2:2:end) = SWtridx;

end

