function BidsCleanupCtfMeg(BidsFolder, isDryRun, isMoveHz, isAnySize, isCheckEvents)
    % Remove empty or unnecessary files (e.g. hz.ds) from CTF MEG recordings in BIDS dataset.
    % This reduces the number of files and accelerates transfers.
    % isDryRun [true]: if set to true, will only display information and proposed actions. 
    %                  Set to false to delete files. Use with care!
    % isMoveHz [false]: if true, move hz.ds to sourcedata instead of deleting them.
    % isAnySize [false]: if true, file sizes are not checked and even non-empty files in the
    %                  "unnecessary" list are deleted.
    % isCheckEvents [true]: if true, look if .mrk file contains only "fake" events at time zero of
    %                  trials, in which case delete the .mrk file, and corresponding BIDS .evt file.

    % See Marc's notes (in MEG & Equipment section, .ds files page) for all possible files inside .ds.
    % For anonymisation, these files would already be deleted: .bak, .hist, .newds, processing.cfg.

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

    % Delete "head zeroing" recordings
    HzDs = dir(fullfile(BidsFolder, 'sub-*', '**', '*.ds', 'hz.ds*')); % last * to avoid listing contents
    for iHz = 1:numel(HzDs)
        File = fullfile(HzDs(iHz).folder, HzDs(iHz).name);
        if isMoveHz
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
                delete(File);
            end
        end
    end
    % Check if there are any unexpected folders.
    AllDsFiles = dir(fullfile(BidsFolder, 'sub-*', '**', '*.ds', '*')); % includes '.' and '..'
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
    for t = 1:nTypes
        fprintf('%-12s  %4d  size: %10d - %10d bytes  ex:%s\n', Types{t}, Count(t), Size(t,:), ...
            fullfile(AllDsFiles(iFirst(t)).folder, AllDsFiles(iFirst(t)).name));
    end
    % Keep: .res4, .meg4 (.1_meg4), .acq, .hc, .infods
    %       For events: MarkerFile.mrk, DigTrigChannelInfo.txt

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
        '.de', inf ... % defaults.de, DataEditor settings
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
    EventsFiles = dir(fullfile(BidsFolder, 'sub-*', '**', '*events.tsv'));
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