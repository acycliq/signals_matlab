function manager = getNetworkManager()
    persistent networkManager
    if isempty(networkManager)
        networkManager = NetworkManager();
    end
    manager = networkManager;
end