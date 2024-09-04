% getOr test
S = struct('a', rand, 'b', rand);
v = getOr(S, 'a');
assert(v == S.a, 'Failed to retrieve value from field')
assert(isempty(getOr(S,'c')), 'Unexpected value returned when field not present')

% Test input default
def = rand;
assert(getOr(S, 'c', def) == def, 'Expected default to be returned')

% Test array of fields
v = getOr(S, {'c', 'b', 'a'});
assert(v == S.b, 'Failed to retrieve value of first present field')

