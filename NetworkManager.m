classdef NetworkManager < handle
    properties (Access = private)
        networks
        maxNetworks = 10
    end
    
    methods
        function obj = NetworkManager()
            obj.networks = cell(1, obj.maxNetworks);
        end
        
        function netId = createNetwork(obj, size)
            netId = find(cellfun(@isempty, obj.networks), 1);
            if isempty(netId)
                error('Maximum number of networks reached');
            end
            obj.networks{netId} = struct('nodes', {cell(1, size)}, 'nNodes', size, 'active', true, 'deleteCallback', []);
        end
        
        function deleteNetwork(obj, netId)
            if netId > 0 && netId <= obj.maxNetworks && ~isempty(obj.networks{netId})
                if ~isempty(obj.networks{netId}.deleteCallback)
                    feval(obj.networks{netId}.deleteCallback);
                end
                obj.networks{netId} = [];
            else
                error('Invalid network ID');
            end
        end
        
        function nodeId = addNode(obj, netId, inputs, transferFun, appendValues)
            network = obj.networks{netId};
            nodeId = find(cellfun(@isempty, network.nodes), 1);
            if isempty(nodeId)
                error('Maximum number of nodes reached for this network');
            end
            if isempty(inputs)
                inputs = [];
            end
            network.nodes{nodeId} = struct('id', nodeId, 'inputs', inputs, 'transferFun', transferFun, 'appendValues', appendValues, 'workingValue', [], 'currValue', []);
        end
        
        function applyNodes(obj, netId, nodeIds)
            network = obj.networks{netId};
            for i = 1:length(nodeIds)
                node = network.nodes{nodeIds(i)};
                inputValues = cellfun(@(x) obj.getNodeWorkingValue(netId, x), node.inputs, 'UniformOutput', false);
                newValue = feval(node.transferFun, inputValues{:});
                obj.setNodeCurrValue(netId, nodeIds(i), newValue);
            end
        end
        
        function [value, isSet] = getNodeCurrValue(obj, netId, nodeId)
            node = obj.networks{netId}.nodes{nodeId};
            value = node.currValue;
            isSet = ~isempty(value);
        end
        
        function [value, isSet] = getNodeWorkingValue(obj, netId, nodeId)
            node = obj.networks{netId}.nodes{nodeId};
            value = node.workingValue;
            isSet = ~isempty(value);
        end
        
        function setNodeWorkingValue(obj, netId, nodeId, value)
            obj.networks{netId}.nodes{nodeId}.workingValue = value;
        end
        
        function setNodeCurrValue(obj, netId, nodeId, value)
            obj.networks{netId}.nodes{nodeId}.currValue = value;
        end
        
        function clearNodeWorkingValue(obj, netId, nodeId)
            obj.networks{netId}.nodes{nodeId}.workingValue = [];
        end
        
        function submit(obj, netId, nodeId, value)
            obj.setNodeWorkingValue(netId, nodeId, value);
            obj.applyNodes(netId, nodeId);
        end
        
        function setNodeEventTarget(obj, netId, nodeId, target)
            obj.networks{netId}.nodes{nodeId}.eventTarget = target;
        end
        
        function inputs = getNodeInputs(obj, netId, nodeId)
            inputs = obj.networks{netId}.nodes{nodeId}.inputs;
        end
        
        function setNodeInputs(obj, netId, nodeId, inputs)
            obj.networks{netId}.nodes{nodeId}.inputs = inputs;
        end
        
        function setNetworkDeleteCallback(obj, netId, callback)
            if netId > 0 && netId <= obj.maxNetworks && ~isempty(obj.networks{netId})
                obj.networks{netId}.deleteCallback = callback;
            else
                error('Invalid network ID');
            end
        end
        
        function deleteAllNetworks(obj)
            for i = 1:obj.maxNetworks
                if ~isempty(obj.networks{i})
                    obj.deleteNetwork(i);
                end
            end
        end
        
        function deleteNode(obj, netId, nodeId)
            if netId > 0 && netId <= obj.maxNetworks && ~isempty(obj.networks{netId})
                obj.networks{netId}.nodes{nodeId} = [];
            else
                error('Invalid network ID or node ID');
            end
        end
        
        function displayNetworkInfo(obj, netId)
            if netId > 0 && netId <= obj.maxNetworks && ~isempty(obj.networks{netId})
                network = obj.networks{netId};
                fprintf('Network %d:\n', netId);
                fprintf('  Number of nodes: %d\n', network.nNodes);
                fprintf('  Active: %d\n', network.active);
            else
                error('Invalid network ID');
            end
        end
        
        function displayNodeInfo(obj, netId, nodeId)
            if netId > 0 && netId <= obj.maxNetworks && ~isempty(obj.networks{netId})
                node = obj.networks{netId}.nodes{nodeId};
                if ~isempty(node)
                    fprintf('Node %d in Network %d:\n', nodeId, netId);
                    fprintf('  Inputs: %s\n', mat2str(node.inputs));
                    fprintf('  Transfer Function: %s\n', func2str(node.transferFun));
                    fprintf('  Append Values: %d\n', node.appendValues);
                else
                    error('Invalid node ID');
                end
            else
                error('Invalid network ID');
            end
        end
    end
end