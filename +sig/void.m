function v = void(cache)
%VOID A signal that never has any values
%   TODO: make it so it really can't be updated!
if nargin < 1; cache = false; end
v = sig.VoidSignal.instance(cache);
end