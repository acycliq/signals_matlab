%% open the window
InitializeMatlabOpenGL;
ins = 40;
% off = -1920;
off = 0;
openbounds = [off 0 640+off 480] + ins;
win = Screen('OpenWindow', 2, [0 255 0], openbounds);

% do init & fiddle
h = onionInit(win);

Screen('BeginOpenGL', win);
glEnable(GL.BLEND);
glClearColor(0, 1, 0, 1); % green construct
Screen('EndOpenGL', win);

%% make some layers
[gabor, layers] = vis.gabor;
% layers = layers.CurrValue;
% layers = vis.loadLayerTextures(win, layers);
%%
tic;
Screen('BeginOpenGL', win);
glClear(GL.COLOR_BUFFER_BIT);
vizDraw(win, h, layers);
Screen('EndOpenGL', win);
toc
Screen('Flip', win);

%% make a gabor & axes test pattern
texsize = 256;
gaborsize = [360 180];
azz = linspace(-gaborsize(1)/2, gaborsize(1)/2, texsize);
ell = linspace( -gaborsize(2)/2, gaborsize(2)/2, texsize);
[gabor,gauss,grate] = vis.gabor(azz, ell, 10, 10, 10, 0, 0, 0);
% gabor(1:512,510:514) = 1;
% gabor(510:514,513:1024) = 1;
% gabrgba = repmat(uint8(floor(255*gabor)), [1 1 3]);
% gabrgba(:,:,4) = 255;
% gabrgba = permute(gabrgba(end:-1:1,:,:), [3 2 1]);

% sine pattern
sf = 1/360;
wave = 0.5*(cos(2*pi*sf*linspace(-180, 180, 100)) + 1);


% grid pattern
n = 6;
gridimg = ones(texsize);
x = round(linspace(1, texsize, 2*n+1));
y = round(linspace(1, texsize, n+1));
gridimg(:,x) = 0;
gridimg(y,:) = 0;

% % turn it into an RGBA uint8 and load
% gridrgba = repmat(uint8(floor(255*grid)), [1 1 4]);
% gridrgba(:,:,4) = 255 - gridrgba(:,:,4);
% gridrgba = permute(gridrgba(end:-1:1,:,:), [3 2 1]);

% scVertexUV = 1*(h.vertexUV - 0.5) + 0.5;
% glBindBuffer(GL.ARRAY_BUFFER, h.uvBufferObject);
% glBufferData(GL.ARRAY_BUFFER, 4*numel(scVertexUV), single(scVertexUV), GL.STATIC_DRAW);
% glBindBuffer(GL.ARRAY_BUFFER, 0);

Screen('BeginOpenGL', w.PtbHandle);
% grid texture
gridLayer = vizLayer(gridimg, 1 - gridimg, [360 180], [0 0], false);
gaborLayer = vizLayer(0.5*ones(size(gauss)), 1 - gauss, gaborsize, [0 0], false);
gratingLayer = vizLayer(wave, 1, [360 180], [0 0], true);


% glBindTexture(GL.TEXTURE_2D, gridtex);
% glTexImage2D(GL.TEXTURE_2D, 0, GL.RGBA, size(grid,2), size(grid,1), 0, GL.RGBA,...
%   GL.UNSIGNED_BYTE, gridrgba(:));
% glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
% glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
% % gabor texture
% glBindTexture(GL.TEXTURE_2D, gabtex);
% glTexImage2D(GL.TEXTURE_2D, 0, GL.RGBA, size(gabor,2), size(gabor,1), 0, GL.RGBA,...
%   GL.UNSIGNED_BYTE, gabrgba(:));
% glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
% glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
% glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_BORDER);
% glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_BORDER);
% glTexParameterfv(GL.TEXTURE_2D, GL.TEXTURE_BORDER_COLOR, single([0 0 0 0]));
Screen('EndOpenGL', w.PtbHandle);

%% draw it
up = 0;
right = 0;
h.view = rotRadZ(deg2rad(-up))*rotRadY(deg2rad(-right))*rotRadX(deg2rad(0));
% layer params
gratingLayer.size = [10 180];
t = 0*360;
% gratingLayer.offset = [gratingLayer.size(1)*t/360 0];
% gratingLayer.texOffset = [0 0];
% stimpos = [30 30];
% gratingLayer.texOffset = [0 0];
% gratingLayer.pos = [0 0];
% gridLayer.texOffset = [0 0];
% gratingLayer.viewAngle = 0;

% gaborLayer.texOffset = [0 0];
% gridLayer.texOffset = [0 0];
% gridLayer.viewAngle = 0;
% gridLayer.texAngle = 0;
gratingLayer.texAngle = 90;
gridLayer.pos = 0*[30 30];
gridLayer.texOffset = 0*[30 30];
gaborLayer.pos = 1*[30 30];
gaborLayer.texOffset = 0*[30 30];
layers = [gratingLayer gaborLayer gridLayer];
%
nreps = 100;
tic
for i = 1:nreps
  vizDraw(w, h, layers);
end
1000*toc/nreps
% 

flip(w);