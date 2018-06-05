%% en_writetable.m
% concatenate csv files from many ids as a single table
%
% Usage:
%   df = en_writetable(ids)
%   df = en_writetable(ids, 'param', val, etc.)
%
% Input:
%   ids: numeric, default all incl in diary
%   'regions': default {'aud', 'mot', 'pmc'}
%   'stim': 'sync' (default) or 'mir'
%   'task': 'eeg' (default) or 'tapping'
%   'save': boolean, whether to save a csv, default true
%
% Output:
%   df: table with data
%   also writes a csv file if save is specified
%   note that entrainment is normalized by id ((val - mean) / std)


function df = en_writetable(ids, varargin)
if nargin > 0 && ischar(ids)
    varargin = [{ids} varargin];
    ids = [];
end

% if no ids given, use all marked as incl in diary
if nargin < 1 || isempty(ids) || ischar(ids)
    d = en_load('diary', 'incl');
    ids = d.id;
end

% defaults
regions = {'aud', 'mot', 'pmc'};
stim = 'sync';
task = 'eeg';
do_save = true;

for i = 1:2:length(varargin)
    param = varargin{i};
    val = varargin{i+1};
    if isempty(val), continue, end
    switch lower(param)
        case {'region', 'regions'}, regions = val;
        case 'stim',                stim = val;
        case {'task','trig'},       task = val;
        case {'do_save', 'save'},   do_save = val;
    end
end
if ~iscell(regions), regions = cellstr(regions); end

for i = 1:length(ids)
    id = ids(i);
    idStr = num2str(id);
    fprintf('  Collecting id %i\n', id)

    for j = 1:length(regions)
        region = regions{j};
        fname = fullfile(getpath('entrainment'), ...
            [stim, '_', task], [idStr, '_', region, '.csv']);
        tmp = readtable(fname);
        if j == 1
            tmp_id = tmp;
        else
            if all(tmp_id.portcode == tmp.portcode) && ...
                all(tmp_id.harmonic == tmp.harmonic)
                tmp_id.([region,'_comp']) = tmp.([region,'_comp']);
                tmp_id.(region) = tmp.(region);
            else
                error(['Portcodes or harmonics don''t match for id ', ...
                    num2str(id), '.'])
            end
        end
    end

    % add current id to master table
    if i == 1
        df = tmp_id;
    else
        df = [df; tmp_id]; %#ok<AGROW>
    end

end

% make some fields categorical
cats = {'stim', 'task', 'rhythm', 'excerpt'};
for i = 1:length(cats)
    df.(cats{i}) = categorical(df.(cats{i}));
end
df.rhythm = reordercats(df.rhythm, {'simple', 'optimal', 'complex'});

% add cols with eeg entrainment data normalized by id
ids = unique(df.id);
for i = 1:length(regions)
    region = regions{i};
    df.([region, '_norm']) = nan(height(df), 1);
end
for i = 1:length(ids)
    id = ids(i);
    for j = 1:length(regions)
        region = regions{j};
        x = df.(region)(df.id==id);
        x_norm = (x - mean(x)) / std(x);
        df.([region, '_norm'])(df.id==id) = x_norm;
    end
end

% save a csv
if do_save
    writetable(df, ['~/projects/en/tables/en_', stim, '_', task, '_', ...
        datestr(now, 'yyyy-mm-dd_HH-MM-SS'), '.csv'])
end
end
