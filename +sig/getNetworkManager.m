function manager = getNetworkManager()
    persistent networkManagerInstance;
    if isempty(networkManagerInstance)
        networkManagerInstance = NetworkManager();
    end
    manager = networkManagerInstance;
end