function clearNodeWorkingValueImpl(netId, nodeId)
    manager = sig.getNetworkManager();
    manager.clearNodeWorkingValue(netId, nodeId);
end