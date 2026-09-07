function [data_table, ffts, fft_settings]=songdata_analysis_fun(data_table, start_freq, Qs_, nfft, win_length, ol, path1)
% Song data frequency analysis
% For use with animal songs analysed with AviSoft. Uses data_table output from songdata_table_fun.m
% start_freq    = high-pass or or lower band-pass filter frequency in Hz
% Qs_           = dB values for Q. e.g. [-3, -10] dB below max frequency peak
% nfft          = size of FFT in number of samples. Choose from 512, 1024, 2048, 4096 or 8192
% win_length    = window length in samples; e.g. 256 or 512
% ol            = FFT overlap in percent

% Determine the number of unique file names to be analysed
[filenames, idx_r, idx_n]=unique(data_table.filename);
numFiles = length(filenames);

% open each wave file, read in the chunks from startTime to endTime and perform a signal analysis
for i = 1:numFiles
    % Construct the full file path
    wav_info=audioinfo(fullfile(path1, filenames{i}));
    fs(i)=wav_info.SampleRate; % sample rate of sound file
    FFT.fs=fs(i);
    % create start and stop samples from table data for each file
    s_start{i}=round(data_table.start_time(idx_n==i).*fs(i));
    s_stop{i}=round(data_table.end_time(idx_n==i).*fs(i));


    for j = 1:length(s_start{i})
        % Read the audio data from the specified time range
        [amp_data, ~]=audioread(fullfile(path1, filenames{i}), [s_start{i}(j), s_stop{i}(j)]);

        % Perform signal analysis
        % normalise amp_data
        amp_data=amp_data/max(abs(amp_data));
        % filter
        [b,a]=butter(6, start_freq/(fs(i)/2), 'high'); % highpass filter
        amp_data=filter(b, a, amp_data);
        % spectrogram with one window of length(signal) and no overlap, nfft
        % specified above.
        [pow, freqs] = pwelch(amp_data, window('hanning', win_length), round(win_length*ol/100), nfft, fs(i), 'power');
        FFT.pow=pow; %power spectrum estimate
        FFT.mag=sqrt(pow); %magnitude
        FFT.freqs=freqs;

        % bandwidth and mean/median frequency of power spectrum
        [FFT.bw, FFT.flo, FFT.fhi]=obw(FFT.pow, FFT.freqs, [], 90);
        FFT.med_freq=medfreq(FFT.pow,FFT.freqs);
        FFT.mean_freq=meanfreq(FFT.pow, FFT.freqs);

        % calculate spectral flatness (Wiener Entropy)
        maglog=log(FFT.mag+1e-20);
        FFT.flatness=exp(mean(maglog,1))./(mean(FFT.mag,1));

        % calculate spectral spread (function SpectralSpread must be in same dir)
        FFT.spread=SpectralSpread(FFT.mag, fs(i)); % results are in Hz

        % calculate spectral entropy
        mag_norm=abs(FFT.mag)./sum(abs(FFT.mag)); % normalise spectrum to get probability mass function
        FFT.entropy=-sum(mag_norm.*log2(mag_norm+eps));

        % get 3 highest peaks of frequency spectrogram and sort by ascending frequency
        [freq_locs, ~]=pickpeaks(abs(FFT.pow),3); % indices of peaks
        freq_pks=FFT.pow(freq_locs); % amplitude of peaks
        peak_freqs=freqs(freq_locs); % frequency of peaks
        if numel(freq_pks)>1
            [peak_freqs, idx]=sort(peak_freqs, 'ascend');
            freq_locs=freq_locs(idx);
            freq_pks=freq_pks(idx);
        end
        FFT.peak_locs=freq_locs;
        FFT.peak_amps=freq_pks;
        FFT.peak_freqs=peak_freqs;

        % calculate Qs for highest peaks in power spectrum
        % Q-3dB
        bandwidth=[];
        peak_freq=[];
        bandstart=[];
        bandstop=[];
        amps=pow; % power spectral density estimate from above
        amp_db=[];
        p=1;
        while p<=length(freq_pks)
            idx=freq_locs(p);
            max_amp=freq_pks(p);
            peak_freq(p)=freqs(idx);
            amp_db(p)=max_amp*10^(Qs_(1)/10); % equals a decrease in amplitude by xdB
            % get frequencies to the left and to the right of peak
            % catch occasions where a peak is close to the start, resulting in find() to return a empty vector
            % => set start of peak to 1
            temp=find(abs(amps(1:idx))<=amp_db(p),1,'last');
            if isempty(temp)
                starts(p)=1;
            else
                starts(p)=temp;
            end
            %         starts(p)=find(abs(amps(1:idx))<=amp_db(p),1,'last');
            ends(p)=find(abs(amps(idx:end))<=amp_db(p),1,'first')+idx-1;
            % interpolate frequencies at -xdB at the left and right side of peak
            bandwidth1=interp1(abs(amps(starts(p):idx)), freqs(starts(p):idx),...
                amp_db(p));
            bandwidth2=interp1(abs(amps(idx:ends(p))), freqs(idx:ends(p)),...
                amp_db(p));
            bandstart(p)=bandwidth1; % start frequencies of bandwidths
            bandstop(p)=bandwidth2; % stop frequencies
            bandwidth(p)=bandwidth2-bandwidth1; % bandwidth at -xdB
            Q1(p)=peak_freq(p)/bandwidth(p);
            p=p+1;
        end
        Q3.amps=amp_db;
        Q3.peak_starts=bandstart;
        Q3.peak_stops=bandstop;
        Q3.bandwidth=bandwidth;
        Q3.Qs=Q1;
        FFT.Q3=Q3;
        %Q2
        if numel(Qs_)==2
            bandwidth=[];
            peak_freq=[];
            bandstart=[];
            bandstop=[];
            amp_db=[];
            p=1;
            while p<=length(freq_pks)
                idx=freq_locs(p);
                max_amp=freq_pks(p);
                peak_freq(p)=freqs(idx);
                amp_db(p)=max_amp*10^(Qs_(2)/10); % equals a decrease in amplitude by ydB (10*log because it's power, not magnitude)
                % get frequencies to the left and to the right of peak
                % catch occasions where a peak is close to the start, resulting in find() to return an empty vector
                % => set start of peak to 1
                temp=find(abs(amps(1:idx))<=amp_db(p),1,'last');
                if isempty(temp)
                    starts(p)=1;
                else
                    starts(p)=temp;
                end
                ends(p)=find(abs(amps(idx:end))<=amp_db(p),1,'first')+idx-1;
                % interpolate frequencies at -xdB at the left and right side of peak
                bandwidth1=interp1(abs(amps(starts(p):idx)), freqs(starts(p):idx),...
                    amp_db(p));
                bandwidth2=interp1(abs(amps(idx:ends(p))), freqs(idx:ends(p)),...
                    amp_db(p));
                bandstart(p)=bandwidth1; % start frequencies of bandwidths
                bandstop(p)=bandwidth2; % stop frequencies
                bandwidth(p)=bandwidth2-bandwidth1; % bandwidth at -ydB
                Q2(p)=peak_freq(p)/bandwidth(p);
                p=p+1;
            end
            Q10.amps=amp_db;
            Q10.peak_starts=bandstart;
            Q10.peak_stops=bandstop;
            Q10.bandwidth=bandwidth;
            Q10.Qs=Q2;
            FFT.Q10=Q10;
        end
        % incl. table idx
        FFT.data_table_idx=find(idx_n==i, 1)+j-1;
        % store data
        ffts{i,j}=FFT;
    end

end

%% add FFT data (peak frequencies, Qs, etc) to original table
% get non-empty cells in ffts and linearise cell array
ffts_lin=ffts'; % transpose cell matrix because the command below goes through columns first
ffts_lin(cellfun(@isempty,ffts_lin))=[]; % a linear cell array with entries in the same order as in data_table

% in data_table, add peak frequencies, amplitudes and Qs, flatness, spread and entropy from ffts
for i = 1:length(ffts_lin)
    data_table.peak_freq1(i) = ffts_lin{i}.peak_freqs(1); % peak freq 1
    data_table.peak_amp1(i) = pow2db(ffts_lin{i}.peak_amps(1)); % peak amp 1 in dB power
    data_table.peak_q1(i) = ffts_lin{i}.Q3.Qs(1); % peak Q3
    data_table.peak_freq2(i) = ffts_lin{i}.peak_freqs(2);
    data_table.peak_amp2(i) = pow2db(ffts_lin{i}.peak_amps(2));
    data_table.peak_q2(i) = ffts_lin{i}.Q3.Qs(2);
    data_table.peak_freq3(i) = ffts_lin{i}.peak_freqs(3);
    data_table.peak_amp3(i) = pow2db(ffts_lin{i}.peak_amps(3));
    data_table.peak_q3(i) = ffts_lin{i}.Q3.Qs(3);
    data_table.flatness(i) = ffts_lin{i}.flatness; % flatness
    data_table.spread(i) = ffts_lin{i}.spread; % spread
    data_table.entropy(i) = ffts_lin{i}.entropy; % entropy
end

%% save data as new xlsx table and mat file
% get animal id
pat='^([^_]+_[^_]+_[^_]+)'; % match three groups of non-underscores separated by _
tok=regexp(data_table.filename(1), pat, 'tokens');
animal_id=tok{1}{1};

save_name = fullfile(path1, [animal_id '_songdata_fft.xlsx']);
% check if save name already exists and ask if file should be overwritten
if isfile(save_name)
    choice = questdlg('.xlsx file already exists. Overwrite?', 'File Exists', 'Yes', 'No', 'No');
    if strcmp(choice, 'No')
        [new_name, new_path]=uiputfile('*.xlsx', 'Save as');
        writetable(data_table, fullfile(new_path, new_name), 'Sheet', strcat(animal_id, '_FFT'));
    else
        writetable(data_table, save_name, 'Sheet', strcat(animal_id, '_FFT'));
    end
else
    writetable(data_table, save_name, 'Sheet', strcat(animal_id, '_FFT'));
end

mat_save_name=[save_name(1:end-4) 'mat'];
ffts=ffts_lin; % rename ffts_lin for saving
fft_settings=struct('start_freq', start_freq, 'nfft', nfft, 'win_length', win_length, 'ol', ol);
% check if save name already exists and ask if file should be overwritten
if isfile(mat_save_name)
    choice = questdlg('.mat file already exists. Overwrite?', 'File Exists', 'Yes', 'No', 'No');
    if strcmp(choice, 'No')
        [new_name, new_path]=uiputfile('*.mat', 'Save as');
        save(fullfile(new_path, new_name), 'data_table', 'ffts', 'fft_settings', '-mat');
    else
        save(mat_save_name, 'data_table', 'ffts', 'fft_settings', '-mat')
    end
else
    save(mat_save_name, 'data_table', 'ffts', 'fft_settings', '-mat')
end

%% once saved, format some columns and rows for better readability of xlsx table
% determine OS locale
% Get language code (e.g., 'de' or 'en')
lang=char(java.util.Locale.getDefault().getLanguage());
% Get country code (e.g., 'DE' or 'US')
country=char(java.util.Locale.getDefault().getCountry());

% open Excel via COM
excel=actxserver('Excel.Application');
workbook=excel.Workbooks.Open(save_name);
sheet=workbook.Sheets.Item(1);
if strcmp(lang, 'de')
    disp('System is German. Customizing code for German locale...');
    sheet.Columns.Item('B').NumberFormat='0,000'; % number, 3 decimals
    sheet.Columns.Item('C').NumberFormat='0,000';
    sheet.Columns.Item('G').NumberFormat='0,0000';
    sheet.Columns.Item('H').NumberFormat='0,0000';
    sheet.Columns.Item('I').NumberFormat='0,000';
    sheet.Columns.Item('J').NumberFormat='0,000';
    sheet.Columns.Item('M').NumberFormat='0,00';
    sheet.Columns.Item('N').NumberFormat='0,00';
    sheet.Columns.Item('P').NumberFormat='0,00';
    sheet.Columns.Item('Q').NumberFormat='0,00';
    sheet.Columns.Item('S').NumberFormat='0,00';
    sheet.Columns.Item('T').NumberFormat='0,00';
    sheet.Columns.Item('U').NumberFormat='0,000';
    sheet.Columns.Item('V').NumberFormat='0';
    sheet.Columns.Item('W').NumberFormat='0,00';
else
    disp('System is US/Global. Using standard parameters...');
    sheet.Columns.Item('B').NumberFormat='0.000'; % number, 3 decimals
    sheet.Columns.Item('C').NumberFormat='0.000';
    sheet.Columns.Item('G').NumberFormat='0.0000';
    sheet.Columns.Item('H').NumberFormat='0.0000';
    sheet.Columns.Item('I').NumberFormat='0.000';
    sheet.Columns.Item('J').NumberFormat='0.000';
    sheet.Columns.Item('M').NumberFormat='0.00';
    sheet.Columns.Item('N').NumberFormat='0.00';
    sheet.Columns.Item('P').NumberFormat='0.00';
    sheet.Columns.Item('Q').NumberFormat='0.00';
    sheet.Columns.Item('S').NumberFormat='0.00';
    sheet.Columns.Item('T').NumberFormat='0.00';
    sheet.Columns.Item('U').NumberFormat='0.000';
    sheet.Columns.Item('V').NumberFormat='0';
    sheet.Columns.Item('W').NumberFormat='0.00';
end
% apply other formatting
sheet.Columns.Item('A').NumberFormat='@'; % text
sheet.Rows.Item(1).Font.Bold = true; % first row in bold
% save & clean up
workbook.Save;
workbook.Close(false);
excel.Quit;
excel.delete;