function simpleChoiceWorld(t, evts, pars, visStim, in, out, audio)
%simpleChoiceWorld Basic movable grating experiment
%   Defines a task with a horizontally translatable grating that is
%   initially presented to the left or right on each trial. Centering the
%   stimulus yields a reward; moving it too far in the other direction
%   yields a noise burst. In either case it locks into the threshold
%   position during the feedback period.

% make some short names
p = pars;
wheel = in.wheel.skipRepeats();

%% when to present stimuli & allow visual stim to move
stimulusOn = evts.newTrial.delay(p.stimulusDelay);
interactiveOn = stimulusOn.delay(p.interactiveDelay);

%% wheel position to stimulus displacement
wheelOrigin = wheel.at(interactiveOn); % wheel position sampled at 'interactiveOn'
targetDisplacement = p.wheelGain*(wheel - wheelOrigin); 

%% response at threshold detection
threshold = interactiveOn.setTrigger(abs(targetDisplacement) >= abs(p.targetAzimuth));
% negative because displacement is opposite sign to initial position
response = -sign(targetDisplacement.at(threshold));

%% feedback
feedback = sign(p.targetAzimuth.at(response))*response; % positive or negative feedback
% 96KHz stereo noist burst waveform played at negative feedback
noise = p.noiseBurstAmp*p.feedbackDuration.map(@(len)randn(2, len*96e3));
audio.noiseBurst = noise.at(feedback < 0);
out.reward = p.rewardSize.at(feedback > 0); % reward only on positive feedback
stimulusOff = response.map(true).delay(p.feedbackDuration);

%% target stimulus
target = vis.grating(t, 'sinusoid', 'gaussian'); % create a Gabor grating
target.altitude = p.targetAltitude;
target.sigma = p.targetSigma;
target.spatialFrequency = p.targetSpatialFrequency;
target.contrast = p.contrast;
targetAzimuth = p.targetAzimuth + cond(... % conditional
  stimulusOn.to(interactiveOn), 0,... % no offset during fixed period
  interactiveOn.to(response),   targetDisplacement,...%offset by wheel
  response.to(stimulusOff),    -response*abs(p.targetAzimuth));%final response
target.azimuth = targetAzimuth;
target.show = stimulusOn.to(stimulusOff);
visStim.target = target; % store target in visual stimuli set

%% misc
% we want to save these signals so we put them in events with appropriate names
evts.stimulusOn = stimulusOn;
evts.stimulusOff = stimulusOff;
evts.interactiveOn = interactiveOn;
evts.targetAzimuth = targetAzimuth;
evts.response = response;
evts.feedback = feedback;
evts.endTrial = stimulusOff; % 'endTrial' is a special event used to advance the trial

end

