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
    opCode = 0 % transferer op code for the post2 dispatch, mirrors network.c transfer() (0 = generic)
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
      % mapn wraps its function as a {f, outIdx} cell, so transfererOpCode
      % always returns 0 for it and the binary op codes (network.c
      % transfer() L729-758) never reached the nodes they were written
      % for. Unwrap the cell to detect them. Only for output index 1,
      % the dispatch assigns the single return value.
      if opCode == 0 && strcmp(transFun, 'sig.transfer.mapn') ...
          && iscell(transArg) && numel(transArg) == 2 ...
          && isequal(transArg{2}, 1) && isa(transArg{1}, 'function_handle')
        opCode = sig.node.transfererOpCode(transFun, transArg{1});
      end
      % Binary op codes are only meaningful on a two input mapn node.
      % transfererOpCode's bare handle rule also matches map, so a call
      % like a.map(@plus) would carry the plus code on a one input node.
      % In MEX that makes transfer() read inputs[1] past the end of the
      % array (network.c L691). Zero the code instead, such nodes always
      % take the generic transfer method.
      if opCode > 0 && opCode < 20 ...
          && ~(strcmp(transFun, 'sig.transfer.mapn') && numel(this.Inputs) == 2)
        opCode = 0;
      end
      this.opCode = opCode;
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
      tf = ~isa(this.CurrValue, 'sig.Nil');
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
        % Use isa(x, 'sig.Nil') rather than comparing against the Nil
        % instance because the working value may itself be a Signal (e.g.
        % flatten's director), and Signal overloads ~= to build a new
        % comparison signal. isa is also much faster than the dispatched
        % comparison.
        if ~isa(this.workingValue, 'sig.Nil')
            this.setCurrValue(this.workingValue);
            this.workingValue = sig.Nil.instance();
        end
    end

    function transact(this, value)
        % Run one full transaction starting from this node: set the
        % working value, propagate breadth first through the targets, then
        % apply the working values and notify event targets. Named after
        % the C function it replicates (network.c transact, L659-687, plus
        % sqApply, L339-400). Callers: OriginSignal.post2 for ordinary
        % posts, Net.runSchedule for delayed deliveries, both of which the
        % MEX served through the submit + applyNodes pair.

        % Set working value on the starting node, direct property write
        % to avoid method call overhead in this hot path.
        this.workingValue = value;

        % Preallocate queue and affected list like MEX network.c L663-664
        % (QUEUE_ALLOC/STACK_ALLOC of nNodes). The queue can never exceed
        % nNodes since the queued flag stops duplicates. The affected list
        % can (nodes computed twice in one transaction), MATLAB just grows
        % the cell in that rare case.
        nNodes = numel(this.Net.nodes);
        queue = cell(1, nNodes);
        affected = cell(1, nNodes);

        % Queue the starting node's targets
        targets = this.Targets;
        nTargets = length(targets);
        qTail = 0;
        for i = 1:nTargets
            target = targets{i};
            if ~target.queued
                qTail = qTail + 1;
                queue{qTail} = target;
                target.queued = true;
            end
        end
        affected{1} = this;  % Add the starting node to the affected list
        nAffected = 1;

        % Use index instead of removing from queue (queue(1)=[] is slow)
        qIdx = 1;
        while qIdx <= qTail
            curr = queue{qIdx};
            qIdx = qIdx + 1;
            curr.queued = false;

            % network.c transfer() L719-773: binary ops on two double
            % scalars are computed inline without the generic mapn
            % machinery. The inline operator is the very same builtin that
            % mapn reaches through its function handle, so the results are
            % identical, and everything else (vectors, ints, missing
            % values) falls through to the transfer method, error paths
            % included. The op code sanitiser in the Node constructor
            % guarantees codes 1-19 only sit on two input mapn nodes.
            op = curr.opCode;
            if op ~= 0 && op < 20
                ins = curr.Inputs;
                nIn1 = ins(1); nIn2 = ins(2);
                l = nIn1.workingValue;
                r = nIn2.workingValue;
                lNew = ~isa(l, 'sig.Nil');
                rNew = ~isa(r, 'sig.Nil');
                if lNew || rNew                        % ANY_NEW_INPUT_OF_2, network.c L691
                    if ~lNew, l = nIn1.CurrValue; end  % LATEST_VALUE, network.c L689
                    if ~rNew, r = nIn2.CurrValue; end
                    if ~isa(l, 'sig.Nil') && ~isa(r, 'sig.Nil')
                        if isa(l, 'double') && isscalar(l) ...
                            && isa(r, 'double') && isscalar(r)
                            switch op
                                case 1,     curr.workingValue = l + r;
                                case 2,     curr.workingValue = l - r;
                                case {3,4}, curr.workingValue = l * r;
                                case {5,6}, curr.workingValue = l / r;
                                case 10,    curr.workingValue = l > r;
                                case 11,    curr.workingValue = l >= r;
                                case 12,    curr.workingValue = l < r;
                                case 13,    curr.workingValue = l <= r;
                                otherwise,  curr.workingValue = l == r; % 14
                            end
                            computed = true;
                        else
                            % not two double scalars, generic transfer
                            % like the C does (network.c L767-769)
                            computed = curr.transferMethodHandle();
                        end
                    else
                        computed = false; % an input has no value at all
                    end
                else
                    computed = false; % nothing new on either input
                end
            else
                % Just call the transfer function, it checks if inputs are ready
                computed = curr.transferMethodHandle();
            end

            % MEX network.c L701-708: the transfer set no output, but this
            % node was given a working value earlier in this transaction.
            % Retract it so it is not committed, and still propagate so
            % downstream nodes recompute without it. isa() rather than ~=
            % because the working value may itself be a Signal.
            if ~computed && ~isa(curr.workingValue, 'sig.Nil')
                curr.workingValue = sig.Nil.instance();
                computed = true;
            end

            if computed  % If node computed new value
                nAffected = nAffected + 1;
                affected{nAffected} = curr;  % Add to affected list

                % Queue all targets
                targets = curr.Targets;
                nTargets = length(targets);
                for j = 1:nTargets
                    target = targets{j};
                    if ~target.queued
                        qTail = qTail + 1;
                        queue{qTail} = target;
                        target.queued = true;
                    end
                end
            end
        end

        % Apply all working values (MEX: sqApply, network.c L339-400),
        % inlined here so a post costs the same number of method calls as
        % before the move from OriginSignal.
        nilInstance = sig.Nil.instance();
        for i = 1:nAffected
            node = affected{i};
            % MEX network.c L368: skip nodes with no working value to apply.
            % A node can appear more than once in the affected list and the
            % first pass commits and clears its value, so this also stops
            % the event target being notified twice for one commit. Same
            % goes for values retracted during the transaction.
            if isa(node.workingValue, 'sig.Nil')
                continue
            end
            % Inline commit (working -> current, then clear), direct
            % property writes to save two method calls per node
            node.CurrValue = node.workingValue;
            node.workingValue = nilInstance;
            % Notify event target after commit (matches MEX network.c L378-381)
            if ~isempty(node.EventTarget)
                node.EventTarget.valueChanged(node.CurrValue);
            end
        end
    end
    
    function valset = mapn(this)
      % mex rule: Compute if ANY input has working value, use LATEST_VALUE for all inputs (better also to the line of network.c here, I will forget it!)
      [f, outnum] = this.transArg{:}; % Get from node property
      inputs = this.Inputs;  % cache the property, read once not per loop pass
      n = numel(inputs);
      inpvals = cell(n, 1);
      hasWorkingValue = false(n, 1);  % Track which inputs have working values


      % mex LATEST_VALUE logic: working value if exists, otherwise current value
      for inp = 1:n
        node = inputs(inp);
        wv = node.workingValue;  % read the property once, not twice
        if ~isa(wv, 'sig.Nil')
          % Input has a working value (new value) - use it
          inpvals{inp} = wv;
          hasWorkingValue(inp) = true;
        else
          cv = node.CurrValue;
          if ~isa(cv, 'sig.Nil')
            % Fall back to current value (MEX LATEST_VALUE behavior).
            % Constants don't trigger, but provide values.
            inpvals{inp} = cv;
          else
            % No value at all - can't compute
            valset = false;
            return;
          end
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
        this.workingValue = out{end};  % Store in working value (phase 1)
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


        % mex logic: working value if exists, otherwise current value
        if ~isa(input.workingValue, 'sig.Nil')
          % Input has a working value (new value) - use it and compute
          this.workingValue = input.workingValue;
          valset = true;
        elseif ~isa(input.CurrValue, 'sig.Nil')
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

      % Only compute if input has a working value (new value)
      if ~isa(input.workingValue, 'sig.Nil')
        wv = input.workingValue;
        try
          val = f(wv);
          this.workingValue = val;
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

      inputs = this.Inputs;  % cache the property, read once not per loop pass
      for i = 1:numel(inputs)
        wv = inputs(i).workingValue;  % read the property once, not twice
        if ~isa(wv, 'sig.Nil')
          this.workingValue = wv;
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

      % Get condition using LATEST_VALUE logic
      nCondition = this.Inputs(2);
      if ~isa(nCondition.workingValue, 'sig.Nil')
        condition = nCondition.workingValue;
      elseif ~isa(nCondition.CurrValue, 'sig.Nil')
        condition = nCondition.CurrValue;
      else
        % MEX L31-33: filter.m returns here without assigning its outputs,
        % so the whole post errors with unassigned output arguments.
        % valset is left unassigned on purpose to crash the same way.
        return
      end

      % Only proceed if node n has a working value
      n = this.Inputs(1);
      if ~isa(n.workingValue, 'sig.Nil')
        what = n.workingValue;
        try
          indicator = f(what);
          if indicator == condition
            this.workingValue = what;
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

      % In MEX: [when, whenset] = workingNodeValue(net, inputs(2))
      % Here we just access the node's workingValue directly
      nWhen = this.Inputs(2);
      whenWorking = nWhen.workingValue;

      % whenset in MEX tells us if working value exists, we check isa Nil instead
      if ~isa(whenWorking, 'sig.Nil')
        % MEX L11: plain if, so a non-scalar 'when' gates on all of its
        % elements being non-zero, and empty gates closed
        if whenWorking
          % Now get 'what' value - try working first, fall back to current
          % MEX does: [what, whatset] = workingNodeValue(...) then currNodeValue(...)
          nWhat = this.Inputs(1);
          if ~isa(nWhat.workingValue, 'sig.Nil')
            this.workingValue = nWhat.workingValue;
            valset = true;
            return
          elseif ~isa(nWhat.CurrValue, 'sig.Nil')
            this.workingValue = nWhat.CurrValue;
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

      % MEX L26-32: Get max buffer size using LATEST_VALUE logic
      nMaxSamps = this.Inputs(2);
      if ~isa(nMaxSamps.workingValue, 'sig.Nil')
        maxSamps = nMaxSamps.workingValue;
        % No zero check here — matches MEX (zero check only in currValue branch)
      elseif ~isa(nMaxSamps.CurrValue, 'sig.Nil')
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
      if ~isa(this.CurrValue, 'sig.Nil')
        buff = this.CurrValue;
      else
        buff = [];
      end

      % MEX L37-38: Only proceed if new sample has a working value
      newval = this.Inputs(1).workingValue;
      if ~isa(newval, 'sig.Nil')
        try
          % MEX L40-46: Concatenation logic
          free = size(buff, 2) - maxSamps;
          if free >= 0  % buffer full, drop oldest and append new
            val = cat(2, buff(:, free+2:end), newval);
          else  % buffer not full, just append
            val = [buff newval];
          end
          this.workingValue = val;
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

      % MEX L5: n = numel(inputs)
      n = numel(this.Inputs);

      % MEX L7
      noMatch = n + 1;

      % MEX L9-12: get this node's current value (the current match index)
      if ~isa(this.CurrValue, 'sig.Nil')
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
        if ~isa(inputNode.workingValue, 'sig.Nil')
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
        elseif ~isa(inputNode.CurrValue, 'sig.Nil')
          % MEX L20-21: no working value, fall back to current
          pred = inputNode.CurrValue;
          predset = true;
        else
          predset = false;
        end

        % MEX L33-38: predicate has no value — can't evaluate further
        if ~predset
          this.workingValue = noMatch;
          valset = true;
          return
        end

        % MEX L40-44: predicate is true — this is the first match
        if pred
          this.workingValue = inp;
          valset = true;
          return
        end
      end

      % MEX L46-48: no matching predicate found
      this.workingValue = noMatch;
      valset = true;
    end

    function valset = keepWhen(this)
      % keepWhen transfer function - passes 'what' value only when 'when' is true
      % See +sig/+transfer/keepWhen.m for MEX reference
      %
      % this.Inputs(1) is 'what' - the value to gate
      % this.Inputs(2) is 'when' - the gate signal
      % Only passes 'what' working value (no current fallback for 'what')

      % MEX L25-28: get latest 'when' value — LATEST_VALUE pattern
      nWhen = this.Inputs(2);
      if ~isa(nWhen.workingValue, 'sig.Nil')
        when = nWhen.workingValue;
      elseif ~isa(nWhen.CurrValue, 'sig.Nil')
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
        if ~isa(nWhat.workingValue, 'sig.Nil')
          this.workingValue = nWhat.workingValue;
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

      % MEX L8-9: Get new value from input's working value
      wv = this.Inputs(1).workingValue;
      if ~isa(wv, 'sig.Nil')
        % MEX L10-11: Compare against this node's own currValue
        % ~cvset (Nil) means no current value yet — always pass through
        % ~isequal means value changed — pass through
        if isa(this.CurrValue, 'sig.Nil') || ~isequal(wv, this.CurrValue)
          this.workingValue = wv;
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

      % MEX L6-7: working values only
      armWV = this.Inputs(1).workingValue;
      releaseWV = this.Inputs(2).workingValue;
      armSet = ~isa(armWV, 'sig.Nil');
      releaseSet = ~isa(releaseWV, 'sig.Nil');

      % MEX L10: current armed state from this node's own CurrValue
      armed = this.CurrValue;

      % MEX L12-13: input must be set AND non-zero (posting 0 is ignored)
      tryArm = armSet && armWV;
      tryRelease = releaseSet && releaseWV;

      % MEX L15-27: release takes priority over arming
      if tryRelease && (tryArm || armed)
        this.workingValue = false;
        valset = true;
      elseif ~armed && tryArm
        this.workingValue = true;
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
      wv = this.Inputs(1).workingValue;
      if ~isa(wv, 'sig.Nil')
        % MEX L9: create timestamped entry
        entry = struct('time', this.transArg(), 'value', wv);
        % Accumulate onto existing log (MEX does this via appendValues in apply phase)
        this.workingValue = [this.CurrValue entry];
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

      % MEX L13-16: get latest 'delay' value — LATEST_VALUE pattern
      nDelay = this.Inputs(2);
      if ~isa(nDelay.workingValue, 'sig.Nil')
        delay = nDelay.workingValue;
      elseif ~isa(nDelay.CurrValue, 'sig.Nil')
        delay = nDelay.CurrValue;
      else
        valset = false;
        return
      end

      % MEX L18: get 'what' WORKING value only (no current fallback)
      what = this.Inputs(1).workingValue;
      if ~isa(what, 'sig.Nil')
        % MEX L21: output schedule packet
        this.workingValue = {what delay};
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
      funcs = this.transArg;
      inputs = this.Inputs;
      nElemInps = numel(funcs);
      nParInps = numel(inputs) - nElemInps - 1;

      % MEX L10-18: seed override — if seed has working value, use it
      seedNode = inputs(nElemInps + 1);
      if ~isa(seedNode.workingValue, 'sig.Nil')
        val = seedNode.workingValue;
        valavail = true;
        valset = true;
      else
        % MEX L17: use this node's own CurrValue as accumulator
        val = this.CurrValue;
        valavail = ~isa(val, 'sig.Nil');
        valset = false;
      end

      % MEX L21-32: gather parameter inputs (LATEST_VALUE pattern)
      % If any param is completely missing, bail out immediately
      pars = cell(1, nParInps);
      for ii = 1:nParInps
        parNode = inputs(nElemInps + 1 + ii);
        if ~isa(parNode.workingValue, 'sig.Nil')
          pars{ii} = parNode.workingValue;
        elseif ~isa(parNode.CurrValue, 'sig.Nil')
          pars{ii} = parNode.CurrValue;
        else
          % MEX L28: bail out — but if seed override set valset=true,
          % we must still propagate the seed value
          if valset
            this.workingValue = val;
          end
          return
        end
      end

      % MEX L34-55: apply scan functions to element inputs
      for ii = 1:nElemInps
        itemWV = inputs(ii).workingValue;
        if valavail && ~isa(itemWV, 'sig.Nil')
          f = funcs{ii};
          try
            val = f(val, itemWV, pars{:});
            valset = true;
          catch ex
            % MEX L45-48: same format string
            msg = sprintf(['Error in Net %i mapping Nodes [%s] to %i:\n' ...
              'function call ''%s'' with inputs (%s) produced an error:\n %s'], ...
              this.Net.Id, num2str([inputs.Id]), this.Id, func2str(f), ...
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
        this.workingValue = val;
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
      % Note: we use isa(x, 'sig.Nil') rather than comparing against the
      % Nil instance because the value being held may itself be a Signal,
      % and Signal overloads == / ~= to build a new comparison Signal
      % rather than return a bool.
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
          this.workingValue = dirWorking;
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
          this.workingValue = sourceWV;
          valset = true;
        elseif valset
          % New source connection was made earlier, take source's current value
          sourceCV = source.CurrValue;
          if ~isa(sourceCV, 'sig.Nil')
            this.workingValue = sourceCV;
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
      nOptions = numel(this.Inputs) - 1;

      % MEX L9-12: grab the latest indexer value, working first then current
      indexer = this.Inputs(1);
      if ~isa(indexer.workingValue, 'sig.Nil')
        idx = indexer.workingValue;
        idxwvset = true;
      elseif ~isa(indexer.CurrValue, 'sig.Nil')
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
        if ~isa(option.workingValue, 'sig.Nil')
          selval = option.workingValue;
          selwvvalset = true;
          selcvvalset = false;
        elseif ~isa(option.CurrValue, 'sig.Nil')
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
          this.workingValue = selval;
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
      inputs = this.Inputs;  % cache the property, read once not per loop pass
      nInputs = numel(inputs);
      inpvals = cell(nInputs, 1);
      wvset = false(nInputs, 1);

      % MEX L8-25: grab every input's value, working first then current.
      % bail out as soon as we find an input with no value at all
      for k = 1:nInputs
        input = inputs(k);
        wv = input.workingValue;  % read the property once, not twice
        if ~isa(wv, 'sig.Nil')
          inpvals{k} = wv;
          wvset(k) = true;
        else
          cv = input.CurrValue;
          if ~isa(cv, 'sig.Nil')
            inpvals{k} = cv;
          else
            valset = false;
            return
          end
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
        this.workingValue = what.(subs);
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
      this.workingValue = subsref(what, s);
      valset = true;
    end

    function valset = flattenStruct(this)
      % flattenStruct transfer function - flattens a struct blueprint
      % whose fields may be Signals, wiring those signals in as inputs so
      % their updates set the struct fields directly.
      % There is no MATLAB reference for this one, the MEX implements it
      % in C: network.c L852-899 (flattenStruct) plus L817-850
      % (flattenSignalStruct). Line refs below are network.c.
      %
      % this.Inputs(1) is the blueprint input. Inputs(2..end) are the
      % field inputs, wired dynamically, one per Signal in the blueprint.
      % this.transArg is a plain struct (the C kept the same state on its
      % transferer, network.h L46-48): workingInputChanges flags that the
      % inputs were rewired from an uncommitted blueprint, and
      % targetIndices/targetFields/fieldNames map field input k to
      % structval(targetIndices(k)).(fieldNames{targetFields(k)}).
      %
      % Fields fill only when their signal updates while wired. A fresh
      % blueprint emits EMPTY signal fields (see flattenSignalStruct.m:
      % all fields that are Signals in the blueprint are empty), current
      % values of the field signals are never pulled in.
      state = this.transArg;
      newOutputSet = false; % L853
      blueprintInp = this.Inputs(1); % L855

      bwv = blueprintInp.workingValue;
      if ~isa(bwv, 'sig.Nil') % L856: new blueprint struct to reconfigure using
        [structval, state] = rewireFromBlueprint(this, bwv, state);
        state.workingInputChanges = true; % L858
        this.transArg = state;
        newOutputSet = true; % L859
      else % L860: no new blueprint struct to process
        if state.workingInputChanges % L861: need to undo input changes
          bcv = blueprintInp.CurrValue;
          if ~isa(bcv, 'sig.Nil') % L862: existing blueprint available
            [structval, state] = rewireFromBlueprint(this, bcv, state);
          else % L865-868: no blueprint available, eliminate field inputs
            this.setInputs(blueprintInp);
            structval = []; % L867: a dummy that just gets discarded later
          end
          state.workingInputChanges = false; % L869
          this.transArg = state;
        else % L871-872: no working input changes to undo
          % MATLAB copy on write plays the role of mxDuplicateArray, the
          % copy happens lazily if the patch loop writes a field
          structval = this.CurrValue;
        end
      end

      % L876-889: check each field input, and update output if it changed
      inputs = this.Inputs;
      n = numel(inputs);
      if n > 1
        idxs = state.targetIndices;
        fieldNo = state.targetFields;
        names = state.fieldNames;
        for i = 1:n-1 % field inputs are 2nd input onwards
          wv = inputs(i + 1).workingValue;
          if ~isa(wv, 'sig.Nil')
            % L884-886: set field value to the field input working value
            structval(idxs(i)).(names{fieldNo(i)}) = wv;
            newOutputSet = true;
          end
        end
      end

      % L891-899
      if newOutputSet
        this.workingValue = structval;
        valset = true;
      else
        valset = false;
      end
    end

    function [structval, state] = rewireFromBlueprint(this, blueprint, state)
      % MEX flattenSignalStruct, network.c L817-850: parse the blueprint
      % with the same helper function the C called through mexCallMATLAB,
      % store the patch tables, and wire the field nodes in as inputs
      % 2..end with the blueprint input staying first (L839-842).
      [structval, inpNodes, fieldIdxs, structIdxs] = ...
        sig.node.flattenSignalStruct(blueprint);
      state.targetFields = fieldIdxs; % L828
      state.targetIndices = structIdxs; % L833
      state.fieldNames = fieldnames(structval);
      % the helper returns node ids like the C wanted, map them to the
      % node objects. repmat of a handle just copies references, the loop
      % overwrites them, this is only to preallocate the array.
      n = numel(inpNodes);
      newInputs = repmat(this.Inputs(1), 1, n + 1); % blueprint input stays first, L839
      netNodes = this.Net.nodes;
      for i = 1:n
        newInputs(i + 1) = netNodes{inpNodes(i)};
      end
      this.setInputs(newInputs); % L843
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

