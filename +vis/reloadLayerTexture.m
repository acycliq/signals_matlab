function reloadLayerTexture(layer, gltex)
%VIS.LOADLAYERTEXTURES Summary of this function goes here
%   Detailed explanation goes here

global GL;

w = layer.rgbaSize(1);
h = layer.rgbaSize(2);

glBindTexture(GL.TEXTURE_2D, gltex); % activate
glTexImage2D(GL.TEXTURE_2D, 0, GL.RGBA, w, h, 0,...
  GL.RGBA, GL.UNSIGNED_BYTE, layer.rgba);
switch layer.interpolation
  case 'linear'
    glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
    glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
  case 'nearest'
    glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
    glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
  otherwise
    error('Invalid interpolation method ''%s''', layer.interpolation);
end

if layer.isPeriodic
  glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.REPEAT);
  glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.REPEAT);
else
  glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_BORDER);
  glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_BORDER);
  if any(strcmp(layer.blending, {'1-src' '1-source'}))
    glTexParameterfv(GL.TEXTURE_2D, GL.TEXTURE_BORDER_COLOR, single([0 0 0 1]));
  else
    glTexParameterfv(GL.TEXTURE_2D, GL.TEXTURE_BORDER_COLOR, single([0 0 0 0]));
  end
end

end

