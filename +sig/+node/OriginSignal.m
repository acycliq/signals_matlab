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
        this.node.CurrValue = value;

        % Check if the topological order is already cached
        if isempty(this.topo)
            this.topo = this.build_topo(this.node);
        else
            fprintf('Using cached topology.\n');
        end

        topo = this.topo;

        fprintf('Assigning %s = %g\n', this.Name, this.node.CurrValue);

        % Process nodes in reverse topological order
        for j = length(topo):-1:1
            n = topo{j};
            if isempty(n.Inputs)
                % Do nothing if there are no inputs
            else
                % Ensure both inputs have valid values before applying the function
                if ~isempty(n.Inputs(1).CurrValue) && ~isempty(n.Inputs(2).CurrValue)
                    % ok, that looks to work but shouldnt I be using mapn
                    % instead of getting the fun from transArg?
                    % Also why the second element in transArg is always
                    % [1]?
                    fun = n.transArg{1};
                    n.CurrValue = fun(n.Inputs(1).CurrValue, n.Inputs(2).CurrValue);
                end
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

