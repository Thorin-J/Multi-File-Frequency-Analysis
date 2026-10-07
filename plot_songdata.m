% Take data from output of MFFA_run and plot selected pulses or groups specified by table entry
% indices
clear
% load data from mat file
global path1
if exist('path1', 'var') && ischar(path1)
    [filename, path1]=uigetfile(fullfile(path1, '.mat'), 'Select .mat file containing song data');
else
    [filename, path1]=uigetfile('.mat', 'Select .mat file containing song data');
end

load(fullfile(path1, filename));

% take the biggest table in the workspace and rename it to data_table (necessary when designation of
% data_table changes in other scripts)
workspaceVariables=whos;
tableVariables=workspaceVariables(strcmp({workspaceVariables.class}, 'table'));
[~, idx]=max([tableVariables.bytes]);
data_table=eval(tableVariables(idx).name);
clear(tableVariables(idx).name);

% check if first file in data_table can be found in path1, otherwise prompt user to specify
% different directory for files
fname_temp=data_table.filename(1);
if ~exist(fullfile(path1, fname_temp), "file")
    h=warndlg(sprintf(['Sound files do not exist in current directory!\n' ...
        'Please specify directory containing .wav files for %s.'], animal_id));
    waitfor(h)
    file_path=uigetdir(path1, 'Directory containing .wav files');
    %catch empty directories and/or cancellations
    file_list=dir(fullfile(file_path, '*.wav'));
    if isempty(file_list)
        if path1==0
            return
        end
        h=warndlg('Directory does not contain any .wav files!', 'CreateMode', 'modal');
        waitfor(h)
        return
    end
else
    file_path=path1;
end

%% get individual animals in .mat file and ask which one is to be used
% get unique animal IDs from filenames
pat='^([^_]+_[^_]+_[^_]+)'; % match three groups of non-underscores separated by _
[ind_files]=unique(data_table.filename);
tok=regexp(ind_files, pat, 'tokens'); % extract animals names from file names
animal_ids=[tok{:}]; % animal IDs
animal_ids=cellfun(@char, [animal_ids{:}], 'UniformOutput',false);
animal_ids=unique(animal_ids); % unique animal identifiers
% select individual and restrict data
choice=listdlg('PromptString', 'Select animal to analyse:', 'SelectionMode', 'single', ...
    'ListString', animal_ids);
sel_id=animal_ids{choice};

%% ask user if they want to analyse individual pulses or complete group of pulses
choice=questdlg('Do you want to analyze individual pulses or a complete group of pulses?', ...
    'Analysis Choice', 'Individual Pulses', 'Complete Groups', 'Individual Pulses');
if strcmp(choice, 'Individual Pulses')
    p_temp=inputdlg('Specify Excel row number(s) of pulse(s) to analyse', 'Input row numbers', 1, "2, 5-10")
    % convert input strings to numeric arrays; input separated by ',' are individual pulses, input
    % separated by '-' are arrays from x to y
    p_temp=split(p_temp, ',');
    p_temp=strip(p_temp, 'both', ' ');
    pulses={};
    for i=1:length(p_temp)
        if contains(p_temp{i}, '-')
            range=cellfun(@str2num, split(p_temp{i}, '-'));
            pulses{i}=range(1):range(2);
        else
            pulses{i}=str2double(p_temp{i});
        end
    end
    pulses=[pulses{:}];
else
    g_temp=inputdlg('Specify Excel starting row number(s) of group(s) to analyse', 'Input row numbers', 1, "5, 14, 18-26")
    g_temp=split(g_temp, ',');
    g_temp=strip(g_temp, 'both', ' ');
    groups={};
    for i=1:length(g_temp)
        if contains(g_temp{i}, '-')
            range=cellfun(@str2num, split(g_temp{i}, '-'));
            groups{i}=range(1):range(2);
        else
            groups{i}=str2double(g_temp{i});
        end
    end
    groups=[groups{:}];
end

