classdef OriginSignal < sig.node.Signal
  % SIG.NODE.ORIGINSIGNAL An input Signal class
  %   A subclass that provides methods for directly setting the signal's
  %   value.
 properties (Access = private)
     topo = [];  % Initialize as empty. It will keep the topological map of the network
 end
  
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
        % TWO-PHASE WORKING VALUES SYSTEM - Matches MEX submit/applyNodes pattern
        % Phase 1: Compute working values for affected nodes (like MEX transact)
        % Phase 2: Copy working values to current values (like MEX sqApply)

        % Cache topology structure for efficient target traversal
        if isempty(this.topo)
            this.topo = this.build_topo(this.node);
        end

        % Compute working values without modifying current values
        % Matches MEX transact() function in network.c:659-687
        
        % Set working value on origin node (NOT current value!)
        % should be similar to setNodeWorkingValue(node, value) from network.c
        this.node.setWorkingValue(value);

        affected = {this.node};  % Include origin node in affected list!
                                 % Without this, origin never gets commitWorkingValue() called
        queue = {this.node};     % nodes whose targets need processing
        
        % Speedup improvement: Use boolean array instead of expensive containers.Map
        % Get max node ID to pre-allocate boolean array
        maxNodeId = 0;
        for i = 1:length(this.topo)
            if this.topo{i}.Id > maxNodeId
                maxNodeId = this.topo{i}.Id;
            end
        end
        processed = false(maxNodeId, 1);  % Pre-allocated boolean array - much faster!

        while ~isempty(queue)
            % Dequeue next node to process (BFS order)
            current = queue{1};
            queue(1) = [];  % Remove first element
            
            % Process all target nodes of current node
            for i = 1:length(current.Targets)
                target = current.Targets{i};
                
                % Skip if we already processed this target node
                % Speedup improvement: Direct boolean array access instead of expensive isKey()
                if ~processed(target.Id)
                    % Check if target node can compute (all inputs have values)
                    if this.allInputsReady(target)
                        % Call targets transfer function to compute working value
                        valset = target.transferMethodHandle();
                        
                        % If transfer function computed a new working value
                        if valset
                            % Add to affected nodes list (for application at a later stage)
                            affected{end+1} = target;
                            
                            % Add to queue for further propagation to its targets
                            queue{end+1} = target;
                        end
                    end
                    
                    % Mark as processed to avoid revisiting
                    % Speedup improvement: Direct boolean array assignment - much faster than Map
                    processed(target.Id) = true;
                end
            end
        end
        

        % Apply working values to current values for all affected nodes
        % This includes the origin node plus all computed nodes
        for i = 1:length(affected)
            % Also clears working value: n[currNode].workingValue = NULL in network.c:371
            affected{i}.commitWorkingValue();
        end
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
            if ~node.Inputs(i).hasCurrValue
                ready = false;  % Found unready input
                return;
            end
        end
        
        % If we get here, all inputs are ready
        % ready = true (already set above)
    end
  end

  methods (Access = private)
      function topo = build_topo(this, node)
          % build_topo Computes the topological ordering of nodes
          %
          %   topo = build_topo(node) traverses the network starting
          %   from 'node', collecting nodes in a topological order so that
          %   each node's dependencies are processed before the node itself.

          visited = {};
          topo = {};

          % Recursive helper function to perform the traversal.
          function recursive_topo(n)
              if ~any(cellfun(@(x) x == n, visited))
                  visited{end+1} = n;
                  for i = 1:length(n.Targets)
                      recursive_topo(n.Targets{i});
                  end
                  topo{end+1} = n;
              end
          end

          % Start the recursion from the input node.
          recursive_topo(node);
      end
  end

end

