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
    transferMethodHandle  % Method handle
    Id
    currValue = sig.Nil.instance()
    workingValue = sig.Nil.instance() % Working value for two-phase computation
    queued = false       % MEX-style queued flag: true if node is currently in processing queue, false otherwise
                        % Prevents duplicate queuing during signal propagation (matches MEX network.c behavior)
    eventsTarget = []    % Signal object that should be notified on value changes (like MEX eventsTarget)
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
      
      % Create method reference for transfer function dynamically
      C = strsplit(transFun, '.');  % for example strip-split: 'sig.transfer.mapn'
      if length(C) >= 3 && strcmp(C{1}, 'sig') && strcmp(C{2}, 'transfer')
        mstr = C{end}; % e.g. 'mapn'
        try
          % Check if method exists on this object
          if ismethod(this, mstr)
            % Create method handle properly - str2func gets the method, @ binds to object
            methodFunc = str2func(mstr);
            this.transferMethodHandle = @() methodFunc(this);
          else
            error('Transfer function method %s not found on Node class', mstr);
          end
        catch ex
          error('Failed to create method handle for %s: %s', transFun, ex.message);
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
        % Setter for current values
        this.currValue = value;
    end
    
    function setWorkingValue(this, value)
        % Setter for working values in two-phase computation
        this.workingValue = value;
    end
    
    function setNodeEventTarget2(this, target)
        % Pure MATLAB version of MEX setNodeEventTarget
        % Sets the Signal object that should be notified when this node's value changes
        this.eventsTarget = target;
    end
    
    function commitWorkingValue(this)
        % Copy working value to current value and clear (like MEX)
        if this.workingValue ~= sig.Nil.instance()
            this.setCurrValue(this.workingValue);
            % Clear working value after application (like MEX does)
            this.workingValue = sig.Nil.instance();
            
            % NEW: Trigger event notifications (like MEX lines 377-383)
            % MEX: if (n[currNode].eventsTarget) { mexCallMATLAB(..., "valueChanged"); }
            if ~isempty(this.eventsTarget) && isvalid(this.eventsTarget)
                try
                    this.eventsTarget.valueChanged(this.currValue);
                catch ex
                    warning('Event notification failed for node %s: %s', this.Name, ex.message);
                end
            end
        end
    end
    
    function valset = mapn(this)
      % Transfer function as Node method (MEX-compliant LATEST_VALUE semantics)
      % MEX Rule: Compute if ANY input has working value, use LATEST_VALUE for all inputs
      [f, outnum] = this.transArg{:}; % Get from node property
      n = numel(this.Inputs);
      inpvals = cell(n, 1);
      hasWorkingValue = false(n, 1);  % Track which inputs have working values
      
      % MEX LATEST_VALUE logic: working value if exists, otherwise current value
      for inp = 1:n
        node = this.Inputs(inp);
        if node.workingValue ~= sig.Nil.instance()
          % Input has a working value (new value) - use it
          inpvals{inp} = node.workingValue;
          hasWorkingValue(inp) = true;
        elseif node.currValue ~= sig.Nil.instance()
          % Fall back to current value (MEX LATEST_VALUE behavior)
          inpvals{inp} = node.currValue;
          hasWorkingValue(inp) = false;  % Constants don't trigger, but provide values
        else
          % No value at all - can't compute
          valset = false;
          return;
        end
      end
      
      % MEX Rule: Only compute if at least one input has a working value (changed)
      if ~any(hasWorkingValue)
        valset = false;
        return;
      end
      
      % At least one input changed - apply the function using LATEST_VALUE for all
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
      % IDENTITY Transfer function - passes input value to output (MEX-compliant LATEST_VALUE)
      % MEX Rule: Compute if input has working value, use LATEST_VALUE for the input
      if numel(this.Inputs) >= 1
        input = this.Inputs(1);
        
        % MEX LATEST_VALUE logic: working value if exists, otherwise current value
        if input.workingValue ~= sig.Nil.instance()
          % Input has a working value (new value) - use it and compute
          this.setWorkingValue(input.workingValue);
          valset = true;
        elseif input.currValue ~= sig.Nil.instance()
          % Input has current value but no working value - don't compute (no change)
          valset = false;
        else
          % No value at all - can't compute
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

