
# songdata_analysis_fun.m => Song Data Frequency Analysis

A MATLAB function for automated spectral analysis of animal song recordings.  
It reads audio segments defined in a table (output of `songdata_table_fun.m`), computes power‐spectrum features (FFT, bandwidth, Q-factors, spectral flatness/spread/entropy, peak frequencies/amplitudes), and exports the results to `.xlsx` and `.mat` files organized by species and individual.

---

## Features

- Reads WAV files and time‐segments from a `data_table` (output of `songdata_table_fun.m`)
- Applies high-pass or band-pass filtering
- Computes Welch power spectral estimate (`pwelch`) with user-defined FFT length, window, and overlap
- Extracts:
  - Bandwidth, mean/median frequency (`obw`, `meanfreq`, `medfreq`)
  - Spectral flatness (Wiener entropy)
  - Spectral spread (via `SpectralSpread.m`)
  - Spectral entropy
  - Top 3 spectral peaks (frequencies, amplitudes)
  - Q-factors at −3 dB and (optionally) −10 dB
- Appends all metrics back into the original `data_table`
- Saves per‐species Excel workbooks (one sheet per individual) and a corresponding `.mat` file
- Optional Excel COM automation for number‐format tuning and styling

---

## Usage

```matlab
% Inputs:
%   data_table – MATLAB table with columns: filename, start_time, end_time, …
%   start_freq – high-pass cutoff (Hz)
%   Qs         – vector of dB levels for Q-factor (e.g. [-3, -10])
%   nfft       – FFT length (512, 1024, 2048, …)
%   win_length – window size (samples)
%   ol         – overlap (percent, e.g. 50)
%   path1      – folder containing WAV files (and where outputs are saved)

% Example
[data_table_out, ffts, fft_settings] = songdata_analysis_fun( ...
    data_table,       ...
    1000,             ...  % start_freq = 1 kHz
    [-3, -10],        ...  % Q-factors at −3 dB and −10 dB
    2048,             ...  % nfft
    512,              ...  % window length
    50,               ...  % 50% overlap
    '/path/to/wavdir' ...  % base directory
);
```

- **data_table_out**: input table augmented with spectral metrics  
- **ffts**: cell array of structs containing full FFT results for each segment  
- **fft_settings**: struct summarizing the analysis parameters  

Upon completion, the function writes:
- `*_songdata_fft.xlsx` (one workbook per species, sheets per individual)
- `*_songdata_fft.mat` (containing `data_table`, `ffts`, and `fft_settings`)