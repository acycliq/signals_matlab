function networkId = createNetwork(size, deleteCallback)
    % createNetwork Create a new network for managing Signals nodes
    %   Initializes a network of a given size that will contain and manage Signals nodes.
    %
    %   Input:
    %     size (int) : The maximum number of nodes allowed in the network. Default: 4000
    %     deleteCallback (function_handle) : Optional callback function to be called when the network is deleted
    %
    %   Output:
    %     networkId (int) : The unique identifier for the created network
    
    if nargin < 1
        size = 4000;
    end
    
    manager = sig.getNetworkManager();
    networkId = manager.createNetwork(size);
    
    if nargin >= 2 && ~isempty(deleteCallback)
        manager.setNetworkDeleteCallback(networkId, deleteCallback);
    end
end
