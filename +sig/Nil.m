classdef Nil < handle
    % SIG.NIL Singleton class
    
    methods (Access = private)
        function this = Nil()
            % Private constructor - forces singleton pattern
        end
    end
    
    methods (Static)
        function obj = instance()
            persistent uniqueInstance
            if isempty(uniqueInstance) || ~isvalid(uniqueInstance)
                obj = sig.Nil();
                uniqueInstance = obj;
            else
                obj = uniqueInstance;
            end
        end
    end
end