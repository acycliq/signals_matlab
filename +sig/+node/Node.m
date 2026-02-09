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

      % If no inputs have working values then set valset to false
      valset = false;
    end

    function valset = filter(this)
      % filter transfer function - only passes value if f(value) == condition
      % See +sig/+transfer/filter.m for MEX reference
      %
      % User calls: y = x.filter(@f, condition) where x is a signal
      % If the underlying node of x has workingValue **and** f(workingValue) == condition,
      % pass through workingValue.
      % Example: b = a.filter(@ischar, true) passes value only if it's a char.
      f = this.transArg;
      nilInstance = sig.Nil.instance();

      % Get condition using LATEST_VALUE logic
      nCondition = this.Inputs(2);
      if nCondition.workingValue ~= nilInstance
        condition = nCondition.workingValue;
      elseif nCondition.currValue ~= nilInstance
        condition = nCondition.currValue;
      else
        valset = false;
        return
      end

      % Only proceed if node n has a working value
      n = this.Inputs(1);
      if n.workingValue ~= nilInstance
        try
          indicator = f(n.workingValue);
          if indicator == condition
            this.setWorkingValue(n.workingValue);
            valset = true;
            return
          end
        catch ex
          warning('Error in filter for node %s: %s', this.Name, ex.message);
        end
      end

      % Otherwise set to false
      valset = false;
    end

    function valset = at(this)
      % at transfer function - samples 'what' when 'when' becomes truthy
      % See +sig/+transfer/at.m for MEX reference
      %
      % this.Inputs(1) is 'what' - the value to sample
      % this.Inputs(2) is 'when' - the trigger
      % Example: clickedPos = pos.at(click) - grab pos value when click fires
      nilInstance = sig.Nil.instance();

      % In MEX: [when, whenset] = workingNodeValue(net, inputs(2))
      % Here we just access the node's workingValue directly
      nWhen = this.Inputs(2);
      whenWorking = nWhen.workingValue;

      % whenset in MEX tells us if working value exists, we check ~= Nil instead
      if whenWorking ~= nilInstance
        % 'when' must be scalar (true/false/0/1). Non-scalar triggers
        % don't make sense for at().
        if ~isscalar(whenWorking)
          error('signals:at:nonScalarWhen', ...
            'at: ''when'' must be scalar, got [%s]', num2str(size(whenWorking)));
        end
        if whenWorking  % when is truthy
          % Now get 'what' value - try working first, fall back to current
          % MEX does: [what, whatset] = workingNodeValue(...) then currNodeValue(...)
          nWhat = this.Inputs(1);
          if nWhat.workingValue ~= nilInstance
            this.setWorkingValue(nWhat.workingValue);
            valset = true;
            return
          elseif nWhat.currValue ~= nilInstance
            this.setWorkingValue(nWhat.currValue);
            valset = true;
            return
          end
        end
      end

      valset = false;
    end

    function valset = buffer(this)
      % buffer transfer function - accumulates values into a rolling array
      % See +sig/+transfer/buffer.m for MEX reference
      %
      % this.Inputs(1) is the new sample to append
      % this.Inputs(2) is the max buffer size
      nilInstance = sig.Nil.instance();

      % MEX L26-32: Get max buffer size using LATEST_VALUE logic
      nMaxSamps = this.Inputs(2);
      if nMaxSamps.workingValue ~= nilInstance
        maxSamps = nMaxSamps.workingValue;
        % No zero check here — matches MEX (zero check only in currValue branch)
      elseif nMaxSamps.currValue ~= nilInstance
        maxSamps = nMaxSamps.currValue;
        if ~maxSamps  % zero check matches MEX L29
          valset = false;
          return
        end
      else
        valset = false;
        return
      end

      % MEX L35: Get current buffer contents from this node's own currValue
      % In MEX, currNodeValue returns [] when no value set yet.
      % Here currValue is Nil initially, so convert to [] for first call.
      if this.currValue ~= nilInstance
        buff = this.currValue;
      else
        buff = [];
      end

      % MEX L37-38: Only proceed if new sample has a working value
      newval = this.Inputs(1).workingValue;
      if newval ~= nilInstance
        try
          % MEX L40-46: Concatenation logic
          free = size(buff, 2) - maxSamps;
          if free >= 0  % buffer full, drop oldest and append new
            val = cat(2, buff(:, free+2:end), newval);
          else  % buffer not full, just append
            val = [buff newval];
          end
          this.setWorkingValue(val);
          valset = true;
        catch ex
          msg = sprintf('Error in buffer for node %s:\nConcatenating %s to buffer produced an error:\n %s', ...
            this.Name, toStr(newval, 1), ex.message);
          sigEx = sig.Exception('transfer:buffer:error', ...
            msg, this.Net.Id, this.Id, [this.Inputs.Id], {buff, newval}, @horzcat);
          ex = ex.addCause(sigEx);
          rethrow(ex)
        end
      else
        valset = false;
      end
    end

    function valset = indexOfFirst(this)
      % indexOfFirst transfer function - returns index of first truthy input
      % See +sig/+transfer/indexOfFirst.m for MEX reference
      nilInstance = sig.Nil.instance();

      % MEX L5: n = numel(inputs)
      n = numel(this.Inputs);

      % MEX L7
      noMatch = n + 1;

      % MEX L9-12: get this node's current value (the current match index)
      if this.currValue ~= nilInstance
        currMatch = this.currValue;
      else
        currMatch = Inf;
      end

      % MEX L14
      firstNewInput = 0;

      % Cache Inputs array — avoid repeated property access in loop
      inputs = this.Inputs;

      for inp = 1:n
        % MEX L19: get latest predicate value — working first, then current
        inputNode = inputs(inp);
        if inputNode.workingValue ~= nilInstance
          % MEX L20-30: input has a new working value
          pred = inputNode.workingValue;
          predset = true;
          if ~firstNewInput
            % MEX L22-30: first input with a new value this transaction
            firstNewInput = inp;
            if firstNewInput > currMatch
              % MEX L24-29: first changed predicate is after current match,
              % result can't change — bail out
              valset = false;
              return
            end
          end
        elseif inputNode.currValue ~= nilInstance
          % MEX L20-21: no working value, fall back to current
          pred = inputNode.currValue;
          predset = true;
        else
          predset = false;
        end

        % MEX L33-38: predicate has no value — can't evaluate further
        if ~predset
          this.setWorkingValue(noMatch);
          valset = true;
          return
        end

        % MEX L40-44: predicate is truthy — this is the first match
        if pred
          this.setWorkingValue(inp);
          valset = true;
          return
        end
      end

      % MEX L46-48: no matching predicate found
      this.setWorkingValue(noMatch);
      valset = true;
    end

    function valset = keepWhen(this)
      % keepWhen transfer function - passes 'what' value only when 'when' is truthy
      % See +sig/+transfer/keepWhen.m for MEX reference
      %
      % this.Inputs(1) is 'what' - the value to gate
      % this.Inputs(2) is 'when' - the gate signal
      % Only passes 'what' working value (no current fallback for 'what')
      nilInstance = sig.Nil.instance();

      % MEX L25-28: get latest 'when' value — LATEST_VALUE pattern
      nWhen = this.Inputs(2);
      if nWhen.workingValue ~= nilInstance
        when = nWhen.workingValue;
      elseif nWhen.currValue ~= nilInstance
        when = nWhen.currValue;
      else
        % MEX L30: whenwvset || whencvset fails — no value at all
        valset = false;
        return
      end

      % MEX L31: gate on 'when' being truthy
      if when
        % MEX L33-38: get 'what' WORKING value only (no current fallback)
        nWhat = this.Inputs(1);
        if nWhat.workingValue ~= nilInstance
          this.setWorkingValue(nWhat.workingValue);
          valset = true;
          return
        end
      end

      % MEX L44-45: all other paths — no output
      valset = false;
    end

    function valset = skipRepeats(this)
      % skipRepeats transfer function - only passes value if different from current
      % See +sig/+transfer/skipRepeats.m for MEX reference
      %
      % Assumes one input. Compares input's working value against this
      % node's own currValue using isequal. First value always passes.
      nilInstance = sig.Nil.instance();

      % MEX L8-9: Get new value from input's working value
      wv = this.Inputs(1).workingValue;
      if wv ~= nilInstance
        % MEX L10-11: Compare against this node's own currValue
        % ~cvset (Nil) means no current value yet — always pass through
        % ~isequal means value changed — pass through
        if this.currValue == nilInstance || ~isequal(wv, this.currValue)
          this.setWorkingValue(wv);
          valset = true;
          return
        end
      end

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

