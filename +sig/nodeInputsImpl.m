function inputs = nodeInputsImpl(netId, nodeId, newInputs)
    manager = sig.getNetworkManager();
    if nargin < 3
        inputs = manager.getNodeInputs(netId, nodeId);
    else
        manager.setNodeInputs(netId, nodeId, newInputs);
        inputs = newInputs;
    end
end