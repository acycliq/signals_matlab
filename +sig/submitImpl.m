function submitImpl(netId, nodeId, value)
    manager = sig.getNetworkManager();
    manager.submit(netId, nodeId, value);
end