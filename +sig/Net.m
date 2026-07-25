classdef Net < handle
  %sig.Net A network for managing Signals nodes.
  %   A network that contains and manages Signals nodes.  A new Signals
  %   network is created in mexnet upon instantiation and new nodes may be
  %   added to the network via methods such as `origin`,
  %   `subscriptableOrigin` and `rootNode`.
  %
  %   Example:
  %     net = sig.Net;
  %     input = net.origin('input signal');
  %     output = input ^ 2;
  
  properties
    % Debug mode.  When true the names and function line numbers are
    % recorded when new nodes are added to the network.
    Debug matlab.lang.OnOffSwitchState = 'off'
    nodes = []

    % maybe these two below are not needed outside mexnet?
    active = true
    deleteCallback = []
  end
  
  properties (Transient)
    % A structure holding node ids, the values they should take and the
    % delay before they are applied.  Used for delayed posting of values.
    Schedule
    Listeners
  end
  
  properties (SetAccess = private, Transient)
    % The unique network identifier.
    Id double
    % The names of the network's nodes mapped to their ids; for debugging
    % purposes.
    NodeName
    % A map of function line numbers where each node was defined; for
    % debugging purposes.
    NodeLine
  end

  properties (Dependent)
    nNodes  % Number of non-empty nodes in the network
  end
  
  events
    % Triggered when the object is being deleted. NB: The underlying mexnet
    % may be deleted without a call to this.  @TODO: Use superclass event
    % instead?
    Deleting
  end
  
  methods
    function this = Net(size)
      % SIG.NET Create a new network for managing Signal's nodes
      %   Initializes a network of a given size in mexnet that will contain
      %   and manage Signals nodes.
      %
      %   Input:
      %     size (int) : The maximum number of nodes allowing in the
      %       network.  Default: 4000
      %
      % See also sig.node.Signal, sig.node.Node

      if nargin < 1
        size = 4000;
      end
      this.Id = this.createNetwork(size);
      this.Schedule = struct('nodeid', {}, 'value', {}, 'when', {});
      this.NodeLine = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
      this.NodeName = containers.Map('KeyType', 'int32', 'ValueType', 'char');
    end

    function Id = createNetwork(this, size)
        % Allocate the first free network slot and register this net so
        % it can be found by id, the same bookkeeping the C kept in its
        % networks[MAX_NETWORKS] table (network.c L7, L632-639, ids are
        % 0 based and at most 10 networks exist at once)
        reg = sig.Net.registry();
        Id = [];
        for slot = 0:9
            if ~isKey(reg, slot) || ~isvalid(reg(slot))
                Id = slot;
                break
            end
        end
        % The C returns -1 when full and lets the caller fail downstream,
        % we fail loudly here instead, a deliberate and documented
        % deviation, silent -1 ids helped nobody in fifteen years
        assert(~isempty(Id), 'sig:Net:full', ...
            'No free network slots, at most 10 networks can exist at once');
        this.nodes = cell(1, size);
        % register LAST, like the C sets active = TRUE as its final step
        % (network.c L62), so the net is only resolvable once fully built
        reg(Id) = this; %#ok<NASGU> handle map, updates the shared registry
    end
    
    function nodeId = addNode(this, newNode)
        nodeId = find(cellfun(@isempty, this.nodes), 1, 'first');
        if isempty(nodeId)
            error('No empty cell found in the nodes array.');
        end
        newNode.Id = nodeId;
        this.nodes{nodeId} = newNode;
    end

    function runSchedule(this)
    % Apply values to nodes that are due to be updated
    %
    %   Applies values to nodes that are due to be updated, i.e. those that
    %   have a delayed post.  This method should be manually run or set as
    %   a callback in a timer function.
    %   Example:
    %     net = sig.Net; % Create network
    %     tmr = timer('TimerFcn', @(~,~)net.runSchedule,...
    %       'ExecutionMode', 'fixedrate', 'Period', 0.01);
    %     start(tmr) % Run schedule every 100 ms
    %     
    %     delayedSig = sig1.delay(5) % New signal delayed by 5 sec
    %     h = output(delayedSig);
    %     delayedPost(s, pi, 5) % Post to input signal also delayed by 5 sec
    %     ... 10 seconds later...
    %     3.1416
    %
    % See also sig.node.OriginSignal/delayedPost, sig.node.Signal/delay
      if numel(this.Schedule) > 0
        % slice out due tasks
        dueIdx = [this.Schedule.when] < GetSecs;
        dueTasks = this.Schedule(dueIdx);
        this.Schedule(dueIdx) = [];
        % work through them, each due task is its own full transaction,
        % delivered through the pure engine instead of the MEX
        % submit + applyNodes pair (same operation, see sig.node.Node/transact)
        for ti = 1:numel(dueTasks)
          % dt = GetSecs - dueTasks(ti).when;
          this.nodes{dueTasks(ti).nodeid}.transact(dueTasks(ti).value);
        end
      end
    end
    
    function s = origin(this, name)
      % Create an origin signal with a specified name
      %  Returns a signal of the class 'OriginSignal', which can have its
      %  values set via the post method.  The name is an optional string
      %  identifier.
      %
      %  Example:
      %   net = sig.Net; % Create network
      %   inputSig = net.origin('input');
      %   post(inputSig, pi)
      %   inputSig.Node.CurrValue
      %   >> ans =
      %          3.1416
      %
      % See also sig.node.OriginSignal, sig.Net.subscriptableOrigin
      rn = rootNode(this, name);
      s = sig.node.OriginSignal(rn);
    end
    
    function s = subscriptableOrigin(this, name)
      % Create a subscriptable origin signal with a specified name
      %  Returns a signal of the class 'SubscriptableOriginSignal', which
      %  can have its values set via either subassign or the post method.
      %  This signal can be subscripted to obtain a new signal whose value
      %  results from subscripting the value of the Origin Signal. The name
      %  is an optional string identifier.
      %
      %  NB: To assign values using `post`, using 'dot syntax' will not
      %  work (see example 2).   
      %
      %  Example 1 - Assigning values:
      %    net = sig.Net; % Create network
      %    structSig = net.subscriptableOrigin('structSig');
      %    s = structSig.a;
      %    class(s)
      %    >> ans =
      %         'sig.node.Signal'
      %    structSig.a = pi; % assign value to field 'a'
      %    s.Node.CurrValue
      %    >> ans =
      %         3.1416
      %
      %  Example 2 - Posting structs:
      %    net = sig.Net; % Create network
      %    structSig = net.subscriptableOrigin('structSig');
      %    s = structSig.a; % A signal that updates with the value of 'a'
      %    post(structSig, struct('a', pi)) % structSig.post(...) will fail
      %    s.Node.CurrValue
      %    >> ans =
      %         3.1416
      %
      % See also sig.Net.OriginSignal, sig.node.SubscriptableOriginSignal
      s = sig.node.SubscriptableOriginSignal(rootNode(this, name));
    end
    
    function s = fromUIEvent(this, uihandle, callback)
      % Create a Signal from a UI event
      %  Returns a signal of the class 'SubscriptableOriginSignal', which
      %  will update with the fields of an event.EventData object thrown by
      %  the uihandle event.  This signal can be subscripted to obtain the
      %  property values of the EventData (subscripting returns a Signal).
      %
      %  Inputs:
      %    uihandle (handle) : A handle to a figure, axes or ui element
      %    callback (char) : The name of the property to set the callback
      %      function for.  Default: 'Callback'
      %
      %  Output:
      %    s (sig.node.SubscriptableOriginSignal) : A signal which will
      %      update with the event data each time the UI callback is
      %      triggered
      %
      %  Example:
      %   net = sig.Net; % Create network
      %   f = figure;
      %   keyPresses = net.fromUIEvent(f, 'KeyPressFcn');
      %   h = output(keyPresses.Key); % print key name to command window
      %
      % See also sig.node.onValue
      if nargin < 3
        callback = 'Callback';
      end
      name = sprintf('%s@%sEvents', get(uihandle, 'Type'), callback);
      s = sig.node.SubscriptableOriginSignal(rootNode(this, name));
      set(uihandle, callback, @(src,evt)post(s, evt));
    end
    
    function n = rootNode(this, name)
    % Create a new node with a specified name
    %  The name of a node is usually a string representation of its
    %  transfer function (the FormatSpec), however some nodes (i.e. ones
    %  that simply hold a value, such a seed), have no transfer function.
    %  This function allows one to create such a node.  If the name is not
    %  specified, the node's id is used instead.
    %
    % See also sig.node.Node
      n = sig.node.Node(this);
      if nargin < 2
        n.Name = sprintf('n%i', n.Id);
      else
        n.Name = name;
      end
      n.FormatSpec = n.Name;
    end
    
    function delete(this)
      disp('**net.delete**');
      if ~isempty(this.Id)
        % same message the mex printed on deletion (network.c L71)
        fprintf('Deleting net(%d)\n', this.Id)
        % free the slot BEFORE tearing down, like the C which sets the
        % network inactive first "for safety (possible reentrancy)"
        % (network.c L72), so nothing can resolve this net by id while
        % its nodes are being destroyed
        reg = sig.Net.registry();
        if isKey(reg, this.Id)
          remove(reg, this.Id);
        end
        notify(this, 'Deleting');
        this.nodes = [];
      end
    end

    function count = get.nNodes(this)
        % Compute the number of non-empty elements in the nodes array
        count = sum(~cellfun(@isempty, this.nodes));
    end
  end
  
  methods (Static)
    function map = registry()
      % The table of live networks by id, the pure equivalent of the C's
      % global networks[MAX_NETWORKS] array (network.c L47). Shared
      % handle, callers mutate it in place.
      persistent reg
      if isempty(reg)
        reg = containers.Map('KeyType', 'double', 'ValueType', 'any');
      end
      map = reg;
    end

    function net = byId(id)
      % Resolve a network id to the live sig.Net, used by the mexcompat
      % adapters that serve the old submit/applyNodes call signatures
      reg = sig.Net.registry();
      assert(isKey(reg, id) && isvalid(reg(id)), 'sig:Net:invalidId', ...
        '%d is not a valid network id', id);
      net = reg(id);
    end
  end

  methods (Access = protected)
%     function mexNetworkDeleted(this)
%       fprintf('network #%i''s storage deleted\n', this.Id);
%       this.Id = [];
%     end
  end
  
end