# Multi-File Frequency Analysis (MFFA)

MATLAB tools for automated analysis of acoustic recordings containing annotated insect songs.

The scripts process multiple WAV recordings in batch mode, extract temporal and spectral song parameters from annotated pulse labels (done using Avisoft), combines the results with collected temperature data, and exports the resulting datasets for further statistical analysis.

## Features

- Batch processing of multiple WAV files.
- Direct import of annotation labels from Avisoft-generated WAV cue chunks.
- Automatic extraction of:
  - Pulse durations
  - Pulse intervals
  - Group durations
  - Group intervals
  - Pulse rates
- FFT-based spectral analysis of individual song elements.
- Calculation of:
  - Peak frequency
  - Relative peak amplitude
  - Q-value
  - Wiener entropy (spectral flatness)
  - Spectral entropy
  - Spectral spread
- Automatic matching of recordings with environmental temperature data.
- Export of processed datasets to:
  - MATLAB `.mat` files
  - Excel `.xlsx` workbooks
- Interactive visualization of pulses and pulse groups.

## Workflow

```text
Annotated WAV files
          |
          v
songdata_table_fun
          |
          v
Temporal song parameters
 + temperature matching
          |
          v
songdata_analysis_fun
          |
          v
Spectral measurements
          |
          v
Species-specific MAT files
Species-specific Excel tables
          |
          v
plot_songdata
```

## Repository Contents

### `MFFA_run.m`

Main analysis script.

This script:

1. Selects the directory containing WAV recordings.
2. Reads recording annotations and metadata.
3. Imports temperature records from an Excel file.
4. Builds a master data table.
5. Performs spectral analyses on all labelled song elements.
6. Saves processed results.

Typical execution starts here.

#### Declare Variables in MFFA_run.m
For example

```matlab
% specify path and name for xls-Table containing temperature data in work sheet "sheet_name"
temp_filename="Temperature_database.xlsx";
sheet_name='Temperature_logs';

start_freq=500; % high-pass or or lower band-pass filter frequency in Hz
Qs_=[-3];       % dB values for Q. Take Q -3 dB below max frequency peak
nfft=2048;      % size of FFT in number of samples. Choose from '512', '1024', '2048', '4096' or '8192'
win_length=256; % window length in samples
ol=50;          % overlap in percent
```
---

### `songdata_table_fun.m`

Creates the main song-data table from annotated recordings.

Functions include:

- Reading WAV cue chunks and labels.
- Extracting:
  - label start times
  - label end times
  - pulse numbers
  - group numbers
  - pulse position within groups
- Calculating:
  - pulse duration
  - pulse interval
  - group duration
  - group interval
  - pulse rate
- Matching recording times to environmental temperature logs.
- Separating datasets by species and individual.
- Writing species-specific Excel workbooks and MATLAB files.

### `songdata_analysis_fun.m`

Performs spectral analyses for each labelled song element.

For every pulse (or group):

- Extracts the corresponding waveform segment.
- Applies FFT analysis.
- Calculates:
  - dominant frequency
  - relative peak amplitude
  - Q-value
  - Wiener entropy
  - spectral entropy
  - spectral spread
- Stores spectral measurements within the data table.

### `plot_songdata.m`

Visualization utility.

Allows inspection of:

- Individual pulses
- Pulse groups
- Corresponding waveform segments
- Power spectra

Useful for validating annotations and analysis results.

## Input Requirements

### Audio files

- Format: WAV
- Recordings must contain embedded annotation labels.
- Labels are expected to include:

| Variable | Description |
|-----------|-------------|
| start_time | Start of song element |
| end_time | End of song element |
| pulse_n | Pulse number |
| group_n | Group number |

### Temperature log

An Excel workbook containing climate measurements.

Expected columns:

| Column | Description |
|---------|-------------|
| Date | Time stamp |
| temp | Temperature |
| RH | Relative humidity |

Recordings are matched to temperature records using timestamps embedded in filenames.

## Filename Convention

The software assumes that filenames contain:

1. Species identifier
2. Individual identifier
3. Recording timestamp

Species and individual IDs are extracted from underscore-separated filename fields.

Examples:

```text
P_apt_01_290626_1430.wav -> Pholidoptera aptera ind. 1, recording from 29.06.2026, 14:30
or
P_apt_01_05_290626_1430.wav -> Pholidoptera aptera ind. 1, recording nr. 5, from 29.06.2026, 14:30
```

The exact naming convention should remain consistent across all recordings within a dataset.

## Output

### MATLAB files

For each species:

```text
<species>_songdata.mat
```

Contains:

- processed data table
- label information
- WAV metadata

### Excel files

For each species:

```text
<species>_songdata.xlsx
```

Each individual is written to a separate worksheet.

### Stored Parameters

The final dataset may include:

- Filename
- Recording temperature
- Pulse number
- Group number
- Pulse duration
- Pulse interval
- Group duration
- Group interval
- Group pulse rate
- Peak frequency
- Peak amplitude
- Q-value
- Wiener entropy
- Spectral entropy
- Spectral spread

## MATLAB Requirements

Tested with MATLAB R2026a using the following toolboxes:
- Signal Processing Toolbox
- Financial Toolbox (function "datefind")

Additional helper functions required by the project include:

- `FeatureSpectralCentroid.m`
- `pickpeaks.m`
- `readWavCueChunks.m`
- `SpectralSpread.m`