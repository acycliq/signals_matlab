function id = network_uid()
    % Create a new network and return its unique identifier

    persistent networkCounter;
    if isempty(networkCounter)
        networkCounter = 0;
    end
    networkCounter = networkCounter + 1;

    % network is persistent, assign it to id and return
    id = networkCounter;

end