classdef Ref < expr.Expr
  %UNTITLED7 Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    Subsref
  end
  
  properties
    Reserved = {'Subsref'}
  end
  
  methods
    function obj = Ref(name)
      if nargin > 0 && ~isempty(name)
        obj.Subsref = struct('type', '.', 'subs', name);
      end
    end

    function varargout = subsref(obj, s)
      if s(1).type == '.' && any(strcmp(s(1).subs, obj.Reserved))
        obj = builtin('subsref', obj, s(1));
        if numel(s) > 1
%           [varargout{1:numel(obj)}] = subsref@expr.Expr(obj, s(2:end))
          [varargout{1:numel(obj)}] = builtin('subsref', obj, s(2:end));
        else
          varargout = {obj};
        end
      else
        b = expr.Ref;
        b.Subsref = [obj.Subsref s];
        varargout = {b};
      end
    end

    function var = resolve(obj, scope)
      var = subsref(scope, obj.Subsref);
    end
    
    function s = str(obj)
      subs = obj.Subsref;
      n = numel(subs);
      elems = cell(1, n);
      for ii = 1:n;
        type = subs(ii).type;
        switch type
          case '.'
            if ii > 1
              elems{ii} = ['.' subs(ii).subs];
            else
              % assume first dot subscripts the scope, prefix with ` instead
              elems{ii} = ['`' subs(ii).subs];
            end
          case '()'
            elems{ii} = ['(' strJoin(subs(ii).subs, ',') ')'];
          case '{}'
            elems{ii} = ['{' strJoin(subs(ii).subs, ',') '}'];
        end
      end
      s = strJoin(elems, '');
    end
  end
  
end

