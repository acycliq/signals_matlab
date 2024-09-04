function c = or_(a, b)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

if ~isa(a, 'jml.Types.EMPTY')
  c = a;
else
  c = b;
end

end

