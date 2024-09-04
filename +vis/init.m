function h = init(win)

global GL

winRect = Screen('Rect', win);
% bgColour = win.BackgroundColour;

[winw, winh] = RectSize(winRect);
aspectRatio = winw/winh;

%% initialization
% load the shader
shadir = fileparts(mfilename('fullpath'));
glsl = LoadGLSLProgramFromFiles(fullfile(shadir, 'slimshady'), 1);
assert(strcmp(gluErrorString, 'no error'), ...
  'signals:vis:init:shaderLoadFail', ['Failed to load the shader: ' gluErrorString])

% location indices to shader variables: allows us to set the variables used
% by the shader later on, using glUniform() (see vis.draw).
texIdx = glGetUniformLocation(glsl, 'myTextureSampler');
vertexPosIdx = glGetAttribLocation(glsl, 'vertexPos');
uvIdx = glGetAttribLocation(glsl, 'vertexUV');
% colourIdx = glGetAttribLocation(glsl, 'vertexColor');
modelIdx = glGetUniformLocation(glsl, 'model');
% posIdx = glGetUniformLocation(glsl, 'pos');
viewIdx = glGetUniformLocation(glsl, 'view');
projectionIdx = glGetUniformLocation(glsl, 'projection');
texAngleIdx = glGetUniformLocation(glsl, 'texAngle');
texSizeIdx = glGetUniformLocation(glsl, 'texSize');
texOffsetIdx = glGetUniformLocation(glsl, 'texOffset');
minColourIdx = glGetUniformLocation(glsl, 'minColor');
maxColourIdx = glGetUniformLocation(glsl, 'maxColor');
% create some object handles
uvBufferObject = glGenBuffers(1);
posBufferObject = glGenBuffers(1);
elementBuffer = glGenBuffers(1);

h = struct;

h.glsl = glsl;
h.texIdx = texIdx;
h.vertexPosIdx = vertexPosIdx;
% h.posIdx = posIdx;
h.viewIdx = viewIdx;
h.uvIdx = uvIdx;
h.winSize = [winw, winh];
% h.viewIdx = viewIdx;
h.modelIdx = modelIdx;
h.projectionIdx = projectionIdx;
h.texAngleIdx = texAngleIdx;
h.texSizeIdx = texSizeIdx;
h.texOffsetIdx = texOffsetIdx;
h.minColourIdx = minColourIdx;
h.maxColourIdx = maxColourIdx;
h.uvBufferObject = uvBufferObject;
h.posBufferObject = posBufferObject;
h.elementBuffer = elementBuffer;

%% load data
%vertex pos
h.sphereN = 101;
[x, y, z, u, v, tridx] = vis.uniSphereTriangles(1, h.sphereN);
h.vertexXYZ = cat(3, x, y, z); 


h.tridx = tridx;

% [x, y, z, u, v, tridx] = cubeMesh;
% rotation hack to look z upwards, y depthward
vertexPos = [x(:) -z(:) y(:)]';
vertexPos = -vertexPos; %invert cos we want the inside
vertexUV = [u(:) 1-v(:)]';
h.vertexUV = vertexUV;

% Load Position Buffer
glBindBuffer(GL.ARRAY_BUFFER, posBufferObject);
glBufferData(GL.ARRAY_BUFFER, 4*numel(vertexPos), single(vertexPos(:)), GL.STATIC_DRAW);
glBindBuffer(GL.ARRAY_BUFFER, 0);

% Load UV Buffer
glBindBuffer(GL.ARRAY_BUFFER, uvBufferObject);
glBufferData(GL.ARRAY_BUFFER, 4*numel(vertexUV), single(vertexUV), GL.STATIC_DRAW);
glBindBuffer(GL.ARRAY_BUFFER, 0);

% Load Index Buffer
tridx = uint16(tridx(:) - 1); % C indexing starts from zero
glBindBuffer(GL.ELEMENT_ARRAY_BUFFER, elementBuffer);
glBufferData(GL.ELEMENT_ARRAY_BUFFER, numel(tridx)*2, tridx, GL.STATIC_DRAW);
glBindBuffer(GL.ARRAY_BUFFER, 0);

Screen('BeginOpenGL', win);
% setup culling of back faces
glFrontFace(GL.CW);
glEnable(GL.CULL_FACE);
glCullFace(GL.BACK);
%turn on alpha blending
glEnable(GL.BLEND);

% prepare vertex array object
h.vao = glGenVertexArrays(1);
glBindVertexArray(h.vao);
% vertex xyz coords
glBindBuffer(GL.ARRAY_BUFFER, posBufferObject);
glEnableVertexAttribArray(vertexPosIdx);
glVertexAttribPointer(vertexPosIdx, size(vertexPos, 1), GL.FLOAT, GL.FALSE, 0, 0);

% vertex tex uv coords
glBindBuffer(GL.ARRAY_BUFFER, uvBufferObject);
glEnableVertexAttribArray(uvIdx);
glVertexAttribPointer(uvIdx, size(vertexUV, 1), GL.FLOAT, GL.FALSE, 0, 0);

% indexing
glBindBuffer(GL.ELEMENT_ARRAY_BUFFER, elementBuffer);

glBindVertexArray(0);

% texture unit?
glActiveTexture(GL.TEXTURE0);

Screen('EndOpenGL', win);

%% ********* setup the model *************
sz = 400; % cm
mscale = diag([sz sz sz 1]);
mrot = eye(4);
mtrans = eye(4);
%mtrans(1:3,end) = [0 0 (-10 - 0.5*sz)];

model = mtrans*mrot*mscale;

% ********* setup the view *************
% view = eye(4); % view == world

% ********* setup the projection *************
% direction from eye to projection plane
% centre of projection/screen eye space pointing along projection normal

% details of projection/screen
% current parameters for ZOOLANDER 20/07/2014
% 1.25cm right from centre(x)
% -2.5cm down from centre (y)
% 12cm from screen plane (z)
Pw = 47.5;
Pcen = [-1.25 2.5 12];

% lets make three subscreens with different view angles
nscrs = 1;
scrw = winw/nscrs;
% scrar = scrw/winh;
Psz = [Pw/nscrs Pw/aspectRatio];
screens = struct;
for i = 0:(nscrs - 1)
  screens(i+1).bounds = [round(i*scrw), 0, round((i+1)*scrw), winh];
  [screens(i+1).w, screens(i+1).h] = RectSize(screens(i+1).bounds);
  viewaz = i*pi/8 - pi/2;
  screens(i+1).projection = vis.planeProjection(Pcen, Psz, [viewaz 0]);
end

h.screens = screens;
h.model = model;

end