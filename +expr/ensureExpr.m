function v = ensureExpr(v)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

if ~isa(v, 'sym.Expr')
  v = sym.Value(v);
end

end

