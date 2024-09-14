classdef NetworkManager < handle
    properties
        networks
        maxNetworks = 10
    end

    properties
        version = []
    end
    
    methods
        function set_version(obj)
            if isempty(obj.version)
                v = rand(1);
                fprintf("NetworkManager version: %g\n",v);
                obj.version = v;
            end
        end

        function obj = NetworkManager()
            obj.networks = cell(1, obj.maxNetworks);
            set_version(obj)
            disp("Network manager was called")
        end
        

        function deleteNetwork(obj, netId)
            if netId > 0 && netId <= obj.maxNetworks && ~isempty(obj.networks{netId})
                delete(obj.networks{netId});  % Call destructor of Net object
            else
                error('Invalid network ID');
            end
        end
        
        function nodeId = addNode(obj, netId, inputs, transferFun, appendValues)
            arguments
                obj NetworkManager

                netId = 1
        
                inputs = []
        
                transferFun = @sig.transfer.nop
        
                appendValues = false
            end

            network = obj.networks{netId};
            nodeId = network.addNode(inputs, transferFun, appendValues);
        end

        function deleteNode(obj, netId, nodeId)
            network = obj.networks{netId};
            delete(network.nodes{nodeId}) % delete the object, the destuctor should be called
        end
        
        function applyNodes(obj, netId, nodeIds)
            network = obj.networks{netId};
            network.applyNodes(nodeIds);  % Use Net's applyNodes method
        end
        
        function [value, isSet] = getNodeCurrValue(obj, netId, nodeId)
            network = obj.networks{netId};
            [value, isSet] = network.getNodeCurrValue(nodeId);  % Use Net's getNodeCurrValue method
        end
        
        function value = getNodeWorkingValue(obj, netId, nodeId)
            network = obj.networks{netId};
            value = network.getNodeWorkingValue(nodeId);  % Use Net's getNodeWorkingValue method
        end
        
        function setNodeWorkingValue(obj, netId, nodeId, value)
            network = obj.networks{netId};
            network.setNodeWorkingValue(nodeId, value);  % Use Net's setNodeWorkingValue method
        end
        
        function setNodeCurrValue(obj, netId, nodeId, value)
            network = obj.networks{netId};
            network.setNodeCurrValue(nodeId, value);  % Use Net's setNodeCurrValue method
        end
        
        function clearNodeWorkingValue(obj, netId, nodeId)
            network = obj.networks{netId};
            network.clearNodeWorkingValue(nodeId);  % Use Net's clearNodeWorkingValue method
        end
        
        function submit(obj, netId, nodeId, value)
            network = obj.networks{netId};
            network.submit(nodeId, value);  % Use Net's submit method
        end
        
        function setNodeEventTarget(obj, netId, nodeId, target)
            network = obj.networks{netId};
            network.setNodeEventTarget(nodeId, target);  % Use Net's setNodeEventTarget method
        end
        
        function inputs = getNodeInputs(obj, netId, nodeId)
            network = obj.networks{netId};
            inputs = network.getNodeInputs(nodeId);  % Use Net's getNodeInputs method
        end
        
        function setNodeInputs(obj, netId, nodeId, inputs)
            network = obj.networks{netId};
            network.setNodeInputs(nodeId, inputs);  % Use Net's setNodeInputs method
        end
        
        function setNetworkDeleteCallback(obj, netId, callback)
            network = obj.networks{netId};
            network.setDeleteCallback(callback);  % Use Net's setDeleteCallback method
        end
        
        function deleteAllNetworks(obj)
            for i = 1:obj.maxNetworks
                if ~isempty(obj.networks{i})
                    obj.deleteNetwork(i);
                end
            end
        end
        
        function displayNetworkInfo(obj, netId)
            network = obj.networks{netId};
            network.displayInfo();  % Use Net's displayInfo method
        end
        
        function displayNodeInfo(obj, netId, nodeId)
            network = obj.networks{netId};
            network.displayNodeInfo(nodeId);  % Use Net's displayNodeInfo method
        end
    end
end