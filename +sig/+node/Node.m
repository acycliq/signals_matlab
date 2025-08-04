classdef Node < handle
  %NODE Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    FormatSpec
    % The nodes (and their ordering) which are presented as inputs, e.g.
    % used in formatting the name of the node, or in a GUI
    DisplayInputs
    Listeners
    transFun
    transArg
    transferMethodHandle  % Method handle (developer's approach)
    Id
    currValue = sig.NotSet()
    hasCurrValue = false       % Boolean flag for currValue checking
    workingValue = sig.NotSet() % Working value for two-phase computation
    hasWorkingValue = false    % Boolean flag for workingValue checking
    Targets % will keep the input nodes (aka children)
  end
  
  properties (SetAccess = immutable)
    Net sig.Net % Parent network
    Inputs sig.node.Node % Array of input nodes
  end
  
  properties (SetAccess = private, Transient)
    NetId double
  end
  
  properties (Dependent)
    Name
  end
  
  properties (Access = private)
    NameOverride
    NetListeners
  end
  
  methods
    function this = Node(srcs, transFun, transArg, appendValues)
      if isa(srcs, 'sig.Net')
        this.Net = srcs;
        this.Inputs = sig.node.Node.empty;
      else % assume srcs is an array of input nodes
        this.Inputs = srcs;
        this.Net = unique([this.Inputs.Net]);
        assert(numel(this.Net) == 1);
      end
      this.DisplayInputs = this.Inputs;
      this.NetId = this.Net.Id;
      inputids = [this.Inputs.Id];
      if nargin < 2
        transFun = 'sig.transfer.nop';
      end
      if nargin < 3
        transArg = [];
      end
      if nargin < 4
        appendValues = false;
      end
      opCode = sig.node.transfererOpCode(transFun, transArg);
      this.NetListeners = event.listener(this.Net, 'Deleting', @this.netDeleted);
      this.transFun = transFun;
      this.transArg = transArg;
      
      % Create method reference for transfer function
      C = strsplit(transFun, '.');  % for example strip-split: 'sig.transfer.mapn'
      if length(C) >= 3 && strcmp(C{1}, 'sig') && strcmp(C{2}, 'transfer')
        mstr = C{end}; % e.g. 'mapn'
        switch mstr
          case 'mapn'
            this.transferMethodHandle = @this.mapn;     % Direct method handle
          case 'nop'
            this.transferMethodHandle = @this.nop;      % Direct method handle  
          case 'identity'
            this.transferMethodHandle = @this.identity; % Direct method handle
          otherwise
            error('Transfer function %s not implemented as Node method', transFun);
        end
      else
        error('Non-transfer function %s not supported', transFun);
      end
      this.Targets = {};
      this.Net.addNode(this);
    end
    
    function v = get.Name(this)
      if ~isempty(this.NameOverride)
        v = this.NameOverride;
      else
        childNames = names(this.DisplayInputs);
        v = sprintf(this.FormatSpec, childNames{:});
      end
    end
    
    function set.Name(this, v)
      this.NameOverride = v;
    end
    
    function delete(this)
      if ~isempty(this.Id)
        fprintf('Deleting node ''%s''\n', this.Name);
        this.Net.nodes{this.Id} = [];
      end
    end

    
    function n = names(those)
      n = cell(numel(those), 1);
      for i = 1:numel(those)
        n{i} = those(i).Name;
      end
    end
    
    function setInputs(this, nodes)
    end
    
    function setCurrValue(this, value)
        % Setter that manages both value and flag
        this.currValue = value;
        this.hasCurrValue = true;
    end
    
    function setWorkingValue(this, value)
        % Setter for working values in two-phase computation
        this.workingValue = value;
        this.hasWorkingValue = true;
    end
    
    function commitWorkingValue(this)
        % Copy working value to current value and clear (like MEX)
        if this.hasWorkingValue
            this.setCurrValue(this.workingValue);
            % Clear working value after application (like MEX does)
            this.workingValue = sig.NotSet();
            this.hasWorkingValue = false;
        end
    end
    
    function valset = mapn(this)
      % Transfer function as Node method (two-phase working values)
      % Apply values of inputs through mapn function
      [f, outnum] = this.transArg{:}; % Get from node property
      n = numel(this.Inputs);
      inpvals = cell(n, 1);
      
      % Get input values (pure boolean check for maximum performance)
      for inp = 1:n
        node = this.Inputs(inp);
        if node.hasCurrValue
          inpvals{inp} = node.currValue;
        else
          valset = false;
          return; % Missing input value, can't compute
        end
      end
      
      % All inputs have values, apply the function directly
      try
        out = cell(1, outnum);
        [out{:}] = f(inpvals{:});
        this.setWorkingValue(out{end});  % Store in working value (phase 1)
        valset = true;
      catch ex
        msg = sprintf('Error in mapn for node %s: %s', this.Name, ex.message);
        warning(msg);
        valset = false;
      end
    end
    
    function valset = nop(this)
      % NOP Transfer function - performs no operation
      % Always returns false (no value set)
      valset = false;
    end
    
    function valset = identity(this)
      % IDENTITY Transfer function - passes input value to output (two-phase)
      if numel(this.Inputs) >= 1
        input = this.Inputs(1);
        if input.hasCurrValue  % Use boolean check
          this.setWorkingValue(input.currValue);  % Store in working value
          valset = true;
        else
          valset = false;
        end
      else
        valset = false;
      end
    end
    

  end
  
  methods (Access = protected)
    function netDeleted(this, ~, ~)
      if isvalid(this)
        this.Id = [];
      end
    end
  end
end

