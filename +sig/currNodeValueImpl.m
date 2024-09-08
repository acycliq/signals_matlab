function [value, isSet] = currNodeValueImpl(netId, nodeId)
    manager = sig.getNetworkManager();
    value = manager.getNodeCurrValue(netId, nodeId);
    isSet = ~isempty(value);
end