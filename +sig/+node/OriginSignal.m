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

        % Set working value on origin node
        this.node.setWorkingValue(value);

        % Initialize queue and affected list
        queue = {};      % Processing queue
        affected = {};   % List of affected nodes

        % Queue origin node's targets
        nTargets = length(this.node.Targets);  % save length so I don't call it multiple times
        for i = 1:nTargets
            target = this.node.Targets{i};
            if ~target.queued
                queue{end+1} = target;
                target.queued = true;
            end
        end
        affected{end+1} = this.node;  % Add origin to affected list

        % Use index instead of removing from queue (queue(1)=[] is slow)
        qIdx = 1;
        while qIdx <= length(queue)
            curr = queue{qIdx};
            qIdx = qIdx + 1;
            curr.queued = false;

            % Just call the transfer function, it checks if inputs are ready
            computed = curr.transferMethodHandle();

            if computed  % If node computed new value
                affected{end+1} = curr;  % Add to affected list

                % Queue all targets
                nTargets = length(curr.Targets);  % save it so i don't keep calling length (used this trick elsewhere)
                for j = 1:nTargets
                    target = curr.Targets{j};
                    if ~target.queued
                        queue{end+1} = target;
                        target.queued = true;
                    end
                end
            end
        end

        % Apply all working values (MEX: sqApply)
        this.applyWorkingValues(affected);
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
    
    function applyWorkingValues(this, affectedNodes)
        % Apply all working values to current values
        for i = 1:length(affectedNodes)
            affectedNodes{i}.commitWorkingValue();
        end
    end
  end

end

