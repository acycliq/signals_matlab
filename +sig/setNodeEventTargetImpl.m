function setNodeEventTargetImpl(netId, nodeId, target)
    manager = sig.getNetworkManager();
    manager.setNodeEventTarget(netId, nodeId, target);
end