% SPDX-License-Identifier: GPL-3.0-only

function BidsCleanupCtfMeg(Folder, isDryRun, isMoveHz, isAnySize, isCheckEvents)
    % Remove empty or unnecessary files (e.g. hz.ds) from CTF MEG recordings in BIDS dataset.
    %
    % This reduces the number of files and accelerates transfers.
    % Folder can be a single CTF MEG recording (.ds) or a BIDS dataset root folder.
    % isDryRun [true]: if set to true, will only display information and proposed actions. 
    %                  Set to false to delete files. Use with care!
    % isMoveHz [false]: if true, move hz.ds to sourcedata instead of deleting them. Requires
    %                  running on a BIDS dataset, and not a single recording.
    % isAnySize [false]: if true, file sizes are not checked and even non-empty files in the
    %                  "unnecessary" list are deleted.
    % isCheckEvents [true]: if true, look if .mrk file contains only "fake" events at time zero of
    %                  trials, in which case delete the .mrk file, and corresponding BIDS .evt file.
    %                  This relies on the .evt file and won't do anything without it.
    
    % Marc Lalancette, 2026-10-14

    % See Bids_ctf_rename_ds for all possible files inside .ds. That function now calls this
    % optionally for cleanup. But for anonymisation, these files would already be deleted: .bak,
    % .hist, .newds, processing.cfg.

    if nargin < 4 || isempty(isCheckEvents)
        isCheckEvents = true;
    end
    if nargin < 3 || isempty(isAnySize)
        isAnySize = false;
    end
    if nargin < 3 || isempty(isMoveHz)
        isMoveHz = false;
    end
    if nargin < 2 || isempty(isDryRun)
        isDryRun = true;
    end

    if strcmp(Folder(end-2:end), '.ds')
        isBids = false;
        if isMoveHz
            error('The option to move hz.ds is only available when running on a BIDS dataset, not individiual recordings.');
        end
    else
        isBids = true;
        BidsFolder = Folder;
        Folder = fullfile(BidsFolder, 'sub-*', '**', '*.ds');
    end
    % Delete "head zeroing" recordings
    HzDs = dir(fullfile(Folder, 'hz.ds*')); % last * to avoid listing contents
    for iHz = 1:numel(HzDs)
        File = fullfile(HzDs(iHz).folder, HzDs(iHz).name);
        if isMoveHz % implies isBids
            NewFile = replace(File, BidsFolder, fullfile(BidsFolder, 'sourcedata'));
            % Simplify by not having two .ds folders
            NewFile = replace(NewFile, 'meg.ds/hz.ds', 'meghz.ds');
            fprintf('Moving %s to %s\n', File, NewFile);
            if ~isDryRun
                [IsOk, Message] = movefile(File, NewFile);
                if ~IsOk, error(Message); end
            end
        else
            fprintf('Deleting %s\n', File);
            if ~isDryRun
                [IsOk, Message] = rmdir(File, 's'); % recursive
                if ~IsOk, error(Message); end
            end
        end
    end
    % Check if there are any unexpected folders.
    AllDsFiles = dir(fullfile(Folder, '*')); % includes '.' and '..'
    AllDsFiles(strcmpi({AllDsFiles.name}, '.')) = [];
    AllDsFiles(strcmpi({AllDsFiles.name}, '..')) = [];
    if isDryRun
        % Ignore hz.ds that would have been removed above.
        AllDsFiles(strcmpi({AllDsFiles.name}, 'hz.ds')) = [];
        AllDsFiles(contains({AllDsFiles.folder}, [filesep 'hz.ds'])) = [];
    end
    if any([AllDsFiles.isdir])
        disp({AllDsFiles([AllDsFiles.isdir]).name});
        error('Unknown folders inside CTF datasets.');
    end

    % Delete other files
    if isempty(AllDsFiles)
        warning('No files found.');
        return;
    end
    for f = 1:numel(AllDsFiles)
        [~, ~, AllDsFiles(f).ext] = fileparts(AllDsFiles(f).name);
        % I don't recall what these number strings were about, maybe .nfs... files?
        if isempty(AllDsFiles(f).ext) && ~ismember(AllDsFiles(f).name(1), '1234567890I')
            % fprintf('%s\n', AllDsFiles(f).name);
            AllDsFiles(f).ext = AllDsFiles(f).name;
        elseif all(ismember(AllDsFiles(f).ext(2:end), '1234567890_-'))
            AllDsFiles(f).ext = '';
        end
    end
    [Types, iFirst, iType] = unique({AllDsFiles.ext});
    nTypes = numel(Types);
    Count = zeros(nTypes, 1);
    Size = zeros(nTypes, 2);
    for t = 1:nTypes
        iThisType = iType == t;
        Count(t) = sum(iThisType);
        if ~isempty([AllDsFiles(iThisType).bytes])
            Size(t, 1) = min([AllDsFiles(iThisType).bytes]);
            Size(t, 2) = max([AllDsFiles(iThisType).bytes]);
        else
            Size(t, :) = [-1, -1];
        end
    end
    % Display
    if isBids
        for t = 1:nTypes
            fprintf('%-12s  %4d  size: %10d - %10d bytes  ex:%s\n', Types{t}, Count(t), Size(t,:), ...
                fullfile(AllDsFiles(iFirst(t)).folder, AllDsFiles(iFirst(t)).name));
        end
    end
    % Keep: .res4, .meg4 (.1_meg4), .acq, .hc, .infods
    %       For events: MarkerFile.mrk, DigTrigChannelInfo.txt

    disp('------------------- Deleting unnecessary files. -------------------');
    % File types to delete, when smaller or equal to size in bytes.
    FileTypes = {...
        '.bak', inf; ... % "backup" when saving occurs
        '.xml', inf; ... % from some beta versions of acquisition software, containing duplicate information as others (res4, infods, etc)
        '.eeg', 1; ... % empty stub
        '.lock', 1; ... % empty flag leftover when acquisition did not end cleanly
        '.segments', 1; ... % empty stub
        'BadChannels', 1; ... % empty stub
        '.hist', inf; ... % for anonymization
        '.newds', inf; ... % for anonymization
        '.cfg', inf; ... % processing.cfg, for anonymization
        '.cls', 300; ... % empty stub has various sizes due to ds file name, this is approximation for max empty size.
        '.de', inf; ... % defaults.de, DataEditor settings
        'VirtualChannels', 1; ... % unsure if fully empty when "stub", but usually not there
        '.dsc', 1 ... % unsure if can be fully empty, but usually not there
        };

    nTypes = size(FileTypes, 1);

    for iT = 1:nTypes
        Type = FileTypes{iT, 1};
        MaxBytes = FileTypes{iT, 2};

        isThisType = strcmp({AllDsFiles.ext}, Type);
        ToDelete = AllDsFiles(isThisType);

        % if ~isAnySize
        %     [AllSizes, iFst, iToDel] = unique([ToDelete.bytes]);
        %     for s = 1:numel(AllSizes)
        %         iThisSize = iToDel == s;
        %         Count(s) = sum(iThisSize);
        %         fprintf('%10d  %4d  ex:%s\n', AllSizes(s), Count(s), ...
        %             fullfile(ToDelete(iFst(s)).folder, ToDelete(iFst(s)).name));
        %     end
        % end

        for f = 1:numel(ToDelete)
            File = fullfile(ToDelete(f).folder, ToDelete(f).name);
            if ~contains(File, Type)
                error('Incorrect file index! %d %s', f, File);
            end
            if ~isAnySize && (ToDelete(f).bytes > MaxBytes)
                fprintf('Skipping non-empty file %s\n', File);
                continue;
            end
            fprintf('Deleting (%dB) %s\n', ToDelete(f).bytes, File);
            if ~isDryRun
                delete(File);
            end
        end
    end
    fprintf('Done.\n');


    % Check for fake-only events at start of trials and delete the corresponding .mrk files.
    % Remove events.tsv if .mrk was deleted, e.g. all fake events 
    if ~isCheckEvents
        return;
    end
    disp('------------------- Verifying events. -------------------');
    % We rely on the BIDS events file here because it's easier to read than the marker file.
    if isBids
        EventsFiles = dir(fullfile(BidsFolder, 'sub-*', '**', '*events.tsv'));
    else
        EventsFiles = dir(replace(Folder, 'meg.ds', 'events.tsv'));
    end
    nFiles = numel(EventsFiles);

    for e = 1:nFiles
        File = fullfile(EventsFiles(e).folder, EventsFiles(e).name);
        MrkFile = replace(File, 'events.tsv', 'meg.ds/MarkerFile.mrk');
        Events = readtable(File, 'FileType', 'text', 'Delimiter', '\t');
        nE = numel(Events.sample);
        % Check if all "fake" events with time zero, at each trial
        nZE = sum(Events.sample == 0);
        fprintf('%d t=0 events; ', nZE);
        if nE > nZE
            fprintf('%d others; ', (nE - nZE));
        end
        % Check if .mrk exists
        if ~exist(MrkFile, 'file')
            isMrk = false;
            fprintf('no mrk; ');
        else
            isMrk = true;
        end
        % Delete
        if nE <= nZE || ~isMrk
            fprintf('Deleting evt %s\n', File);
            if ~isDryRun
                delete(File);
            end
            if isMrk
                fprintf('Deleting mrk %s\n', File);
                if ~isDryRun
                    delete(MrkFile);
                end
            end
        else
            fprintf('Skipping evt %s\n', File);
        end
    end
    fprintf('Done.\n');

end