classdef ScanningSignal < sig.node.Signal
  %sig.node.ScanningSignal Signal whose value is update iteratively
  %   Detailed explanation goes here
  
  methods
    function this = ScanningSignal(node)
      this = this@sig.node.Signal(node);
    end

    % Add a signal to use to iteratively update this one.
    %
    % acc.scan(items, f) adds a signal whose values are used to iteratively
    % update the values on this signal. The function f will be called with
    % each new value of items, together with the existing value of this
    % signal to obtain its new value, as in newacc = f(itemval, accval).
    function addScan(this, items, f)
      node = this.Node;
      inp = [node.Inputs.Id]; % fetch current inputs
%       nodeInputs(node.NetId, node.Id, inp);
    end
  end  
end

