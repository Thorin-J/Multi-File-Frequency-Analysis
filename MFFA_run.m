% Multi-File Frequency Analysis for bush-cricket songs
% reads all wave files in a given folder, extracts cool edit or avisoft cues and labels (only
% avisoft labels are currently used) delineating song parts to be analysed. Labeled sections have to
% contain pulse and group numbers. On the basis of this information, pulse durations, intervals,
% group durations and intervals are calculated. An FFT is performed for each labeled pulse/section
% and peak frequencies and amplitudes for the first three peaks are extracted, together with Q for 
% each peak and flatness, spread and entropy values.
% Recording temperature for each wave file is added from specified excel file. Data is saved as .mat
% and excel files.

clear
%% declare some variables
% specify path and name for xls-Table containing temperature data in work sheet "sheet_name"
temp_filename="Daten Tiere & Recordings.xlsx";
sheet_name='KlimaLoggPro';

start_freq=500; % high-pass or or lower band-pass filter frequency in Hz
Qs_=[-3]; % dB values for Q. Take Q -3 and -10 dB below max frequency peak
nfft=2048; %size of FFT in number of samples. Choose from '512', '1024', '2048', '4096' or '8192'
win_length=256; % window length in samples
ol=50; % overlap in percent

% select main directory and specify table/sheet containing temperature data
global path1
if exist(path1, 'var') || ischar(path1)
    path1=uigetdir(path1, 'Select directory containing wave files');
else
    path1=uigetdir(path, 'Select directory containing wave files');
end
file_list = dir(fullfile(path1, '*.wav'));

%catch empty directories and/or cancellations
if isempty(file_list)
    if path1==0
        return
    end
    h=warndlg('Directory does not contain any files of the chosen data format!', 'CreateMode', 'modal');
    waitfor(h)
    return
end

% call function to extract cues and labels from wave files and create data table
data_table=songdata_table_fun(file_list, temp_filename, sheet_name, path1);
% perform frequency analysis over all labeled sections in data_table
[data_table, ffts, fft_settings]=songdata_analysis_fun(data_table, start_freq, Qs_, nfft, win_length, ol, path1);
