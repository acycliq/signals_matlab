function [value, isSet] = workingNodeValueImpl(netId, nodeId, setValue, newValue)
    manager = sig.getNetworkManager();
    if nargin < 4
        value = manager.getNodeWorkingValue(netId, nodeId);
        isSet = ~isempty(value);
    else
        manager.setNodeWorkingValue(netId, nodeId, newValue);
        value = newValue;
        isSet = true;
    end
end