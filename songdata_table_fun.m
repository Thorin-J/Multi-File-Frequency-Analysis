function [data_table]=songdata_table_fun(file_list, temp_filename, sheet_name, path1)
% Read Avisoft label information from all wave files in a given directory and collate data in a
% table
% Avisoft labels are assumed to contain label start and end times, pulse and group numbers
% Temperature data is read from given sheet in specified Excel file

%% cycle through each wave-file and extract label data
var_names={'start_time', 'end_time', 'pulse_n', 'group_n', 'group_pn', 'filename'};
var_types={'double', 'double', 'double', 'double', 'double', 'string'};
data_table=table('size', [0, length(var_names)], 'VariableNames', var_names, 'VariableTypes', var_types);

for i=1:length(file_list)
    filename=fullfile(file_list(i).folder, file_list(i).name);
    [cues, labels, wav_info]=readWavCueChunks(filename);
    if isempty(labels)
        continue
    end

    f_names=fieldnames(labels);
    % for now assuming that each wave file only contains one label id entry, not several and
    % that the last column contains unnecessary type string
    temp_labels=labels.(f_names{1})(:,1:end-1);
    % convert all strings in temp_labels to double
    temp_labels=str2double(temp_labels);
    % and the pulse and group numbers to integers
    temp_labels(:, 3:5) = uint16(temp_labels(:, 3:5));

    temp_table=array2table(temp_labels,...
        'VariableNames', {'start_time', 'end_time', 'pulse_n', 'group_n', 'group_pn'});
    temp_table.filename=repmat(file_list(i).name, size(temp_labels, 1), 1);
    % add contents of temp_table to data_table
    data_table=[data_table; temp_table];
end

%% for each wave file, calculate pulse durations, intervals, group durations and group intervals
[ind_files, idx_r, idx_n]=unique(data_table.filename);
for i=1:size(ind_files, 1)
    p_dur=data_table.end_time(idx_n==i)-data_table.start_time(idx_n==i); % pulse durations
    s_time=data_table.start_time(idx_n==i);
    e_time=data_table.end_time(idx_n==i);
    p_int=s_time(2:end)-e_time(1:end-1); % pulse intervals
    p_int=[0; p_int];

    % group durations and group pulse rates
    group_n=data_table.group_n(idx_n==i);
    group_pn=data_table.group_pn(idx_n==i);
    g_dur=zeros(max(group_n),1);
    g_pr=zeros(max(group_n),1);
    for j=1:max(group_n)
        g_dur(j)=e_time(find(group_n==j, 1, 'last'))-s_time(find(group_n==j, 1, 'first'));
        g_pr(j)=max(group_pn(group_n==j))/g_dur(j);
    end

    % group intervals (from the end of one group to the beginning of the next group)
    g_int=zeros(max(group_n)-1, 1); % initialize group intervals
    for j=1:max(group_n)-1
        g_int(j)=s_time(find(group_n==j+1, 1, 'first'))-e_time(find(group_n==j, 1, 'last'));
    end
    g_int=[0; g_int];

    % insert into data_table
    data_table.pulse_dur(idx_n==i) = p_dur; % pulse durations
    data_table.pulse_int(idx_n==i) = p_int; % pulse intervals
    % each group starts at group_pn==1
    data_table.group_dur(find(idx_n==i & data_table.group_pn==1))=g_dur; % group durations
    data_table.group_int(find(idx_n==i & data_table.group_pn==1))=g_int; % group intervals
end

%% include temperatures from "Daten Tiere & Recordings.xlsx", sheet "KlimaLoggPro"
t_data=readtable(temp_filename, 'Sheet', sheet_name);
t_data=renamevars(t_data, ["Var1", "Var2", "Var3"], ["Date", "temp", "RH"]);
t_data.Var4=[];

% extract date and time from filenames and match with entries in t_data
% Extract date from filenames and match with temperature data
datePattern = '\d{2}\d{2}\d{2}'; % Assuming filenames contain dates in DDMMYY format
for i = 1:length(ind_files)
    fileDate = cell2mat(regexp(ind_files{i}, datePattern, 'match'));
    fileTime=ind_files{i}(end-7:end-4);
    if ~isempty(fileDate)
        % Convert to datetime for matching
        fileDate = datetime([fileDate, fileTime], 'InputFormat', 'ddMMyyHHmm');
        % Find matching temperature data (with a tolerance of 7.5 minutes
        matchingRow=datefind(fileDate, t_data.Date, 1/24/8);
        if any(matchingRow)
            data_table.temp(idx_n==i)=t_data.temp(matchingRow);
            % data_table.RH(idx_n==i)=t_data.RH(matchingRow);
        else
            error('No matching date and time found in temperature log! Update "KlimaLoggPro" in "Daten Tiere & Recordings.xlsx"')
        end
    end
end

%% replace 0 with NaN for group_int, pulse_int and group_dur
data_table.group_int(data_table.group_int==0)=NaN;
data_table.pulse_int(data_table.pulse_int==0)=NaN;
data_table.group_dur(data_table.group_dur==0)=NaN;
% move filename variable to beginning of table
data_table=movevars(data_table, "filename", Before="start_time");

%% save data
% get animal identifier(s) and separate data into xlsx-files (one file for each species, with
% individual sheets for individuals
pat='^([^_]+_[^_]+_[^_]+)'; % match three groups of non-underscores separated by _
tok=regexp(ind_files, pat, 'tokens'); % extract animals names from file names
animal_ids=[tok{:}]; % animal IDs
animal_ids=cellfun(@char, [animal_ids{:}], 'UniformOutput',false);
animal_ids=unique(animal_ids); % unique animal identifiers

pat2='^([^_]+_[^_]+)';
spec_ids=regexp(ind_files, pat2, 'tokens');
spec_ids=cellfun(@char, [spec_ids{:}], 'UniformOutput',false);
spec_ids=unique(spec_ids); % unique species identifiers

temp_data_table=data_table; % stupid workaround to save species table as "data_table" in each .mat file
for i=1:length(spec_ids)
    spec_name=spec_ids{i};
    mat_savename=fullfile(path1, strcat(spec_name, '_songdata.mat'));
    xls_savename=fullfile(path1, strcat(spec_name, '_songdata.xlsx'));
    % prepare data to be saved for current species
    spec_mask=startsWith(data_table.filename, spec_name);
    species_table=data_table(spec_mask, :);
    data_table=species_table;
    % save mat file
    save(mat_savename, 'data_table', 'labels', 'wav_info');
    data_table=temp_data_table; % recreate original data_table

    % get animal ids for the current species and save each animal per species in a separate
    % .xlsx worksheet
    temp_ids=find(startsWith(string(animal_ids), spec_name));
    for j=1:length(temp_ids)
        id_mask=startsWith(species_table.filename, animal_ids{temp_ids(j)});
        writetable(species_table(id_mask, :), xls_savename, 'Sheet', animal_ids{temp_ids(j)});
    end
end
end