# USENIX 2026 Submission: "GridPrint: Electric Network Frequency Signatures for Chip Geolocation"

## 1. Introduction

This repository contains the artifacts for the paper titled "GridPrint: Electric Network Frequency Signatures for Chip Geolocation," submitted to the 35th USENIX Security Symposium (USENIX 2026). The artifacts provided here allow for the complete and independent verification of our findings. Our work demonstrates the first experimental validation that Electric Network Frequency (ENF) signatures can be reliably recovered from the local environment of DC-powered PCB. We captured these signatures from two modalities: ambient electromagnetic radiation and on-board power traces sampled at the input of the first-stage voltage regulator. Refer to Section 5 in the paper for the complete details on the experimental methology.

The artifacts include:
* The complete raw dataset of ambient electromagnetic and on-board power traces captured from our experimental setups.
* The MATLAB scripts used for ENF extraction, and generating the plotting the results.
* Snapshots of our experimental setups and key results for quick reference and validation.

*Note: Our analysis tool, developed under one of the authors’ previous university’s policy, contains proprietary source code and cannot be released. To facilitate verification while respecting this constraint, we provide the core analysis functions as a compiled MATLAB
executable (`proc_enf_analysis.p`). This approach was discussed and approved by the USENIX Security 2026 Program Chairs to meet the open-artifact requirements.* 

## 2. Folder and File Hierarchy

The repository is structured as follows:
* **`exp_inputs/`**: Contains the EM and power traces for each board and DC adapter captured using Picoscope 3206D MSO
    * **`em_traces/`**: Ambient EM traces
        * **`baseline_em/`**: Ambient EM traces for experiment 1 from our paper
        * **`fpga_evalb_cw_305/`**: Ambient EM traces for experiment 2 from our paper for CW305 FPGA board, for each of DC adapter
        * **`fpga_evalb_sakura_g/`**: Ambient EM traces for experiment 2 from our paper for Sakura-G FPGA board, for each of DC adapter

    * **`power_traces/`**: On-board power traces
        * **`fpga_evalb_cw_305/`**: On-board power traces for experiment 3 from our paper for CW305 FPGA board, for each of DC adapter
        * **`fpga_evalb_sakura_g/`**: On-board power traces for experiment 3 from our paper for Sakura-G FPGA board, for each of DC adapter

    * **`multi_loc_exp/`**: Ambient EM traces for multi-location validation experiment 4
        * **`loc_60hz/`**: Ambient EM traces for Phase 1 of the multi-location validation experiment 4
        * **`loc_50hz/`**: Ambient EM traces for Phase 2 of the multi-location validation experiment 4

* **`exp_results/`**: Contains pre-generated figures and plots from our paper for easy reference

* **`exp_scripts/`**: Contains all the MATLAB code required to reproduce our analysis
    * **`enf_analysis_top.m`**: The main script to run the entire analysis pipeline
    * **`proc_enf_analysis.p`**: The core function for ENF extraction and plotting (proprietory protected code)

* **`exp_setups/`**: Contains snapshots for the experiment setups for each sensing modality for easy reference

* **`README.md`**: This file

## 3. MATLAB ENF Extraction Script Overview

### 1. Inputs
The script takes two time-synchronized inputs for each experiment:
* A **ground-truth reference trace** captured from the AC mains using the digital voice recorder
* A **sensed trace** captured from the experimental FPGA board using the PicoScope 3206D, which can be either an ambient EM signal or an on-board power trace.

### 2. Pre-processing
Both input traces are downsampled to a **1050 Hz sample rate**. This step focuses the analysis on the relevant frequency band (0-500 Hz) while reducing computational overhead.

### 3. Spectrogram Generation
The Short-Time Fourier Transform (STFT) is applied to both pre-processed traces to generate high-resolution **spectrograms**, which visualize the harmonic content of the signals over time.

### 4. ENF Estimation
Modality-specific algorithms are used to extract the instantaneous Electric Network Frequency (ENF) signature from each spectrogram:
* For **ambient EM traces** from both FPGA boards, a weighted average energy method is used.
* For **on-board power traces**, the algorithm is tailored to the board's specific harmonic profile:
    * A quadratic interpolation spectrum combination approach is used for traces from the **Sakura-G** board.
    * The weighted average energy method is used for traces from the **CW-305** board.

