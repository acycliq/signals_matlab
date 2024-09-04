% TidyHandle test
count = 5;
m = containers.Map(1:count, rand(1,count));
h = TidyHandle(@() m.remove(count));

assert(m.length == count, 'Task executed too early')
h2 = h;
clear('h')
assert(m.length == count, 'Task executed too early')

clear('h2')
assert(m.length == count-1, 'Task failed to execute')

% Test value clearance
count = m.length;
h = TidyHandle(@() m.remove(count), TidyHandle(@() m.remove(count-1)));
assert(m.length == count, 'Task executed too early')
clear('h')
assert(m.length == count-2, 'Task failed to execute')
