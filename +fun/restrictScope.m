function closeWith_fun = restrictScope(f)
% FUN.RESTRICTSCOPE Eliminate variables outside a function's scope
%   Detailed explanation goes here
%
% Part of Burgbox

% 2013-10 CB created

closeWith_fun = func2str(f);
if closeWith_fun(1) ~= '@'
  closeWith_fun = ['@' closeWith_fun];
end
clear f;

closeWith_fun = eval(closeWith_fun);

end

