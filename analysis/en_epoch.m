function [EEG, portcodes] = en_epoch(EEG, stimType, trigType, timelim)
% EEG = en_epoch(EEG, stimType, taskType [, timelim])
if ~ismember(lower(stimType), {'sync', 'mir'}),    error('Invalid stimType.'), end
if ~ismember(lower(trigType), {'eeg', 'tapping'}), error('Invalid trigType'), end

% default extraction window
% 1 second of silence after portcode, so stimulus plays from 1-31 seconds
% leave 3 seconds to start entraining, so start epoch at 5 seconds
if nargin < 4 || isempty(timelim), timelim = [4 31]; end % 30 epochs x 27-seconds = 13.5 minutesj

% EEG.setname is assumed to be the id
try
    id = str2num(EEG.setname);
catch
    error('EEG.setname should be the id.')
end

d = en_load('diary', id);

%% get event indices
% 'eventindices' param/val pair in pop_epoch is the indices of EEG.event from where
%   you want ot extract all epochs that have the labels of the events input
% so, to get all the sync trials from block 1 (of 4), you would have
% EEG = pop_epoch(EEG, syncPortcodes, [5 31], 'eventindices', 1:30)

% start with all portcode indices
eventindices = 1:length(EEG.event);

% remove extra portcodes
if ~isnan(d.rmportcodes)
    disp('Removing extra portcodes...')
    eventindices(d.rmportcodes) = [];
end

% add nans for missed portcodes
if ~isnan(d.missedportcodes)
    disp('Adding nans for extra portcodes...')
    for i = 1:length(d.missedportcodes)
        if d.missedportcodes(i) == 1
            eventindices = [nan eventindices];
        elseif d.missedportcodes(i) == 120
            eventindices = [eventindices nan];
        else
            eventindices = [eventindices(1:d.missportcodes(i)-1) ...
                            nan ...
                            eventindices(d.missportcodes(i)+1:end)];
        end
    end
end

% get desired event indices and portcodes (event types)
if strcmpi(stimType, 'sync')
    if strcmpi(trigType, 'eeg')

        if     d.order == 1,   eventindices = eventindices(1:30);
        elseif d.order == 2,   eventindices = eventindices(31:60);
        end

    elseif strcmpi(trigType, 'tapping')
        if     d.order == 1,   eventindices = eventindices(31:60);
        elseif d.order == 2,   eventindices = eventindices(1:30);
        end
    end
elseif strcmpi (stimType, 'mir')
    if strcmpi(trigType, 'eeg')
        if     d.order == 1,   eventindices = eventindices(61:90);
        elseif d.order == 2,   eventindices = eventindices(91:120);
        end
    elseif strcmpi(trigType, 'tapping')
        if     d.order == 1,   eventindices = eventindices(91:120);
        elseif d.order == 2,   eventindices = eventindices(61:90);
        end
    end
end

% remove nans (probably due to some missed portcodes)
eventindices(isnan(eventindices)) = [];

% get portcodes in order to return to caller
portcodes = [EEG.event.type];
portcodes = portcodes(eventindices);

% we can just lock to all events (sync and mir) because we're
%   restricting by eventindices anyway
eventTypes = unique([EEG.event.type]);
eventTypes = regexp(num2str(eventTypes), '\s*', 'split'); % convert numeric to cell of strings

% do epoching
EEG = pop_epoch(EEG, eventTypes, timelim, ...
    'eventindices', eventindices, ...
    'newname',      EEG.setname); % keep same setname

end
