% mergeStruct test
% preconditions: set up some scalar structs
names = mapToCell(@char,97:122); 
A = cell2struct(mapToCell(@(~)rand(10,1),1:10)', names(1:10)');
B = cell2struct(mapToCell(@(~)rand(10,1),1:10)', names(6:15)');
C = cell2struct(mapToCell(@(~)rand(10,1),1:3)', names(9:11)');

% FETCH returns the value of field f, looking first in struct x and if not
% there then struct y
fetch = @(f,x,y)iff(isfield(x,f), @()x.(f), @()y.(f));

%% Test1: cell2struct method
s = mergeStruct(B, A);
assert(isequal(sort(fieldnames(s)), unique([fieldnames(A); fieldnames(B)])), ...
  'Not all fields were merged') % Check fields

correct = cellfun(@(f)isequal(s.(f), fetch(f,A,B)), fieldnames(s));
assert(all(correct), 'Unexpected field values') % Check values

% Test order precedence
shared = intersect(fieldnames(A), fieldnames(B));
% Check values in shared fields of s come from struct y
checkOrder = @(s,y) all(cellfun(@(f)isequal(s.(f), y.(f)), shared));
assert(checkOrder(s,A) && checkOrder(mergeStruct(A,B),B), 'Failed order precedence')

%% Test 2: direct update method
% Occurs when src has less than half the number of fields
s = mergeStruct(A, C);
assert(isequal(sort(fieldnames(s)), unique([fieldnames(A); fieldnames(C)])), ...
  'Not all fields were merged') % Check fields

correct = cellfun(@(f)isequal(s.(f), fetch(f,C,A)), fieldnames(s));
assert(all(correct), 'Unexpected field values') % Check values
