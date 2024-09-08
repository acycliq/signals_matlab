classdef Node < handle
  %NODE Summary of this class goes here
  %   Detailed explanation goes here
  
  properties
    FormatSpec
    DisplayInputs
    Listeners
  end
  
  properties (SetAccess = immutable)
    Net sig.Net % Parent network
    Inputs sig.node.Node % Array of input nodes
  end
  
  properties (SetAccess = private, Transient)
    NetId double
    NodeId double % Changed from Id to NodeId to avoid conflict
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
    function this = Node(net, inputs, transferFun, appendValues)
      if nargin < 2
        inputs = [];
      end
      if nargin < 3
        transferFun = @sig.transfer.nop;
      end
      if nargin < 4
        appendValues = false;
      end
      
      this.Net = net;
      this.Inputs = inputs;
      this.NetId = net.Id;
      
      manager = sig.getNetworkManager();
      this.NodeId = manager.addNode(net.Id, [inputs.NodeId], transferFun, appendValues);
      
      this.DisplayInputs = inputs;
      this.NetListeners = event.listener(this.Net, 'Deleting', @this.netDeleted);
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
%         fprintf('Deleting node ''%s''\n', this.Name);
        deleteNode(this.NetId, this.Id);
      end
    end
    
    function v = get.CurrValue(this)
      manager = sig.getNetworkManager();
      [v, ~] = manager.getNodeCurrValue(this.NetId, this.NodeId);
    end
    
    function set.CurrValue(this, v)
      manager = sig.getNetworkManager();
      manager.submit(this.NetId, this.NodeId, v);
    end
    
    function b = get.CurrValueSet(this)
      manager = sig.getNetworkManager();
      [~, b] = manager.getNodeCurrValue(this.NetId, this.NodeId);
    end
    
    function v = get.WorkingValue(this)
      manager = sig.getNetworkManager();
      [v, ~] = manager.getNodeWorkingValue(this.NetId, this.NodeId);
    end
    
    function set.WorkingValue(this, v)
      manager = sig.getNetworkManager();
      manager.setNodeWorkingValue(this.NetId, this.NodeId, v);
    end
    
    function b = get.WorkingValueSet(this)
      manager = sig.getNetworkManager();
      [~, b] = manager.getNodeWorkingValue(this.NetId, this.NodeId);
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

