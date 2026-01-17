classdef Node < handle
  %NODE Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    FormatSpec
    DisplayInputs
    Listeners
    transFun
    transArg
    transferMethodHandle  % Method handle
    Id
    currValue = sig.Nil.instance()
    workingValue = sig.Nil.instance() % Working value for two-phase computation
    queued = false       % mex-style queued flag: true if node is currently in processing queue, false otherwise
                         % Its role is to prevents duplicate queuing during signal propagation
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
          % Check if method exists on this object (maybe I should remove the check if it is costly, need to time it, but shouldnt add too much...)
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

      % Register this node as a target of all its inputs (mimics MEX addTargetToInputs)
      for i = 1:numel(this.Inputs)
        this.Inputs(i).Targets{end+1} = this;
      end
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
    
    function commitWorkingValue(this)
        % Copy working value to current value and clear (like MEX)
        nilInstance = sig.Nil.instance();  % save it so I don't call the function twice
        if this.workingValue ~= nilInstance
            this.setCurrValue(this.workingValue);
            % Clear working value after application (like MEX does)
            this.workingValue = nilInstance;
        end
    end
    
    function valset = mapn(this)
      % mex rule: Compute if ANY input has working value, use LATEST_VALUE for all inputs (better also to the line of network.c here, I will forget it!)
      [f, outnum] = this.transArg{:}; % Get from node property
      n = numel(this.Inputs);
      inpvals = cell(n, 1);
      hasWorkingValue = false(n, 1);  % Track which inputs have working values

      % grab the Nil instance once instead of calling it over and over
      nilInstance = sig.Nil.instance();

      % mex LATEST_VALUE logic: working value if exists, otherwise current value
      for inp = 1:n
        node = this.Inputs(inp);
        if node.workingValue ~= nilInstance
          % Input has a working value (new value) - use it
          inpvals{inp} = node.workingValue;
          hasWorkingValue(inp) = true;
        elseif node.currValue ~= nilInstance
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
      % identity transfer function - passes input value to output
      if numel(this.Inputs) >= 1
        input = this.Inputs(1);

        % save Nil so I don't keep calling instance()
        nilInstance = sig.Nil.instance();

        % mex logic: working value if exists, otherwise current value
        if input.workingValue ~= nilInstance
          % Input has a working value (new value) - use it and compute
          this.setWorkingValue(input.workingValue);
          valset = true;
        elseif input.currValue ~= nilInstance
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

    function valset = map(this)
      % map transfer function - applies function to single input
      % See +sig/+transfer/map.m for MEX reference
      f = this.transArg;
      input = this.Inputs(1);
      nilInstance = sig.Nil.instance();

      % Only compute if input has a working value (new value)
      if input.workingValue ~= nilInstance
        try
          val = f(input.workingValue);
          this.setWorkingValue(val);
          valset = true;
        catch ex
          warning('Error in map for node %s: %s', this.Name, ex.message);
          valset = false;
        end
      else
        valset = false;
      end
    end

    function valset = merge(this)
      % merge transfer function - returns value of first input with working value
      % See +sig/+transfer/merge.m for MEX reference
      % Combines multiple signals into one. Whenever any input updates,
      % the output takes that value.
      %
      % Loops through inputs looking for one with a workingValue (i.e. one
      % that was just updated this cycle). If inputs are independent origins,
      % only one updates at a time:
      %   m = merge(a, b, c);
      %   a.post2(10);  % a has workingValue, b and c don't -> m gets 10
      %
      % But if inputs share a node, multiple could update:
      %   a = x * 2; b = x + 1; m = merge(a, b);
      %   x.post2(5);  % both a and b have workingValues -> m gets a (first one)
      nilInstance = sig.Nil.instance();

      for i = 1:numel(this.Inputs)
        if this.Inputs(i).workingValue ~= nilInstance
          this.setWorkingValue(this.Inputs(i).workingValue);
          valset = true;
          return
        end
      end

      % No inputs have working values
      valset = false;
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

