function [c, h] = component(parent)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

path = fileparts(mfilename('fullpath'));
fid = fopen(fullfile(path, 'slimshady.vert'));
vertexsrc = fread(fid, '*char')';
fclose(fid);
fid = fopen(fullfile(path, 'slimshady.frag'));
fragsrc = fread(fid, '*char')';
fclose(fid);


addSignalsJava();
c = javaObjectEDT('VisualRenderer', vertexsrc, fragsrc);

[jh, h] = javacomponent(c, [0 0 100 50], bui.parentFigure(parent));
set(h, 'Parent', parent);

end

