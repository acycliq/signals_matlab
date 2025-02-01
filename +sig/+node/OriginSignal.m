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
        % Assign value and compute forward pass
        this.node.value = value;
        
        % Check if the topological order is already cached
        if isempty(this.topo)
            visited = {};
            topo = {};
            
            % Build the topology
            build_topo(this.node);
            
            % Cache the computed topological order
            this.topo = topo;
        else
            topo = this.topo;  % Use the cached order
            fprintf('Using cached topology.\n');
        end
        
        fprintf('Assigning %s = %g\n', this.Name, this.node.value);
        
        % Process nodes in reverse topological order
        for j = length(topo):-1:1
            n = topo{j};
            if isempty(n.Inputs)
                % Do nothing if there are no inputs
            elseif strcmp(n.transFun, 'sig.transfer.nop')
                n.value = n.Inputs(1).value;
            else
                % Ensure both inputs have valid values before applying the function
                if ~isempty(n.Inputs(1).value) && ~isempty(n.Inputs(2).value)
                    fun = n.transArg{1}; 
                    n.value = fun(n.Inputs(1).value, n.Inputs(2).value);
                end
            end
        end
    
        function build_topo(node)
            % If the node hasn't been visited yet
            if ~any(cellfun(@(x) x == node, visited))
                visited{end+1} = node;
                for i = 1:length(node.next)
                    build_topo(node.next{i});
                end
                topo{end+1} = node;
            end
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
  end
end

