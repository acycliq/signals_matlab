function deleteNodeImpl(netId, nodeId)
    nm = sig.getNetworkManager();
    if netId > 0 && netId <= nm.maxNetworks && ~isempty(nm.networks{netId})
        nm.networks{netId}.nodes{nodeId} = [];
    else
        error('Invalid network ID or node ID');
    end
%     manager.deleteNode(netId, nodeId);
end