# Neural Entrainment Scripts

These MATLAB scripts were used for a project measuring neural entrainment using EEG. I have put them here with the hope that they will be useful to others interested in analyzing EEG data. They can be used as a template for another analysis or for inspiration. Many of the scripts can be used outside of this project (see the [General EEG Analysis](#analysis-general-eeg-analysis) section).

The `task` folder is for presenting stimuli on a Windows computer, and was used to send port codes to a BioSemi EEG recording system. The `analysis` folder is a combination of wrapper scripts for [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) (mostly for preprocessing), and custom functions for selecting independent components by location and measuring entrainment.

## Table of Contents

1. [Analysis](#analysis)
    1. [Running the Pipeline](#analysis-running-the-pipeline)
    2. [Preparing the Project Folder](#analysis-preparing-the-project-folder)
    3. [The Diary File](#analysis-the-diary-file)
    4. [List of Analysis Functions](#analysis-list-of-analysis-functions)
        1. [Project Macros](#analysis-functions-project-macros)
        2. [Project Utilities](#analysis-functions-project-utilities)
        3. [Project EEG Analysis](#analysis-functions-project-eeg-analysis)
        4. [General EEG Analysis](#analysis-functions-general-eeg-analysis)
2. [MATLAB](#matlab)

<a name="analysis">

## Analysis

<a name="analysis-running-the-pipeline">

### Running the Pipeline

The following code will run the entire EEG analysis pipeline from raw BDF files to a tabular data frame of entrainment values.

```matlab
% make sure paths in en_getpath are correct
% set current folder to this analysis folder
ids = 6:16;
en_load('eeglab')
en_loop_eeg_preprocess(ids);
% look at topographical maps saved in en_getpath('topoplots') and mark down component numbers that are dipolar in en_diary.csv
en_loop_eeg_entrainment(ids);
T = en_getdata(ids);
writetable(T, 'mydata.csv');
```

<a name="analysis-preparing-the-project-folder"></a>

### Preparing the Project Folder

The function `en_getpath` is used to access all required directory paths and files for the rest of the scripts in this toolbox (except for the "General EEG Analysis" functions, which don't require any external paths or files). Paths can be edited, added, or removed from that function as needed. Here is the folder structure for the current project, with some example filenames:

```
project_folder/  
|-- analysis/  
    |-- en_diary.csv  
    |-- (all the other files in the analysis folder)  

|-- data/  
    |-- bdf/                (raw EEG recordings)  
        |-- 20180101A.bdf  

    |-- eeg/                (output data from en_eeg_preprocess)  
        |-- 1.set  
        |-- 1.fdt  
        |-- 1_portcodes.txt  

    |-- eeg_goodcomps/      (output plots from en_eeg_entrainment)  
        |-- aud
            |-- 1_dipplot.png  
            |-- 1_topoplot.png  
        |-- mot
            |-- 1_dipplot.png  
            |-- 1_topoplot.png  
        |-- pmc
            |-- 1_dipplot.png  
            |-- 1_topoplot.png  

    |-- eeg_entrainment/    (output data from en_eeg_entrainment)  
        |-- 1_aud.csv  
        |-- 1_pmc.csv  

    |-- eeg_topoplots/      (output plots from en_eeg_preprocess)  
        |-- 1_topoplot.fig  
        |-- 1_topoplot.png  

    |-- logfiles/           (output from the task)  
        |-- 1_mir_eeg.csv  
        |-- 1_mir_eeg_trialList.txt  
        |-- 1_mir_tapping.csv  
        |-- 1_mir_tapping_trialList.txt  
        |-- 1_sync_eeg.csv  
        |-- 1_sync_eeg_trialList.txt  
        |-- 1_sync_tapping.csv  
        |-- 1_sync_tapping_trialList.txt  

    |-- midi/               (raw tapping files exported from ProTools)
        |-- 6.mid
        |-- 6.wav

|-- eeglab/                 (EEGLAB toolbox)  

|-- task/               (this folder is moved to the stim pres comp)
    |-- logfiles/       (these are just logfiles from testing)

```

Note: the task scripts save the logfiles in the task/logfiles folder; these files should be moved to the logfiles folder for analysis.

<a name="analysis-the-diary-file"></a>

### The Diary File

The diary.csv file can be considered a sort of configuration file for the analysis. It should contain the following columns, with each row representing a single participant:

| Variable        | Type                                    | Description |
| --------------- | --------------------------------------- | ----------- |
| id              | [numeric]                               | Each row should be a unique number. When calling the functions in this toolbox, use this number to refer to a specific participant. |
| incl            | [boolean; 1 or 0]                       | Whether or not to include this participant in the analysis. When calling the "getdata" or looping functions in this toolbox, leaving the id argument empty will use all id's that have a 1 here. |
| order           | [numeric, 1 or 2]                       | This is used by the `en_epoch` function. |
| bdffile         | [comma-separated list of strings]       | List of bdf (raw BioSemi EEG data) files associated with this id. Don't include the ".bdf". If there are multiple files, `en_readbdf` will read them all and merge them using EEGLAB's `pop_mergeset`. |
| eventchans      | [numeric]                               | The channel from which the portcode information should be extracted. Used by the `en_readbdf` function. |
| rmchans         | [comma-separated list of strings]       | Channel/electrode labels that should be removed because they were noisy during the recording. |
| rmportcodes     | [comma-separated list of numbers]       | If there were extra portcodes sent (e.g., because a trial was repeated and the portcode was erroneously sent twice), enter the indices of the portcodes that should be removed. For example, if there are 60 trials, and the portcode for the 30th trial was sent twice (i.e., the 30th and 31st portcodes are the same trial, and you would like to remove the first one), enter 30 here. |
| missedportcodes | [comma-separated list of numbers]       | If some portcodes did not get sent (e.g., because the BioSemi battery died, but the experiment continued), enter the indices of the portcodes that were missed. For example, if there are 60 trials, and the battery died after the 10th trial, you didn't notice and stop the experiment until after the 15th trial (trials 11 to 15 did not have their portcodes recorded), enter "11, 12, 13, 14, 15" here (without the quotes). Note that if the battery dies in the middle of a trial, you might want to consider adding that trial to *rmportcodes*. Filling in this field will probably require some comparison of the logfile (which portcodes were sent) and the BDF file (which portcodes were recorded). |
| experimenters   | [comma-separated list of strings]       | Initials of the experimenters for this participant's session. |
| recording_notes | [semicolon-separated list of sentences] | Any notes from the EEG recording session that might be good to know. |
| dipolar_comps   | [comma-separated list of numbers]       | After running `en_eeg_preprocess`, look at the topographical plots that are saved and mark down which components are dipolar. This field is used by `en_eeg_entrainment` to select good components with `select_comps`. See Delorme, Palmer, Onton, Oostenveld, & Makeig (2012; PLOS ONE) for more information. |

<a name="analysis-list-of-analysis-functions"></a>

### List of Analysis Functions

Each function list is loosely in the order that they would be used in the processing pipeline.

<a name="analysis-functions-project-macros"></a>

#### Project Macros

Perform a whole section of the analysis pipeline and batch processing. These mostly contain calls to the other functions in the lists below.

| Function                  | Description |
| ------------------------- | ----------- |
| `en_eeg_preprocess`       | A macro that runs `en_readbdf` and a number of [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) functions to pre-process EEG data, including ICA and dipole fitting. Resultant .set files are saved to `en_getpath('eeg')`. |
| `en_loop_eeg_preprocess`  | Loops through the specified IDs and runs `en_eeg_preprocess`. All output from the command window is captured for each ID and saved to `en_getpath('eeg')`, as well as a summary file with processing times and any errors for each ID. |
| `en_eeg_entrainment`      | A macro that takes an ID or EEGLAB struct and outputs a table of entrainment values for each trial. Resultant tables are saved as .csv files in `en_getpath('eeg_entrainment')`. |
| `en_loop_eeg_entrainment` | Loops through specified IDs and runs `en_eeg_entrainment`. |

<a name="analysis-functions-project-utilities"></a>

#### Project Utilities

Simplify finding and loading files.

| Function                  | Description |
| ------------------------- | ----------- |
| `en_getpath`              | Takes a keyword as input and returns a directory or file path. All functions in this "toolbox" use this function to get path names. This means that you can move these scripts to a different computer or port them to a different project, and will only have to change this file in order for everything to work (theoretically). Note that in order for the `en_load` function to properly detect if a toolbox has been loaded, these have to be absolute paths. |
| `en_load`                 | Takes a keyword (and optionally an ID number), and loads the specified file into the MATLAB workspace. Can also start [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) from the path specified in `en_getpath('eeglab')`. |

<a name="analysis-functions-project-eeg-analysis"></a>

#### Project EEG Analysis

These include wrappers on EEGLAB functions (mostly EEG preprocessing) and custom scripts for spectral analyses.

| Function                  | Description |
| ------------------------- | ----------- |
| `en_readbdf`              | Takes an ID number as input, gets their .bdf filenames from `en_diary.csv`, and reads those files into an [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) .set file (if there are multiple .bdf files, they are merged). It also converts the channel labels from the BioSemi alphabetical labels into [Oostenveld](http://robertoostenveld.nl/electrode/)'s 10-5 system. |
| `en_epoch`                | Epochs an EEG struct using [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) based on portcodes which are specified with keywords. This function in particular is highly specialized for the current study, and will require lots of editing to work for a different study. |
| `en_dipfit`               | Wrapper on [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) functions for dipole fitting using the Boundary Element Model (BEM). |

<a name="analysis-functions-general-eeg-analysis"></a>

#### General EEG Analysis

Some EEG-related functions for preprocessing and spectral analysis that will work outside of this project.

| Function                  | Description |
| ------------------------- | ----------- |
| `alpha2fivepct`           | Takes an EEG struct or a cell of strings, and remaps channel labels from BioSemi alphabetical labels to [Oostenveld](http://robertoostenveld.nl/electrode/)'s 10-5 system. |
| `averageReference`        | Performs average referencing for fully-ranked data on an EEG struct. |
| `tal2region`              | This is a wrapper for the [Talairach client](http://www.talairach.org/client.html). It requires that the `talairach.jar` file be in the same folder. |
| `region2comps`            | This is a wrapper for `tal2region`, that takes an EEG struct and a brain region as input, and returns the IC numbers that are in, or close to that region. |
| `select_comps`            | Takes a preprocessed EEG struct and returns component numbers that match three criteria: region, residual variance, or by manually giving indices. In this project, the indices input is used for manually selecting components that are dipolar. |
| `dtplot`                  | Takes a preprocessed EEG struct and displays both a topographical plot and a dipole plot for the specified components. If a folder argument is given, these plots are saved as .png files instead of being displayed. |
| `getfft3`                 | A fancy wrapper on MATLAB's `fft` function that expects data to be channels-by-time-by-trials (e.g., EEGLAB's EEG.data). |
| `noisefloor3`             | For each value in the data, remove the mean of surrounding values. This version expects data to be channels-by-time-by-trials (e.g., EEGLAB's EEG.data). |
| `getbins3`                | Given some data and a vector of labels, get the value (or mean/max/min) of data for specified labels. This is used to get the max spectral value at a given frequency. |

<a name="matlab"></a>

## MATLAB

These scripts were written using MATLAB R2017a.
