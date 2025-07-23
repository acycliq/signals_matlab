classdef (Sealed) NotSet
    % Class for uninitialized node values
    % This class is only used for node initialization. 
    % Performance-critical code uses boolean flags
    % (hasCurrValue) instead of expensive isa() type checking.
    %
    % INITIALIZATION EXAMPLE:
    %   currNodeValue = sig.NotSet()  % Clear semantic meaning of "uninitialized"
    %
    % PERFORMANCE NOTE: We replaced expensive calls like:
    %   isa(node.currNodeValue, 'sig.NotSet') 
    % with fast boolean checks like:
    %   node.hasCurrValue
    % I think it will safe to make the class redudant and initialise as a
    % boolean: currNodeValue = False
end

