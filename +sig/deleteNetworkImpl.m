function deleteNetworkImpl(netId)
    manager = sig.getNetworkManager();
    if nargin == 0
        manager.deleteAllNetworks();
    else
        manager.deleteNetwork(netId);
    end
end