%% Analyse individual pulses
r_offset=find(startsWith(data_table.filename, sel_id), 1, "first");
if strcmp(choice, 'Individual Pulses')
    for i=1:length(pulses)
        p_idx=pulses(i)+r_offset-2; % -1 to account for header row in Excel
        fs=ffts{p_idx}.fs; % sampling rate
        start_idx=round(data_table.start_time(p_idx)*fs);
        stop_idx=round(data_table.end_time(p_idx)*fs);
        % amplitude data
        amp_data=audioread(fullfile(file_path, data_table.filename(p_idx)), [start_idx stop_idx]);

        % plot
        fig=figure;
        tl=tiledlayout('TileSpacing', 'compact', 'Padding', 'compact');
        title(tl, sprintf('%s - Pulse Nr. %d', data_table.filename(p_idx), data_table.pulse_n(p_idx)),...
            'Interpreter', 'none');
        % plot amp_data
        nexttile
        plot((1:length(amp_data))/fs*1000, amp_data./max(abs(amp_data)));
        box off
        title('Amplitude Data');
        xlabel('Time (ms)');
        ylabel('Rel. Amplitude');

        % plot spectrum and add points for peak frequencies
        fft_data=pow2db(ffts{p_idx}.pow);
        freqs=ffts{p_idx}.freqs./1000;
        peak_freqs=ffts{p_idx}.peak_freqs./1000;
        peak_amps=pow2db(ffts{p_idx}.peak_amps);
        nexttile
        plot(freqs, fft_data);
        hold on
        plot(peak_freqs, peak_amps, 'o')
        box off
        title(sprintf('Power Spectrum - Peak at %.1f kHz',...
            peak_freqs(find(max(peak_amps)))))
        xlabel('Frequency (kHz)');
        ylabel('Power [dB]');
    end
else % plot whole groups
    for i=1:length(groups)
        g_idx=groups(i)+r_offset-2; % -1 to account for header row in Excel
        if data_table.group_pn(g_idx)==1 % check if given row is group start
            fs=ffts{g_idx}.fs; % sampling rate
            start_idx=round(data_table.start_time(g_idx)*fs); % start of group
            % find end of group
            stop_idx=find(data_table.group_pn(g_idx+1:end)==1, 1, "first")+g_idx-1;
            if isempty(stop_idx) % because g_idx is last group
                stop_idx=round(data_table.end_time(end)*fs);
            else
                stop_idx=round(data_table.end_time(stop_idx)*fs);
            end
            % amplitude data
            amp_data=audioread(fullfile(file_path, data_table.filename(g_idx)), [start_idx stop_idx]);
        else % g_idx is not start or group
            continue
        end

        % perform signal analysis over group
        % normalise amp_data
        amp_data=amp_data/max(abs(amp_data));
        % filter
        [b,a]=butter(6, fft_settings.start_freq/(fs/2), 'high'); % highpass filter
        amp_data=filter(b, a, amp_data);
        % spectrum with one window of length(signal) and ol overlap, nfft
        % specified above.
        [pow, freqs] = pwelch(amp_data, window('hanning', fft_settings.win_length),...
            round(fft_settings.win_length*fft_settings.ol/100), fft_settings.nfft, fs, 'power');

        % plot
        fig=figure;
        tl=tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(tl, sprintf('%s - Group Nr. %d', data_table.filename(g_idx), data_table.group_n(g_idx)),...
            'Interpreter', 'none');
        % plot amp_data
        ax1=nexttile;
        plot((1:length(amp_data))/fs*1000, amp_data./max(abs(amp_data)));
        box off
        title('Amplitude Data');
        xlabel('Time (ms)');
        xlim([0, length(amp_data)/fs*1000])
        ylabel('Rel. Amplitude');

        % plot spectrogram
        ax2=nexttile;
        [S, f, t]=spectrogram(amp_data, window('hanning', fft_settings.win_length), ...
            round(fft_settings.win_length*fft_settings.ol/100), ...
            fft_settings.nfft, fs, 'yaxis', 'psd');
        Sdb=mag2db(abs(S)+eps);
        pcolor(ax2, t*1000, f/1000, Sdb);
        shading(ax2, 'interp');
        axis(ax2, 'xy');
        % spectrogram(amp_data, window('hanning', fft_settings.win_length), ...
        %     round(fft_settings.win_length*fft_settings.ol/100), ...
        %     fft_settings.nfft, fs, 'yaxis', 'psd');
        linkaxes([ax1 ax2], 'x');
        title('Spectrogram');
        % colorbar;

        % plot spectrum
        nexttile
        plot(freqs, pow2db(pow));
        peak_loc=pickpeaks(pow, 1);
        hold on
        plot(freqs(peak_loc), pow2db(pow(peak_loc)), 'o')
        box off
        xlim('tight')
        title(sprintf('Power Spectrum - Peak at %.1f kHz',...
            freqs(peak_loc)/1000))
        xlabel('Frequency (kHz)');
        ylabel('Power [dB]');

    end
end

