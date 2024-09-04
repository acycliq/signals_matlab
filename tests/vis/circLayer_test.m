% vis.circLayer test

% preconditions
net = sig.Net;
load(fullfile(fileparts(which('addSignalsPaths')), '\tests\fixtures\data\circle.mat'), 'circle');

%% Test one: standard inputs
pos = [10 5];
dims = [50 50];
ori = 12;
[layer, img] = vis.circLayer(pos, dims, ori);
% Verify layer properties correctly set
assert(strcmp(layer.interpolation, 'linear'), 'interpolation incorrect');
assert(all(layer.texOffset == pos), 'texOffset incorrect');
assert(layer.texAngle == ori, 'texAngle incorrect');
assert(all(layer.size == 50), 'size incorrect');
assert(~layer.isPeriodic, 'isPeriodic set to true');
% Verify image is correct
assert(isa(img, 'single'), 'incorrect type');
assert(isequal(img,circle), 'img incorrect');

%% Test two: Signals inputs
% @todo 'dims' field cannot currently be a signal  
pos = net.origin('position');
dims = [50, 50];
ori = net.origin('orientation');

[layer, img] = vis.circLayer(pos, dims, ori);
pos.post([10, 5]);
ori.post(12);

% Verify layer properties correctly set
assert(all(layer.texOffset.Node.CurrValue == pos.Node.CurrValue), ...
  'texOffset incorrect');
assert(layer.texAngle.Node.CurrValue == ori.Node.CurrValue, ...
  'texAngle incorrect');
assert(all(layer.size == 50), 'size incorrect');
% Verify image is correct
assert(isa(img, 'single'), 'incorrect type');
assert(isequal(img,circle), 'img incorrect');
