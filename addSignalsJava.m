function addSignalsJava()
%addSignalsJava Adds java classes for signals to MATLAB classpath
%   Detailed explanation goes here

jcp = fullfile(fileparts(mfilename('fullpath')), 'java');
if ~any(strcmp(javaclasspath, jcp))
  javaaddpath(jcp);
end

end

