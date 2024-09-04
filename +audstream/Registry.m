classdef Registry < StructRef
  %audstream.Registry A registry for interating with PsychPortAudio devices
  %   Detailed explanation goes here
  
  properties
    Handles
  end
  
  properties (SetAccess = private)
    % Structure of available audio devices similar to that returned by
    % PsychPortAudio('GetDevices')
    Devices
  end
  
  methods
    function this = Registry(devices)
      % Populate Devices property with audio device information, namely
      % sample rate, number of output channels and device index
      if nargin == 0
        this.Devices = containers.Map('default',...
          struct('DeviceIndex', -1,...% -1 means use system default audio device
          'DefaultSampleRate', 44100,...
          'NrOutputChannels', 2));
      else
        this.Devices = containers.Map(...
          {devices.DeviceName},...
          arrayfun(@(s){s}, devices));
      end
      this.Reserved = {'Devices'};
    end
    
    function value = entryAdded(this, name, value)
      d = this.Devices(name);
      this.Handles = ...
        [this.Handles audstream.fromSignal(value, d.DefaultSampleRate, 2, d.NrOutputChannels, d.DeviceIndex)];
      this.EntryNames = {}; % Clear entry names in order to keep adding new handles
    end
  end
  
end
