classdef TernaryOp < expr.Expr
  %UNTITLED Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    First
    Second
    Third
    Fun
    Format
  end
  
  methods
    function obj = TernaryOp(first, second, third, fun, format)
      if ~isa(first, 'expr.Expr')
        first = sym.Value(first);
      end
      if ~isa(second, 'expr.Expr')
        second = sym.Value(second);
      end
      if ~isa(third, 'expr.Expr')
        third = sym.Value(third);
      end
      obj.First = first;
      obj.Second = second;
      obj.Third = third;
      obj.Fun = fun;
      obj.Format = format;
    end
    
    function var = resolve(obj, scope)
      var = obj.Fun(resolve(obj.First, scope),...
        resolve(obj.Second, scope), resolve(obj.Third, scope));
    end
    
    function s = str(obj)
      s = sprintf(obj.Format, str(obj.First), str(obj.Second), str(obj.Third));
    end
  end
  
end

