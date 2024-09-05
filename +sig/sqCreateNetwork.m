function net = sqCreateNetwork(networkSize, deleteCallback)
    persistent networks;  % Persistent variable to store networks
    MAX_NETWORKS = 10;   % Define the maximum number of networks

    if isempty(networks)
        networks = repmat({struct('active', false)}, MAX_NETWORKS, 1); % Preallocate with inactive networks
    end
    
    % Find the next free network slot
    net = nextFreeNetwork();

    if net >= 0
        % Initialize an array of Node structs
        nodes = cell(networkSize, 1);
        for i = 1:networkSize
            nodes{i} = createNode(net, i); % Create each node with network id and node id
        end
        
        % Initialize the network structure
        networkStruct.nodes = nodes;                   % Store the array of nodes
        networkStruct.nNodes = networkSize;            % Store the number of nodes
        networkStruct.deleteCallback = deleteCallback; % Store the delete callback
        networkStruct.active = true;                   % Mark the network as active

        % Store the network in the networks array
        networks{net} = networkStruct;
    else
        net = -1; % If no free slot was found, return -1
    end
    
    
    % Nested function to find the next free slot
    function idx = nextFreeNetwork()
        for j = 1:MAX_NETWORKS
            if ~networks{j}.active
                idx = j;
                return;
            end
        end
        idx = -1; % Return -1 if no free network slot is found
    end

    call_this(networks)
end




% function to create a new Node
function nodeStruct = createNode(netId, id)
    nodeStruct.netId = netId;                  % Network ID
    nodeStruct.id = id;                        % Node ID
    nodeStruct.currValue = [];                 % Current value, initialized to empty
    nodeStruct.workingValue = [];              % Working value, initialized to empty
    nodeStruct.inputs = {};                    % Inputs, as an empty cell array
    nodeStruct.nInputs = 0;                    % Number of inputs
    nodeStruct.targets = {};                   % Targets, as an empty cell array
    nodeStruct.nTargets = 0;                   % Number of targets
    nodeStruct.transferer = [];                % Placeholder for Transferer, assuming function handle or similar
    nodeStruct.eventsTarget = [];              % Events target, initialized to empty
    nodeStruct.inUse = false;                  % Node is initially not in use
    nodeStruct.queued = false;                 % Not queued by default
    nodeStruct.appendValues = false;           % No appending by default
    nodeStruct.currValueAllocElems = 0;        % No elements allocated yet
end


function out = call_this(n)
    disp('yes')
end
    