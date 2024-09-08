% Create a network
net = sig.Net();

% Create an origin signal
input = net.origin('input');

% Create a derived signal
output = sig.node.Signal(sig.node.Node(net, input.Node, @(x) x * 2));
output.Node.FormatSpec = 'output = input * 2';

% Set a value and observe the result
input.Node.CurrValue = 5;
disp(['Input: ' num2str(input.Node.CurrValue)]);
disp(['Output: ' num2str(output.Node.CurrValue)]);

% Clean up
delete(net);