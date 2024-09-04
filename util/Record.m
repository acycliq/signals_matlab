classdef Record < handle
  %EXP.RECORD Summary of this class goes here
  %   Detailed explanation goes here
  
  properties (SetAccess = protected)
    FieldNames = java.util.ArrayList()
    DataMaps
    Size
  end
  
%   events
%     NewField
%   end
  
  methods
    function this = Record(from)
      if nargin == 0
        from = struct;
      end
%       
%       if isa(from, java.util.List)
%         
%       else
%         this.DataMaps = 
%       end
%       if nargin == 0
%         this.Size = [1 1];
%       else
%         this.Size = cell2mat(varargin);
%       end
%       n = prod(this.Size);
%       this.DataMaps = java.util.ArrayList(n);
%       for ii = 1:n % build list of Maps
%         this.DataMaps.add(java.util.HashMap);
%       end
    end
  end
  
  methods (Sealed)
    function out = subsasgn(this, s, varargin)
      out = this;
      assert(numel(varargin)==1, 'TO DO: make work on arrays');
      b = varargin{1};
      field = s.subs;
      if isstruct(b)
        [m, fields] = structToJavaMap(b);
        jml.Collections.putAll(get(this.DataMaps, 0), {field}, {m}, isrow(b), iscolumn(b));
        jml.Collections.put(get(this.DataMaps, 0), [field '/fieldnames'], fields);
        jml.Collections.put(get(this.DataMaps, 0), [field '/size'], size(b));
      else
        jml.Collections.putAll(get(this.DataMaps, 0), {field}, {b}, isrow(b), iscolumn(b));
      end
      wasField = isfield(this, field);
      if ~wasField
        add(this.FieldNames, java.lang.String(field));
      end
    end

    function varargout = subsref(this, s)
      assert(~strcmp(s(1).type, '()'), 'TO DO: make work on arrays');
      working = this.DataMaps.get(0);
      si = 1;
      while si <= length(s)
        if isa(working, 'java.util.Map')
          switch s(si).type
            case'.'
              field = s(si).subs;
              if jml.Collections.containsKey(working, field)
                sz = jml.Collections.get(working, [field '/size']);
                fn = cell(jml.Collections.get(working, [field '/fieldnames']));
                working = jml.Collections.get(working, field);
                if length(s) >= si+2
                  % value exists so eliminate any subsequent or_(..) subs
                  if strcmp(s(si+1).type, '.') && strcmp(s(si+1).subs, 'or_') ...
                      && strcmp(s(si+2).type, '()')
                    s(si+1:si+2) = [];
                  end
                end
              else
                working = Option.None;
              end
          end
        elseif isa(working, 'java.util.List')
          disp('x');
        else
          s_remain = s(si:end);
          if ~isempty(s_remain)
            [varargout{1:nargout}] = subsref(working, s_remain);
            return
          end
        end
        si = si + 1;
      end
      if isa(working, 'java.util.ArrayList')
        working = reshape(javaMapsToStruct(working, fn), sz);
      end
      varargout = {working};
    end
    
    function b = isfield(this, name)
      b = contains(this.FieldNames, java.lang.String(name));
    end
    
    function names = fieldnames(this)
      names = cell(jml.Collections.toStringArray(this.FieldNames));
    end
  end
  
end

