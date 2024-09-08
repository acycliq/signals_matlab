function deleteNodeImpl(netId, nodeId)
    manager = sig.getNetworkManager();
    manager.deleteNode(netId, nodeId);
end