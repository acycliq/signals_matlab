function networkInfoImpl(netId, nodeId)
    manager = sig.getNetworkManager();
    if nargin < 2
        manager.displayNetworkInfo(netId);
    else
        manager.displayNodeInfo(netId, nodeId);
    end
end