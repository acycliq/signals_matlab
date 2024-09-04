classdef BinaryOp < expr.Expr
  %UNTITLED2 Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    Left
    Right
    Fun
    Format
  end
  
  methods
    function obj = BinaryOp(left, right, fun, format)
      if ~isa(left, 'expr.Expr')
        left = expr.Value(left);
      end
      if ~isa(right, 'expr.Expr')
        right = expr.Value(right);
      end
      obj.Left = left;
      obj.Right = right;
      obj.Fun = fun;
      obj.Format = format;
    end

    function var = resolve(obj, scope)
      var = obj.Fun(resolve(obj.Left, scope), resolve(obj.Right, scope));
    end
    
    function s = str(obj)
      s = sprintf(obj.Format, str(obj.Left), str(obj.Right));
    end
  end
  
end

