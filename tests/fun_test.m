% +fun package test
%% Test 1: fun.always
v = rand;
f = fun.always(v);

assert(isa(f, 'function_handle'), 'Failed to return function handle')
assert(isequal(f(), f(rand), v), 'Failed to return value on evaluation')

%% Test 2: fun.partial
A = magic(3);
f = fun.partial(@max, A, []);
assert(isa(f, 'function_handle'), ...
  'Unexpected output: expected function handle but returned %s', class(f))

assert(all(f(1) == max(A, [], 1)), 'Unexpected output on evaluation')
[~, I] = f(2); % Test multiple output assignment
[~, expected] = max(A, [], 2);
assert(all(I == expected), 'Unexpected output on evaluation')


