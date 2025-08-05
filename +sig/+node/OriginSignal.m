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
        % Pure MATLAB version replicating MEX transact philosophy (network.c:659-687)
        % Uses queue-based processing with natural dependency ordering
        
        % Set working value on origin node (like MEX setNodeWorkingValue)
        this.node.setWorkingValue(value);
        
        % Initialize queue and affected list (like MEX QUEUE_ALLOC/STACK_ALLOC)
        queue = {};      % Processing queue (like MEX todo queue)
        affected = {};   % List of affected nodes (like MEX affected stack)
        
        % Queue origin node's targets (like MEX QUEUE_PUT_ALL line 669)
        for i = 1:length(this.node.Targets)
            target = this.node.Targets{i};
            if ~target.queued                    % MEX: if (!(vals)[i]->queued)
                queue{end+1} = target;
                target.queued = true;            % MEX: (vals)[i]->queued = true
            end
        end
        affected{end+1} = this.node;  % Add origin to affected list (like MEX line 670)
        
        % Process queue until empty (like MEX while (!QUEUE_IS_EMPTY(todo)) line 671)
        while ~isempty(queue)
            curr = queue{1};        % Get next node from front (like MEX QUEUE_GET)
            queue(1) = [];          % Remove from front of queue
            curr.queued = false;    % MEX: curr->queued = false (line 673)
            
            % Try to compute current node (like MEX transfer(curr) line 676)
            if this.allInputsReady(curr)
                computed = curr.transferMethodHandle();
                
                if computed  % If node computed new value (like MEX if (propagate) line 678)
                    affected{end+1} = curr;  % Add to affected list (like MEX line 680)
                    
                    % Queue all targets (like MEX QUEUE_PUT_ALL line 682)
                    for j = 1:length(curr.Targets)
                        target = curr.Targets{j};
                        if ~target.queued                % MEX: if (!(vals)[i]->queued)
                            queue{end+1} = target;
                            target.queued = true;        % MEX: (vals)[i]->queued = true
                        end
                    end
                end
            end
        end
        
        % Apply all working values (like MEX sqApply)
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
        % CHECK IF ALL INPUTS OF A NODE HAVE CURRENT VALUES
        % Used to determine if a node can compute its transfer function

        ready = true;  % Assume ready until proven otherwise
        
        % Check each input node individually
        for i = 1:length(node.Inputs)
            if node.Inputs(i).currValue == sig.Nil.instance()
                ready = false;  % Found unready input
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

