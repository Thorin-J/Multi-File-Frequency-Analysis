function [cues, txt_labels, wav_info] = readWavCueChunks(filename)
% Extracts WAV cue marker information and label information as saved by Avisoft
%
% Outputs:
%   cues        - From 'cue ' chunk (IDs and raw start sample offsets), if available
%   cues.labels - From 'LIST' -> 'labl'/'lbl ' chunks (IDs and text names)
%   cues.length - From 'LIST' -> 'ltxt' chunks (IDs and sample lengths for cue markers)
%   txt_labels  - extra structure for data extracted from lbl chunks (e.g., from Avisoft)

wav_info=audioinfo(filename); 
fid = fopen(filename, 'r', 'l');
if fid == -1, error('Could not open file: %s', filename); end

% Initialize explicit separate output structures
cues = struct('id', {}, 'cue_start', {});
cue_labels = struct('id', {}, 'text', {});
cue_durations = struct('id', {}, 'cue_length', {});
txt_labels=struct([]);

try
    % Verify core RIFF header
    riff_tag = fread(fid, 4, '*char')';
    if ~strcmp(riff_tag, 'RIFF')
        fclose(fid); error('Not a valid RIFF file.');
    end
    fseek(fid, 12, 'bof');

    while ~feof(fid)
        curr_pos = ftell(fid);
        chunk_id = fread(fid, 4, '*char')';
        if length(chunk_id) < 4
            break
        end

        chunk_size = double(fread(fid, 1, 'uint32'));
        if isempty(chunk_size)
            break
        end

        % Clean up non-printable characters for display
        display_id = regexprep(chunk_id, '[^ -~]', '?');
        % display which chunks have been found
        fprintf('Found Chunk: "%s" | Size: %d bytes | File Position: %d\n', ...
            display_id, chunk_size, curr_pos);

        % extract data from 'cue ' chunk
        if strcmpi(chunk_id, 'cue ')
            num_cues = fread(fid, 1, 'uint32');
            for i = 1:num_cues
                c_id = fread(fid, 1, 'uint32');
                fseek(fid, 16, 'cof'); % Skip structural block offsets
                sample_offset = fread(fid, 1, 'uint32');

                cues(end+1).id = c_id; %#ok<AGROW>
                cues(end).cue_start = sample_offset;
            end

            % extract data from 'LIST' chunk (wraps sub-chunks like 'labl' and 'ltxt')
        elseif strcmpi(chunk_id, 'LIST')
            list_type = fread(fid, 4, '*char')';
            list_end = ftell(fid) + chunk_size - 4;

            while ftell(fid) < list_end
                sub_id = fread(fid, 4, '*char')';
                if length(sub_id) < 4, break; end
                sub_size = double(fread(fid, 1, 'uint32'));

                % Capture label strings inside the LIST structure
                if strcmpi(sub_id, 'labl') || strcmpi(sub_id, 'lbl ')
                    lbl_id = fread(fid, 1, 'uint32');
                    text_len = sub_size - 4;
                    lbl_text = fread(fid, text_len, '*char')';

                    cue_labels(end+1).id = lbl_id; %#ok<AGROW>
                    cue_labels(end).text = replace(strtrim(lbl_text), char(0), '');

                    % Capture explicit regions durations inside the LIST structure
                elseif strcmpi(sub_id, 'ltxt')
                    ltxt_id = fread(fid, 1, 'uint32');
                    sample_length = fread(fid, 1, 'uint32');

                    cue_durations(end+1).id = ltxt_id; %#ok<AGROW>
                    cue_durations(end).cue_length = sample_length;

                    fseek(fid, sub_size - 8, 'cof'); % Skip remaining metadata headers
                else
                    fseek(fid, sub_size + mod(sub_size, 2), 'cof');
                end
            end

            % extract from standalone 'LBL ' / 'LABL' chunks (fallback if outside 'LIST')
        elseif strcmpi(chunk_id, 'labl') || strcmpi(chunk_id, 'lbl ')
            lbl_id = fread(fid, 1, 'uint32');
            text_len = chunk_size - 4;
            lbl_text = fread(fid, text_len, '*char')';
            cue_labels(end+1).id = lbl_id; %#ok<AGROW>
            cue_labels(end).text = replace(strtrim(lbl_text), char(0), ''); % remove white space
        else
            % Use absolute positioning math to skip over unneeded chunks safely
            padded_size = chunk_size + mod(chunk_size, 2);
            fseek(fid, curr_pos + 8 + padded_size, 'bof');
        end

        % Enforce standard boundary alignment wrap
        padded_size = chunk_size + mod(chunk_size, 2);
        fseek(fid, curr_pos + 8 + padded_size, 'bof');
    end
    % if there are labels not belonging to cues (e.g. from Avisoft), save them as separate
    % cell arrays within a structure
    if numel(cue_labels)>numel(cues)
        [notcue_labels, idx]=setdiff([cue_labels.id], [cues.id]); % find labels that don't belong to any cues
        for i=1:length(notcue_labels)
            label_txt=cue_labels(idx(i)).text; % get text
            label_txt=strsplit(label_txt, {'\r', '\n'}, 'CollapseDelimiters', 1)'; % split by new line/return delimiter
            label_txt(cellfun('isempty', label_txt))=[]; % delete empty cells
            label_txt=cellfun(@(x) strsplit(x, {' ', ':', '\t'}), label_txt, 'UniformOutput', false); % split by any remaining delimiters
            txt_labels(i).(['id_', num2str(cue_labels(idx(i)).id)])=vertcat(label_txt{:}); % save in structure with id
        end
        % delete extra cue information from cue_labels and cue_durations
        cue_labels(idx) = [];
        
        % save all cue data in cues
        % add the field cue_durations.cue_length to structure cues
        for i = 1:numel(cues)
            cues(i).cue_length = cue_durations(i).cue_length;
            cues(i).labels = cue_labels(i).text;
        end
    end
catch ME
    fclose(fid); rethrow(ME);
end
fclose(fid);
end