### 5. Outputs & Correlation
Finally, the script compares the ENF signature from the sensed trace against the signature from the ground-truth reference. It calculates the **Pearson correlation coefficient** and generates the final, temporally aligned plots to visually and quantitatively assess the match, as shown in the paper's results figures.

## 4. MATLAB ENF Extraction Script Usage
To reproduce the results presented in our paper, you will need a valid license for **MATLAB R2018b** or newer, with the **Signal Processing Toolbox** installed.

1.  **Download or clone this repository**
2.  **Open MATLAB**: Launch MATLAB and navigate to the `exp_scripts` directory within the cloned repository.
3.  **Set parameter values as per Experiment**: Open `enf_analysis_top.m` script and set the experiment configuration variables are described below for each experiment.
4.  **Run the Main Script**: Run the `enf_analysis_top.m` script. This will execute the complete analysis pipeline, from loading the raw data to generating the final results.
    ```matlab
    % In the MATLAB command window
    >> enf_analysis_top
    ```
5. **Complete Analysis**: After reviewing the results, you can clear and close the generated plots using the below command
    ```matlab
    % In the MATLAB command window
    >> clc; close all;
    ```

### ENF Script Configuration Guide
This table explains the various configuration options available in the script, what they control, and the valid values for each setting.

|Variable|Valid Values|Description|
|----------|--------------|-------------|
|`analysis_type`|`1` = Ambient EM Trace<br>`2` = Power Trace| Primary analysis method selection.|
|`pow_trace_type`|`1` = VREG IN<br>`2` = VREG OUT|Power trace source (when analysis_type = 2). |
|`board_type`|`1` = Sakura-G<br>`2` = CW305|Target FPGA board.|
|`adapter_type`|`1` to `5`|Specifies which DC adapter was used.|
|`enable_em_baseline`|`0` = Disabled<br>`1` = Enabled|Enable/disable EM baseline experiments. |
|`em_baseline_type`|`1` = Without Faraday bag<br>`2` = With Faraday bag|EM baseline experiment setup. Only used when enable_em_baseline = 1.|
|`enable_multi_loc`|`0` = Disabled<br>`1` = Enabled|Enable multi-location ENF validation.|
|`multi_loc_grid_freq`|`50` = 50Hz<br>`60` = 60Hz|Power grid frequency for multi-location testing.|
|`multi_loc_city`|**60Hz Options:**<br>"city_a_lab" (US Eastern)<br>"city_a_home" (US Eastern)<br>"worcester" (US Eastern)<br>"richardson" (US Texas)<br>"tucson" (US Western)<br><br>**50Hz Options:**<br>"city_a_lab" (US Eastern)<br>"dresden" (European)|City/location selection. Must match selected grid frequency.|
|`enable_50_vs_60_comparison`|`0` = Disabled<br>`1` = Enabled|Enable 50Hz vs 60Hz comparison. (for experiment 4, phase 2.)|

### Configuration Dependencies

- `pow_trace_type` is only used when `analysis_type = 2`
- `em_baseline_type` is only used when `enable_em_baseline = 1`
- `multi_loc_city` options must correspond to the selected `multi_loc_grid_freq`
- Multi-location options are only active when `enable_multi_loc = 1`
- When selecting "dresden" for 50hz location, enable `enable_50_vs_60_comparison`

### Example Configuration

```matlab
% Basic EM trace analysis with multi-location validation
analysis_type = 1;                  % Ambient EM Trace
board_type = 1;                     % Sakura-G board
adapter_type = 1;                   % DC adapter #1
enable_em_baseline = 0;             % Disable baseline experiments
enable_multi_loc = 0;               % Enable multi-location testing
%multi_loc_grid_freq = 60;           % 60Hz grid
%multi_loc_city = "city_a_lab";      % Primary location
%enable_50_vs_60_comparison = 1;     % Enable frequency comparison
```
