classdef OriginSignal < sig.node.Signal
  % SIG.NODE.ORIGINSIGNAL An input Signal class
  %   A subclass that provides methods for directly setting the signal's
  %   value.
  
  methods
    function this = OriginSignal(node)
      % SIG.NODE.ORIGINSIGNAL Returns an OriginSignal using a given node
      %   Makes a new origin signal out of a given sig.node.Node object.
      %   The value of this node may then be directly updated via the post
      %   method and new signals derived from it.
      %
      %   Input:
      %     node (sig.node.Node) : A node object to associate with the
      %       origin signal
      %
      %   Example:
      %     net = sig.Net;
      %     n = sig.node.Node(net);
      %     signal = sig.node.OriginSignal(n);
      %     signal.post(3)
      
      this = this@sig.node.Signal(node);
    end

    function post(this, v)
      % POST Assigns a value to this Signal
      %   Updates the value of this Signal and triggers propagration of
      %   changes through the network.  The new value is set as the node's
      %   working value while the values of all dependent nodes are
      %   recalculated, then it becomes the current value.
      %
      %   Input:
      %     v (*) : The value to assign to this Signal's node
      %
      %   Example:
      %     s.post(pi) % Assign the value of pi to origin signal, s
      %
      % See also delayedPost
      
      % an array containing the network indices of the signals which will
      % be affected as a result of this post
      affectedIdxs = submit(this.Node.NetId, this.Node.Id, v);
      applyNodes(this.Node.NetId, affectedIdxs);
    end

    function post2(this, value)

        % Set working value on origin node. Node property, not the node()
        % method, and a direct property write, both to avoid method call
        % overhead in this hot path.
        n = this.Node;
        n.workingValue = value;

        % Preallocate queue and affected list like MEX network.c L663-664
        % (QUEUE_ALLOC/STACK_ALLOC of nNodes). The queue can never exceed
        % nNodes since the queued flag stops duplicates. The affected list
        % can (nodes computed twice in one transaction), MATLAB just grows
        % the cell in that rare case.
        nNodes = numel(n.Net.nodes);
        queue = cell(1, nNodes);
        affected = cell(1, nNodes);

        % Queue origin node's targets
        targets = n.Targets;
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
        affected{1} = n;  % Add origin to affected list
        nAffected = 1;

        % Use index instead of removing from queue (queue(1)=[] is slow)
        qIdx = 1;
        while qIdx <= qTail
            curr = queue{qIdx};
            qIdx = qIdx + 1;
            curr.queued = false;

            % Just call the transfer function, it checks if inputs are ready
            computed = curr.transferMethodHandle();

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

        % Apply all working values (MEX: sqApply)
        this.applyWorkingValues(affected(1:nAffected));
    end



    function delayedPost(this, value, delay)
      % DELAYEDPOST Assigns a value to this Signal after a given delay
      %   S.DELAYEDPOST(VALUE, DELAY) or S.DELAYEDPOST({VALUE, DELAY})
      %   queues an update of this Signal's value in the network objects's
      %   Schedule, with a given delay in seconds. 
      %
      %   If the network's runSchedule method is called after the delay,
      %   the value is posted to this signal's node.
      %
      %   Input:
      %     v (*|cell) : The value to assign to this Signal's node.  May
      %       also be a cell of the form {v, delay}
      %     delay (double) : The delay in seconds from this call, after
      %       which the value should be posted.  Optional if `value` is a
      %       cell array containing the delay.
      %
      %   Example:
      %     s.delayedPost(pi, 10) % Assign value of pi to s after 10 seconds
      %     while numel(s.Node.Net.Schedule) > 0
      %       runScehdule(s.Node.Net) % check if post due
      %     end
      %
      % See also sig.Net/runSchedule, post, sig.node.Signal/delay
      t = GetSecs;
      if nargin < 3
        [value, delay] = value{:};
      end
      this.Node.Net.Schedule(end+1) = struct('nodeid', this.Node.Id, 'value', value, 'when', t + delay);
    end
    
    function ready = allInputsReady(this, node)
        % CHECK IF ALL INPUTS HAVE VALUES (MEX LATEST_VALUE logic)
        % MEX Rule: workingValue takes precedence, fallback to currValue only for readiness check
        % This implements MEX LATEST_VALUE, see line 689 of network.c: workingValue ? workingValue : currValue

        ready = true;  % Assume ready until proven otherwise
        
        % Check each input node individually - MEX LATEST_VALUE logic
        for i = 1:length(node.Inputs)
            input = node.Inputs(i);
            % MEX LATEST_VALUE: check working value first, then current value
            if input.workingValue ~= sig.Nil.instance()
                % Input has working value - it's ready
                continue;
            elseif input.CurrValue ~= sig.Nil.instance()
                % Input has current value but no working value - it's ready
                continue;
            else
                % Input has no value at all - not ready
                ready = false;
                return;
            end
        end
        
        % If we get here, all inputs are ready
        % ready = true (already set above)
    end
    
    function applyWorkingValues(~, affectedNodes)
        % Apply all working values to current values
        nilInstance = sig.Nil.instance();
        for i = 1:length(affectedNodes)
            node = affectedNodes{i};
            % MEX network.c L368: skip nodes with no working value to apply.
            % A node can appear more than once in the affected list and the
            % first pass commits and clears its value, so this also stops
            % the event target being notified twice for one commit. Same
            % goes for values retracted during the transaction.
            if isa(node.workingValue, 'sig.Nil')
                continue
            end
            % Inline commit (working -> current, then clear), direct
            % property writes instead of commitWorkingValue to save two
            % method calls per node in this hot path
            node.CurrValue = node.workingValue;
            node.workingValue = nilInstance;
            % Notify event target after commit (matches MEX network.c L378-381)
            if ~isempty(node.EventTarget)
                node.EventTarget.valueChanged(node.CurrValue);
            end
        end
    end
  end

end

