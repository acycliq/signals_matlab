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
        % Pure matlab version to replace mexnet submit/applyNodes
        % Two phases: first compute all working values, then apply them
        
        % Start by setting the working value on the origin node
        this.node.setWorkingValue(value);
        
        % Keep track of nodes that will be affected by this change
        affectedNodes = {this.node};  % start with just the origin
        processedNodeIds = [];        % track what you've already processed
        
        % Keep going until you don't find any new nodes to process
        foundNewNodes = true;
        while foundNewNodes
            foundNewNodes = false;
            newNodes = {};
            
            % Go through each node in the affected list
            for i = 1:length(affectedNodes)
                currentNode = affectedNodes{i};
                
                % Skip nodes you've already processed
                if any(processedNodeIds == currentNode.Id)
                    continue;
                end
                
                % Mark this one as done
                processedNodeIds(end+1) = currentNode.Id;
                
                % Now look at all the nodes that depend on this one
                for j = 1:length(currentNode.Targets)
                    targetNode = currentNode.Targets{j};
                    
                    % Don't add the same node twice to the list
                    alreadyKnown = false;
                    for k = 1:length(affectedNodes)
                        if affectedNodes{k}.Id == targetNode.Id
                            alreadyKnown = true;
                            break;
                        end
                    end
                    if alreadyKnown
                        continue;
                    end
                    
                    % See if this target can actually compute something
                    if this.allInputsReady(targetNode)
                        % Try to run the transfer function
                        wasComputed = targetNode.transferMethodHandle();
                        
                        if wasComputed
                            % Great, this node computed something new
                            newNodes{end+1} = targetNode;
                            foundNewNodes = true;
                        end
                    end
                end
            end
            
            % Add whatever new nodes you found this round
            affectedNodes = [affectedNodes, newNodes];
        end
        
        % Finally, apply all the working values to current values
        for i = 1:length(affectedNodes)
            affectedNodes{i}.commitWorkingValue();
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

