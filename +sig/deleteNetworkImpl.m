function deleteNetworkImpl(netId)
nm = sig.getNetworkManager();
if nargin == 0
    nm.deleteAllNetworks();
else
    if netId > 0 && netId <= nm.maxNetworks && ~isempty(nm.networks{netId})
        delete(nm.networks{netId});  % Call delete method of Net object
        nm.networks{netId} = [];
    else
%        do nothing
    end
end
end