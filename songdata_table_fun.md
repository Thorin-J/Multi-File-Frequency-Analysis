
# songdata_table_fun.m

A MATLAB function to collate labeled song segments from WAV files into a single table, add temperature data from database, compute temporal metrics (pulse/group durations and intervals), and save the results per species and individual.  
The resulting `data_table` is formatted and ready for downstream spectral analysis by **songdata_analysis_fun.m**.

---

## Features

- Reads Avisoft cue chunks (`start_time`, `end_time`, `pulse_n`, `group_n`, `group_pn`) from all WAV files in a directory using `readWavCueChunks`.
- Converts and merges label data into a MATLAB table with columns:
  - `filename`, `start_time`, `end_time`, `pulse_n`, `group_n`, `group_pn`
- Computes:
  - `pulse_dur`: pulse durations
  - `pulse_int`: inter-pulse intervals
  - `group_dur`: durations of each pulse group
  - `group_int`: intervals between groups
- Imports temperature (and optionally relative humidity) from a specified Excel sheet, matching by date/time extracted from filenames.
- Cleans placeholder zeros to `NaN` for timing metrics.
- Reorders variables so `filename` appears first.
- Splits the master table by species and animal ID, then saves:
  - `<species>_songdata.mat` (contains `data_table`, `labels`, `wav_info`)
  - `<species>_songdata.xlsx` (one worksheet per individual)

---

## Usage

```matlab
% 1. Prepare a list of WAV files, e.g.:
wav_dir   = '/path/to/wav/files';
file_list = dir(fullfile(wav_dir, '*.wav'));

% 2. Define your temperature log file and sheet:
temp_file  = 'Daten Tiere & Recordings.xlsx';
sheet_name = 'KlimaLoggPro';

% 3. Define an output path for species-specific results:
path1 = '/path/to/output';

% 4. Run the table-building function:
data_table = songdata_table_fun(file_list, temp_file, sheet_name, out_path);

% 5. data_table is now ready for input into:
%    [data_table_out, ffts, settings] = songdata_analysis_fun(data_table, ...);
```

Inputs:
- `file_list`   : array of file structs (from `dir`)
- `temp_file`   : path to Excel file containing date, temp (and RH)
- `sheet_name`  : worksheet name with climate logs
- `path1`   	: directory for saving per-species `.mat` and `.xlsx` files

Output:
- `data_table`  : MATLAB table of labeled segments with timing & temperature, formatted for `songdata_analysis_fun.m`