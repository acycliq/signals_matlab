function networkId = createNetworkImpl(size, deleteCallback)
    if nargin < 1
        size = 4000;
    end
    
    manager = sig.getNetworkManager();
    networkId = manager.createNetwork(size);
    
    if nargin >= 2 && ~isempty(deleteCallback)
        manager.setNetworkDeleteCallback(networkId, deleteCallback);
    end
    
    % Set up cleanup on MATLAB exit
    persistent isExitFunctionSet
    if isempty(isExitFunctionSet)
        exitFunc = @() manager.deleteAllNetworks();
        matlab.unittest.fixtures.GlobalFixture.setFixture(matlab.unittest.fixtures.ExitFixture(exitFunc));
        isExitFunctionSet = true;
    end
end