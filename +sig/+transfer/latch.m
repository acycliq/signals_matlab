function [val, valset] = latch(net, inputs, node, ~)
% SIG.TRANSFER.LATCH Summary of this function goes here
%   Detailed explanation goes here

% always assumes two inputs: [arm, release]
[arm, armSet] = workingNodeValue(net, inputs(1));
[release, releaseSet] = workingNodeValue(net, inputs(2));
% current state:
% armed = false when currently released, armed = true when currently armed
armed = currNodeValue(net, node);

tryArm = armSet && arm;
tryRelease = releaseSet && release;

if tryRelease && (tryArm || armed)
  % new arm *and* new release signals -> new release
  % - OR -
  % previously armed *and* new release -> new release
  val = false;
  valset = true;
elseif ~armed && tryArm % previously not armed *and* new arm -> new armed
  val = true;
  valset = true;
else % no latch state change
  val = [];
  valset = false;
end

end