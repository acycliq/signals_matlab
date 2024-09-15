classdef NetworkManager < handle
    properties
        networks
        maxNetworks = 10
        networkNames containers.Map % New property to store network names
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
            obj.networkNames = containers.Map('KeyType', 'char', 'ValueType', 'uint32');
            set_version(obj)
            disp("Network manager was called")
        end
        
        function createNetwork(obj, name, size)
            if obj.networkNames.isKey(name)
                error('A network with this name already exists');
            end
            
            % Find the first empty slot
            netId = find(cellfun(@isempty, obj.networks), 1);
            if isempty(netId)
                error('Maximum number of networks reached');
            end
            
            % Create the network in the base workspace
            newNet = sig.Net(size, name);
            assignin('base', name, newNet);
            
            % Store the network
            obj.networks{netId} = newNet;
            obj.networkNames(name) = netId;
            
            fprintf('Created network "%s" with ID %d and size %d\n', name, netId, size);
        end

        function deleteNetwork(obj, netId)
            if netId > 0 && netId <= obj.maxNetworks && ~isempty(obj.networks{netId})
                % Find the name associated with this netId
                names = obj.networkNames.keys;
                for i = 1:length(names)
                    if obj.networkNames(names{i}) == netId
                        networkName = names{i};
                        break;
                    end
                end
                
                % Delete the network object
                delete(obj.networks{netId});
                
                % Remove the network from our storage
                obj.networks{netId} = [];
                
                % Remove the name from our map
                if exist('networkName', 'var')
                    remove(obj.networkNames, networkName);
                    
                    % Remove the variable from the base workspace
                    if evalin('base', sprintf('exist(''%s'', ''var'')', networkName))
                        evalin('base', sprintf('clear %s', networkName));
                    end
                    
                    fprintf('Network "%s" (ID: %d) has been deleted and removed from the workspace.\n', networkName, netId);
                else
                    fprintf('Network with ID %d has been deleted.\n', netId);
                end
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