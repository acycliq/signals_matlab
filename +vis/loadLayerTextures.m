function gltex = loadLayerTextures(layers)
%VIS.LOADLAYERTEXTURES Summary of this function goes here
%   Detailed explanation goes here

gltex = glGenTextures(numel(layers)); % make the OGL texture names
for ii = 1:numel(layers)
%   rgba = uint8(round(255*layers(ii).rgba));
%   rgba = permute(rgba(end:-1:1,:,:), [3 2 1]);
  
  vis.reloadLayerTexture(layers(ii),gltex(ii));
end

end

