classdef Node < handle
  %NODE Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    FormatSpec
    DisplayInputs
    Listeners
  end
  
  properties (SetAccess = immutable)
    NetId double % Parent network ID
    Inputs % Array of input nodes (remove the sig.node.Node restriction)
  end
  
  properties (SetAccess = private, Transient)
    Id double 
    transferFun % That is probably called transferer on the MEX side 
    appendValues
    % I think  I should also move here the rest of the properties declared
    % in network.h, line 52 (targets, eventsTarget, inUse, queued)
  end
  
  properties (Dependent)
    Name
    CurrValue
    CurrValueSet
    WorkingValue
    WorkingValueSet
  end
  
  properties (Access = private)
    NameOverride
    NetListeners
  end
  
  methods
    function this = Node(net, nodeId, inputs, transferFun, appendValues)
      if nargin < 3
        inputs = [];
      end
      if nargin < 4
        transferFun = @sig.transfer.nop;
      end
      if nargin < 5
        appendValues = false;
      end
      
      this.NetId = net.Id;
      this.Id = nodeId;
      this.Inputs = inputs;
      this.transferFun = transferFun;
      this.appendValues = appendValues;
      
      % Set other properties as needed
      this.DisplayInputs = inputs;
      this.NetListeners = event.listener(net, 'Deleting', @this.netDeleted);
      
      % You may want to store transferFun and appendValues as properties if needed
    end
    
    function v = get.Name(this)
      if ~isempty(this.NameOverride)
        v = this.NameOverride;
      else
        childNames = names(this.DisplayInputs);
        v = sprintf(this.FormatSpec, childNames{:});
      end
    end
    
    function set.Name(this, v)
      this.NameOverride = v;
    end
    
    function delete(this)
      if ~isempty(this.Id)
        fprintf('Node destructor: Deleting from network %d node %d \n',  this.NetId, this.Id);
        sig.deleteNodeImpl(this.NetId, this.Id);
      end
    end
    
    function v = get.CurrValue(this)
      manager = sig.getNetworkManager();
      [v, ~] = manager.getNodeCurrValue(this.NetId, this.Id);
    end
    
    function set.CurrValue(this, v)
      manager = sig.getNetworkManager();
      manager.submit(this.NetId, this.Id, v);
    end
    
    function b = get.CurrValueSet(this)
      manager = sig.getNetworkManager();
      [~, b] = manager.getNodeCurrValue(this.NetId, this.Id);
    end
    
    function v = get.WorkingValue(this)
      manager = sig.getNetworkManager();
      [v, ~] = manager.getNodeWorkingValue(this.NetId, this.Id);
    end
    
    function set.WorkingValue(this, v)
      manager = sig.getNetworkManager();
      manager.setNodeWorkingValue(this.NetId, this.Id, v);
    end
    
    function b = get.WorkingValueSet(this)
      manager = sig.getNetworkManager();
      [~, b] = manager.getNodeWorkingValue(this.NetId, this.Id);
    end
    
    function n = names(those)
      n = cell(numel(those), 1);
      for i = 1:numel(those)
        n{i} = those(i).Name;
      end
    end
    
    function setInputs(this, nodes)
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

