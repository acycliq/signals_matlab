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
    CurrValue = sig.Nil.instance()
    workingValue = sig.Nil.instance() % Working value for two-phase computation
    queued = false       % mex-style queued flag: true if node is currently in processing queue, false otherwise
                         % Its role is to prevents duplicate queuing during signal propagation
    Targets % will keep the input nodes (aka children)
    EventTarget % Signal to notify on value commit (replaces MEX eventsTarget)
  end
  
  properties (SetAccess = immutable)
    Net sig.Net % Parent network
  end

  properties (SetAccess = private)
    Inputs sig.node.Node % Array of input nodes (private so only setInputs can rewire)
  end
  
  properties (SetAccess = private, Transient)
    NetId double
  end
  
  properties (Dependent)
    Name
    CurrValueSet
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
        % 'subsref' as a method name on a handle class would override MATLAB's
        % builtin dot/index dispatch and brick all property access on Node.
        % use a renamed method instead.
        if strcmp(mstr, 'subsref')
          mstr = 'subsrefTransfer';
        end
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
    
    function tf = get.CurrValueSet(this)
      tf = this.CurrValue ~= sig.Nil.instance();
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
    
    function setInputs(this, newInputs)
      % MATLAB equivalent of MEX nodeInputs() — rewires this node's inputs
      % and updates Targets arrays for propagation. Used by flatten to
      % dynamically add/remove source connections.
      %
      % Fix #1: no-op early exit when inputs are unchanged.
      % Fix #3: diff-based — only inputs that move in/out are touched. Stable
      % inputs (e.g. flatten's director) keep their Targets entry untouched.
      oldInputs = this.Inputs;
      nOld = numel(oldInputs);
      nNew = numel(newInputs);

      if nOld == nNew
        same = true;
        for i = 1:nOld
          if oldInputs(i) ~= newInputs(i)
            same = false;
            break
          end
        end
        if same
          return
        end
      end

      % Remove this node from old inputs that are not in newInputs.
      for i = 1:nOld
        inp = oldInputs(i);
        keep = false;
        for j = 1:nNew
          if inp == newInputs(j)
            keep = true;
            break
          end
        end
        if ~keep
          for k = numel(inp.Targets):-1:1
            if inp.Targets{k} == this
              inp.Targets(k) = [];
              break
            end
          end
        end
      end

      this.Inputs = newInputs;

      % Add this node to new inputs that were not in oldInputs.
      for i = 1:nNew
        inp = newInputs(i);
        isNew = true;
        for j = 1:nOld
          if inp == oldInputs(j)
            isNew = false;
            break
          end
        end
        if isNew
          inp.Targets{end+1} = this;
        end
      end
    end
    
    function setCurrValue(this, value)
        % Setter for current values
        this.CurrValue = value;
    end
    
    function setWorkingValue(this, value)
        % Setter for working values in two-phase computation
        this.workingValue = value;
    end
    
    function commitWorkingValue(this)
        % Copy working value to current value and clear (like MEX).
        % Use isa(x, 'sig.Nil') instead of ~= nilInstance because the
        % working value may itself be a Signal (e.g. flatten's director),
        % and Signal overloads ~= to build a new comparison signal.
        if ~isa(this.workingValue, 'sig.Nil')
            this.setCurrValue(this.workingValue);
            this.workingValue = sig.Nil.instance();
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
        elseif node.CurrValue ~= nilInstance
          % Fall back to current value (MEX LATEST_VALUE behavior)
          inpvals{inp} = node.CurrValue;
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
        inputIds = [this.Inputs.Id];
        msg = sprintf(['Error in Net %i mapping Nodes [%s] to %i:\n' ...
          'function call ''%s'' with inputs (%s) produced an error:\n %s'], ...
          this.Net.Id, num2str(inputIds), this.Id, func2str(f), ...
          strjoin(mapToCell(@(v)toStr(v,1), inpvals), ', '), ex.message);
        sigEx = sig.Exception('transfer:mapn:error', ...
          msg, this.Net.Id, this.Id, inputIds, inpvals, f);
        ex = ex.addCause(sigEx);
        rethrow(ex)
      end
    end
    
    function valset = nop(this)
      % NOP Transfer function - performs no operation
      % Always returns false (no value set)
      warning('signals:transfer:nopCalled', 'sig.transfer.nop called')
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
        elseif input.CurrValue ~= nilInstance
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
        wv = input.workingValue;
        try
          val = f(wv);
          this.setWorkingValue(val);
          valset = true;
        catch ex
          inputId = input.Id;
          msg = sprintf(['Error in Net %i mapping Node %i to %i:\n' ...
            'function call ''%s'' with input %s produced an error:\n %s'], ...
            this.Net.Id, inputId, this.Id, func2str(f), toStr(wv, 1), ex.message);
          sigEx = sig.Exception('transfer:map:error', ...
            msg, this.Net.Id, this.Id, inputId, wv, f);
          ex = ex.addCause(sigEx);
          rethrow(ex)
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
      elseif nCondition.CurrValue ~= nilInstance
        condition = nCondition.CurrValue;
      else
        valset = false;
        return
      end

      % Only proceed if node n has a working value
      n = this.Inputs(1);
      if n.workingValue ~= nilInstance
        what = n.workingValue;
        try
          indicator = f(what);
          if indicator == condition
            this.setWorkingValue(what);
            valset = true;
            return
          end
        catch ex
          inputIds = [this.Inputs.Id];
          msg = sprintf(['Error in Net %i mapping Nodes [%s] to %i:\n' ...
            'Calling %s on %s produced an error:\n %s'], ...
            this.Net.Id, num2str(inputIds), this.Id, toStr(f), toStr(what, 1), ex.message);
          sigEx = sig.Exception('transfer:filter:error', ...
            msg, this.Net.Id, this.Id, inputIds, {what, condition}, f);
          ex = ex.addCause(sigEx);
          rethrow(ex)
        end
      end

      % Otherwise set to false
      valset = false;
    end

    function valset = at(this)
      % at transfer function - samples 'what' when 'when' becomes true
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
        % MEX L11: plain if, so a non-scalar 'when' gates on all of its
        % elements being non-zero, and empty gates closed
        if whenWorking
          % Now get 'what' value - try working first, fall back to current
          % MEX does: [what, whatset] = workingNodeValue(...) then currNodeValue(...)
          nWhat = this.Inputs(1);
          if nWhat.workingValue ~= nilInstance
            this.setWorkingValue(nWhat.workingValue);
            valset = true;
            return
          elseif nWhat.CurrValue ~= nilInstance
            this.setWorkingValue(nWhat.CurrValue);
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
      elseif nMaxSamps.CurrValue ~= nilInstance
        maxSamps = nMaxSamps.CurrValue;
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
      if this.CurrValue ~= nilInstance
        buff = this.CurrValue;
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
          % MEX L48-51: same format string, including the Concatinating typo
          msg = sprintf(['Error in Net %i mapping Nodes [%s] to %i:\n' ...
            'Concatinating %s to %s produced an error:\n %s'], ...
            this.Net.Id, num2str([this.Inputs.Id]), this.Id, ...
            toStr(newval, 1), toStr(buff), ex.message);
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
      % indexOfFirst transfer function - returns index of first true input
      % See +sig/+transfer/indexOfFirst.m for MEX reference
      nilInstance = sig.Nil.instance();

      % MEX L5: n = numel(inputs)
      n = numel(this.Inputs);

      % MEX L7
      noMatch = n + 1;

      % MEX L9-12: get this node's current value (the current match index)
      if this.CurrValue ~= nilInstance
        currMatch = this.CurrValue;
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
        elseif inputNode.CurrValue ~= nilInstance
          % MEX L20-21: no working value, fall back to current
          pred = inputNode.CurrValue;
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

        % MEX L40-44: predicate is true — this is the first match
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
      % keepWhen transfer function - passes 'what' value only when 'when' is true
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
      elseif nWhen.CurrValue ~= nilInstance
        when = nWhen.CurrValue;
      else
        % MEX L30: whenwvset || whencvset fails — no value at all
        valset = false;
        return
      end

      % MEX L31: gate on 'when' being non-zero
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
        if this.CurrValue == nilInstance || ~isequal(wv, this.CurrValue)
          this.setWorkingValue(wv);
          valset = true;
          return
        end
      end

      valset = false;
    end

    function valset = latch(this)
      % latch transfer function - arms on first input, releases on second
      % See +sig/+transfer/latch.m for MEX reference
      %
      % this.Inputs(1) is 'arm' - arms the latch when non-zero
      % this.Inputs(2) is 'release' - releases the latch when non-zero
      % this.CurrValue holds the armed state (initialised to false by Signal.m)
      %
      % Only reacts to working values (no LATEST_VALUE fallback) — latch
      % cares about fresh updates in this transaction, not stale values.
      nilInstance = sig.Nil.instance();

      % MEX L6-7: working values only
      armWV = this.Inputs(1).workingValue;
      releaseWV = this.Inputs(2).workingValue;
      armSet = armWV ~= nilInstance;
      releaseSet = releaseWV ~= nilInstance;

      % MEX L10: current armed state from this node's own CurrValue
      armed = this.CurrValue;

      % MEX L12-13: input must be set AND non-zero (posting 0 is ignored)
      tryArm = armSet && armWV;
      tryRelease = releaseSet && releaseWV;

      % MEX L15-27: release takes priority over arming
      if tryRelease && (tryArm || armed)
        this.setWorkingValue(false);
        valset = true;
      elseif ~armed && tryArm
        this.setWorkingValue(true);
        valset = true;
      else
        valset = false;
      end
    end

    function valset = log(this)
      % log transfer function - timestamps and logs each new value
      % See +sig/+transfer/log.m for MEX reference
      %
      % Assumes one input. this.transArg is a clock function (default @GetSecs).
      % When input has a working value, appends struct('time', clock(), 'value', wv)
      % to the existing log array.
      % this.CurrValue is initialised to struct('time', {}, 'value', {}) by Signal.m.
      %
      % In MEX, the transfer returns a single struct and appendValues=true
      % makes the apply phase concatenate. Here we accumulate directly.

      % MEX L5: working value only (no LATEST_VALUE fallback)
      nilInstance = sig.Nil.instance();
      wv = this.Inputs(1).workingValue;
      if wv ~= nilInstance
        % MEX L9: create timestamped entry
        entry = struct('time', this.transArg(), 'value', wv);
        % Accumulate onto existing log (MEX does this via appendValues in apply phase)
        this.setWorkingValue([this.CurrValue entry]);
        valset = true;
      else
        valset = false;
      end
    end

    function valset = schedule(this)
      % schedule transfer function - packages value with delay for delayed posting
      % See +sig/+transfer/schedule.m for MEX reference
      %
      % this.Inputs(1) is 'what' - the value to deliver after delay
      % this.Inputs(2) is 'delay' - the delay duration
      % Output is a cell {what, delay} "packet" used by delayedPost
      nilInstance = sig.Nil.instance();

      % MEX L13-16: get latest 'delay' value — LATEST_VALUE pattern
      nDelay = this.Inputs(2);
      if nDelay.workingValue ~= nilInstance
        delay = nDelay.workingValue;
      elseif nDelay.CurrValue ~= nilInstance
        delay = nDelay.CurrValue;
      else
        valset = false;
        return
      end

      % MEX L18: get 'what' WORKING value only (no current fallback)
      what = this.Inputs(1).workingValue;
      if what ~= nilInstance
        % MEX L21: output schedule packet
        this.setWorkingValue({what delay});
        valset = true;
      else
        valset = false;
      end
    end

    function valset = scan(this)
      % scan transfer function - fold/accumulate over element inputs
      % See +sig/+transfer/scan.m for MEX reference
      %
      % Input layout: [item_1, ..., item_n, seed, par_1, ..., par_m]
      % this.transArg = funcs (cell array, one function per element input)
      % this.CurrValue holds the accumulator (initialised from seed by Signal.m)
      nilInstance = sig.Nil.instance();
      funcs = this.transArg;
      inputs = this.Inputs;
      nElemInps = numel(funcs);
      nParInps = numel(inputs) - nElemInps - 1;

      % MEX L10-18: seed override — if seed has working value, use it
      seedNode = inputs(nElemInps + 1);
      if seedNode.workingValue ~= nilInstance
        val = seedNode.workingValue;
        valavail = true;
        valset = true;
      else
        % MEX L17: use this node's own CurrValue as accumulator
        val = this.CurrValue;
        valavail = val ~= nilInstance;
        valset = false;
      end

      % MEX L21-32: gather parameter inputs (LATEST_VALUE pattern)
      % If any param is completely missing, bail out immediately
      pars = cell(1, nParInps);
      for ii = 1:nParInps
        parNode = inputs(nElemInps + 1 + ii);
        if parNode.workingValue ~= nilInstance
          pars{ii} = parNode.workingValue;
        elseif parNode.CurrValue ~= nilInstance
          pars{ii} = parNode.CurrValue;
        else
          % MEX L28: bail out — but if seed override set valset=true,
          % we must still propagate the seed value
          if valset
            this.setWorkingValue(val);
          end
          return
        end
      end

      % MEX L34-55: apply scan functions to element inputs
      for ii = 1:nElemInps
        itemWV = inputs(ii).workingValue;
        if valavail && itemWV ~= nilInstance
          f = funcs{ii};
          try
            val = f(val, itemWV, pars{:});
            valset = true;
          catch ex
            msg = sprintf(['Error in Net %i scanning node %s (id %i) from Nodes [%s]:\n' ...
              'function call ''%s'' with inputs (%s) produced an error:\n %s'], ...
              this.Net.Id, this.Name, this.Id, num2str([inputs.Id]), func2str(f), ...
              strjoin(mapToCell(@(v)toStr(v,1), [{val itemWV}, pars]), ', '), ex.message);
            sigEx = sig.Exception('transfer:scan:error', ...
              msg, this.Net.Id, this.Id, [inputs.Id], [{val itemWV}, pars], f);
            ex = ex.addCause(sigEx);
            rethrow(ex)
          end
        end
      end

      % MEX: if valset, store the accumulated result
      if valset
        this.setWorkingValue(val);
      end
    end

    function valset = flatten(this)
      % flatten transfer function - unwraps nested signals
      % See +sig/+transfer/flatten.m for MEX reference
      %
      % this.Inputs(1) is the 'director' — the signal whose value might be another signal
      % this.Inputs(2) is the 'source' — dynamically wired to whatever signal the director holds
      % this.transArg is a StructRef with 'unappliedInputChanges' flag (persists across calls)
      %
      % Note: we use isa(x, 'sig.Nil') instead of x == nilInstance because
      % the value being held may itself be a Signal, and Signal overloads
      % == / ~= to build a new comparison Signal rather than return a bool.
      state = this.transArg;
      director = this.Inputs(1);
      valset = false; % MEX L30: default to false

      %%% MEX L33-42: Check director's working value
      dirWorking = director.workingValue;
      if ~isa(dirWorking, 'sig.Nil')
        state.unappliedInputChanges = true;
        valset = true;
        if isa(dirWorking, 'sig.node.Signal')
          % Director value is a Signal — rewire source connection
          sourceNode = dirWorking.Node;
          this.setInputs([director, sourceNode]);
          % Don't return yet — check source below
        else
          % Director value is regular — return it directly
          this.setInputs(director); % remove source if any
          this.setWorkingValue(dirWorking);
          return
        end

      %%% MEX L43-58: No director working value, handle unappliedInputChanges.
      % Fix #2: skip setInputs in this branch — wiring already reflects the
      % rewire from the previous transaction (this.Inputs persists across
      % calls, unlike MEX's local 'inputs' variable that resets each call).
      else
        if state.unappliedInputChanges
          state.unappliedInputChanges = false;
          dirCurr = director.CurrValue;
          if ~isa(dirCurr, 'sig.Nil')
            if isa(dirCurr, 'sig.node.Signal')
              % Inputs already == [director, sourceNode] from previous call —
              % nothing to rewire, fall through to consume source below.
            else
              % Inputs already == [director] from previous call.
              valset = false;
              return
            end
          else
            % Director currValue cleared somehow (shouldn't happen in normal
            % use). Inputs already trimmed last time, nothing to do.
            valset = false;
            return
          end
        end
      end

      %%% MEX L61-74: Check source, if any
      if numel(this.Inputs) > 1
        source = this.Inputs(2);
        sourceWV = source.workingValue;
        if ~isa(sourceWV, 'sig.Nil')
          this.setWorkingValue(sourceWV);
          valset = true;
        elseif valset
          % New source connection was made earlier, take source's current value
          sourceCV = source.CurrValue;
          if ~isa(sourceCV, 'sig.Nil')
            this.setWorkingValue(sourceCV);
            % valset stays true
          else
            valset = false;
          end
        end
      end
    end

    function valset = selectFrom(this)
      % selectFrom picks one of N options based on an index value.
      % See +sig/+transfer/selectFrom.m for the MEX reference.
      %
      % Inputs(1) is the indexer, a numeric signal saying which option to pick.
      % Inputs(2..end) are the options themselves.
      %
      % Tricky bit: only emit when the indexer or the chosen option actually
      % just changed. Without that check, the same pair would get re-emitted
      % every time the node was visited even when nothing relevant changed.
      nilInstance = sig.Nil.instance();
      nOptions = numel(this.Inputs) - 1;

      % MEX L9-12: grab the latest indexer value, working first then current
      indexer = this.Inputs(1);
      if indexer.workingValue ~= nilInstance
        idx = indexer.workingValue;
        idxwvset = true;
      elseif indexer.CurrValue ~= nilInstance
        idx = indexer.CurrValue;
        idxwvset = false;
      else
        % MEX L15-19: no indexer value at all, can't pick anything
        valset = false;
        return
      end

      % MEX L21-32: if idx is in range, try to get the option's value
      if idx <= nOptions
        option = this.Inputs(idx + 1);
        if option.workingValue ~= nilInstance
          selval = option.workingValue;
          selwvvalset = true;
          selcvvalset = false;
        elseif option.CurrValue ~= nilInstance
          selval = option.CurrValue;
          selwvvalset = false;
          selcvvalset = true;
        else
          selwvvalset = false;
          selcvvalset = false;
        end

        % MEX L26-31: only emit if we have a value AND either the idx or
        % the option changed this round
        if (selwvvalset || selcvvalset) && (idxwvset || selwvvalset)
          this.setWorkingValue(selval);
          valset = true;
          return
        end
      end

      % MEX L33-34: nothing to emit
      valset = false;
    end

    function valset = subsrefTransfer(this)
      % subsref transfer function - applies indexing to a signal's value.
      % See +sig/+transfer/subsref.m for the MEX reference.
      %
      % Named subsrefTransfer rather than subsref so it doesn't collide
      % with MATLAB's builtin subsref dispatch on the Node handle class.
      % The Node constructor maps 'sig.transfer.subsref' to this method name.
      %
      % Inputs(1) is the thing being indexed, the parent signal.
      % Inputs(2..end) are the subscripts (any of which can be a signal,
      % a literal value, or a deferred expr.Expr like end-1:end).
      % this.transArg is the subscript type, one of '.', '()' or '{}'.
      %
      % In normal use Signal.subsref only routes '()' here, the '.' and '{}'
      % branches are reachable only by direct invocation.
      %
      % We need a value on every input (working or current). We only emit
      % if at least one of them was just updated this round.
      type = this.transArg;
      nilInstance = sig.Nil.instance();
      nInputs = numel(this.Inputs);
      inpvals = cell(nInputs, 1);
      wvset = false(nInputs, 1);

      % MEX L8-25: grab every input's value, working first then current.
      % bail out as soon as we find an input with no value at all
      for k = 1:nInputs
        input = this.Inputs(k);
        if input.workingValue ~= nilInstance
          inpvals{k} = input.workingValue;
          wvset(k) = true;
        elseif input.CurrValue ~= nilInstance
          inpvals{k} = input.CurrValue;
          wvset(k) = false;
        else
          valset = false;
          return
        end
      end

      % MEX L27: only emit if at least one input actually changed this round
      if ~any(wvset)
        valset = false;
        return
      end

      what = inpvals{1};

      % MEX L30-42: '.' field access. If what is a struct and the field
      % doesn't exist on it, emit nothing
      if strcmp(type, '.')
        subs = inpvals{2};
        if isstruct(what) && ~isfield(what, subs)
          valset = false;
          return
        end
        this.setWorkingValue(what.(subs));
        valset = true;
        return
      end

      % MEX L43-44: build subscript struct for () or {} access
      s = struct('type', type, 'subs', {inpvals(2:end)});

      % MEX L46-50: resolve any deferred expr.Expr subscripts.
      % covers things like arr(end) where end is built as expr.End by
      % Signal.end(k, n) at parse time
      for kk = 1:length(s.subs)
        if isa(s.subs{kk}, 'expr.Expr')
          s.subs{kk} = resolve(s.subs{kk}, what);
        end
      end

      % MEX L53-54: plain subsref call, exactly as the reference does it.
      % Dispatches on the class of 'what' so values with their own
      % indexing keep that behaviour. No collision with this method since
      % it is not named subsref.
      this.setWorkingValue(subsref(what, s));
      valset = true;
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

