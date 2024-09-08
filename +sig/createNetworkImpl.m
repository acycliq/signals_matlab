function networkId = createNetworkImpl(size, deleteCallback)
    if nargin < 1
        size = 4000;
    end
    
    manager = sig.getNetworkManager();
    networkId = manager.createNetwork(size);
    
    if nargin >= 2 && ~isempty(deleteCallback)
        manager.setNetworkDeleteCallback(networkId, deleteCallback);
    end
    
    % Set up cleanup on MATLAB exit
    persistent cleanupObj
    if isempty(cleanupObj)
        cleanupObj = onCleanup(@() manager.deleteAllNetworks());
    end
end