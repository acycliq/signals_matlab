function [net] = createNetwork(size, deleteCallback)
    
    if ~isnumeric(size) || size ~= floor(size) || size ~= abs(size)
            error('InputError:NotAnInteger', 'Input argument for size is not a positive integer.');
    end
    
    if nargin >= 1 && nargin <= 2  % Equivalent to checking (nrhs >= 1 && nrhs <= 2)
        size = round(size);  % Round the input (equivalent to roundl in C++)
        
        if nargin == 2  % Check if the second argument is provided
            deleteCallback = copy(deleteCallback);  % Duplicate the array if the callback is provided (similar to mxDuplicateArray)
        else
            deleteCallback = [];  % If no second argument, initialize deleteCallback to empty (similar to setting it to NULL)
        end
        
        net = sqCreateNetwork(size, deleteCallback);  % Create the network (equivalent to sqCreateNetwork in C++)
        
        if net >= 0 && ~isempty(deleteCallback)  % Check if network creation was successful and deleteCallback is provided
            assignin('base', 'deleteCallback', deleteCallback);  % Make deleteCallback persistent (similar to mexMakeArrayPersistent)
        end
    else
        error('sq:notEnoughArgs', 'Not enough input arguments');  % Error handling (equivalent to mexErrMsgIdAndTxt)
    end
end
