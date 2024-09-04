% rotRad(X,Y,Z) test
% Tests the transformation matrices to to some precision for 0 and pi.

% prerequisites:
s = 1.2246e-16; % Sin(pi) to 20 placed
n = 20; % Number of decimal places to test to

%% rotRadX test
assert(isequal(rotRadX(0), eye(4)))
expected = [1 0 0 0; 0 -1 -s 0; 0 s -1 0; 0 0 0 1];
actual = round(rotRadX(pi), n); 
assert(isequal(actual, expected))

%% rotRadY test
assert(isequal(rotRadY(0), eye(4)))
expected = [-1 0 s 0; 0 1 0 0; -s 0 -1 0; 0 0 0 1];
actual = round(rotRadY(pi), n); 
assert(isequal(actual, expected))

%% rotRadZ test
assert(isequal(rotRadZ(0), eye(4)))
expected = [-1 -s 0 0; s -1 0 0; 0 0 1 0; 0 0 0 1];
actual = round(rotRadZ(pi), n); 
assert(isequal(actual, expected))
