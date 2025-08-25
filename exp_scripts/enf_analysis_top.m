%% ENF Signature Analysis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Description:
% This script implements the signal processing pipeline for the USENIX Security 
% 2026 paper, "GridPrint: Electric Network Frequency Signatures for Chip
% Geolocation".
%
% The primary goal is to validate the feasibility of extracting Electric 
% Network Frequency (ENF) signatures from DC-powered hardware by comparing 
% a sensed trace against a ground-truth reference. The procedure is a direct
% implementation of the methodology detailed in Section 5 of the paper.
%
% --- ANALYSIS OVERVIEW ---
% 1.  INPUTS: The script takes two time-synchronized inputs:
%     - A 'ground-truth reference trace' captured from the AC mains.
%     - A 'sensed trace' captured from the experimental FPGA board.
%       This can be either an ambient EM signal or an on-chip power trace.
%
% 2.  PRE-PROCESSING: Both trace files are converted to (.wav format) and 
%     undergo downsampling to a 1050 Hz sample rate to focus on the relevant 
%     frequency band (0-500 Hz).
%
% 3.  SPECTROGRAM GENERATION: The Short-Time Fourier Transform (STFT) is
%     applied to both traces to generate high-resolution spectrograms,
%     visualizing the harmonic content over time.
%
% 4.  ENF ESTIMATION: Modality-specific algorithms are then used to extract
%     the instantaneous ENF signature from each spectrogram. A weighted 
%     average energy method is used for EM traces for both FPGA boards. 
%     A quadratic interpolation spectrum combination approach is used for 
%     power traces from Sakura-G board and weighted average energy method 
%     is used for power traces from CW305 board.
%
% 5.  OUTPUTS & CORRELATION: Finally, the script compares the ENF signature
%     from the sensed trace against the signature from the ground-truth 
%     reference. It calculates the Pearson correlation coefficient and 
%     generates the final temporally aligned plots to visually and quantitatively 
%     assess the match.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Script User Configuration Options
%Options for sensed trace type
%1: Ambient EM Trace
%2: Power Trace
analysis_type = 1;

%Options for power sensed trace type
%1: VREG IN
%2: VREG OUT
pow_trace_type = 2;

%Options for FPGA board
%1: Sakura-G
%2: CW305
board_type = 1;

%Options of DC adapter:
%Valid values 1 to 5
adapter_type = 4;

%Enable baseline EM experiments 1
enable_em_baseline = 0;
%Options for baseline EM experiments 1
%1: Without faraday bag
%2: With faraday bag
em_baseline_type = 1;

%Enable multilocation ENF validation
enable_multi_loc = 0;
multi_loc_grid_freq = 60;

%Options for 60Hz Grids:
%1: city_a_lab     %US Eastern Connection Power Grid
%2: city_a_home    %US Eastern Connection Power Grid
%3: worcester      %US Eastern Connection Power Grid
%4: richardson     %US Texas Connection Power Grid
%5: tucson         %US Western Connection Power Grid

%Options for 50Hz Grids:
%1: city_a_lab     %US Eastern Connection Power Grid
%2: dresden        %US Eastern Connection Power Grid
multi_loc_city = "richardson";

%Enable ENF comparison for 60Hz vs 50Hz (Experiment 4, phase 2)
enable_50_vs_60_comparison = 0;


%% Script Configuration
if enable_multi_loc == 0
    [file_path, file_1_name, file_2_name] = config_input_files(analysis_type,pow_trace_type,board_type,adapter_type,enable_em_baseline,em_baseline_type);    
else
    analysis_type = 1;
    [file_path, file_1_name, file_2_name] = config_input_files_multi_loc(multi_loc_grid_freq, multi_loc_city, enable_50_vs_60_comparison);   
end

% Spectrogram Parameters:
% STFT compute param settings
frame_size_arr      = [1:12]*1000;
frame_size          = frame_size_arr(8);                %8000ms window
nfft_arr            = 2.^[10:20];
nfft                = nfft_arr(6);                      %2^15 = 32768 pts
overlap_size_arr    = 0:0.1:0.9;
overlap_size        = overlap_size_arr(1)*frame_size;   %non-overlapping

if enable_50_vs_60_comparison == 0
    % Fundamental power grid frequency settings
    nominal_freq_arr      = [50 60]; 
    nominal_freq_1        = nominal_freq_arr(2);        %60hz ref
    harmonics_arr_1       = [1:7]*nominal_freq_1;
    
    nominal_freq_2        = nominal_freq_arr(2);        %60hz sens
    harmonics_arr_2       = [1:7]*nominal_freq_2;
else
    % Fundamental power grid frequency settings
    nominal_freq_arr      = [50 60]; 
    nominal_freq_1        = nominal_freq_arr(1);        %50hz ref
    harmonics_arr_1       = [1:7]*nominal_freq_1;
    
    nominal_freq_2        = nominal_freq_arr(2);        % 60hz sens
    harmonics_arr_2       = [1:7]*nominal_freq_2;
end

% Frequency Estimation Parameters:
trace_1_est_freq = harmonics_arr_1(1);                    %1st harmonic= 60Hz    
trace_2_est_freq = harmonics_arr_2(1);                    %1st harmonic= 60Hz
%Frequency estimation method options: 
%1: weighted average (pmf power = 3)
%2: spectrum combining (quad interp)

if analysis_type == 1 || (analysis_type == 2 && board_type == 2)
    %For reference trace
    trace_1_freq_est_method = 1;                            
    trace_1_freq_est_spec_comb_harmonics = [60 120 180 240 300 360 420];
    %For sensed trace
    trace_2_freq_est_method = 1;                            
    trace_2_freq_est_spec_comb_harmonics = [120 240 360];
elseif analysis_type == 2 && board_type == 1
    %For reference trace
    trace_1_freq_est_method = 2;                            
    trace_1_freq_est_spec_comb_harmonics = [60 120 180 240 300 360 420];
    %For sensed trace
    trace_2_freq_est_method = 2;                            
    trace_2_freq_est_spec_comb_harmonics = [120 240 360];
end
        

%The colormap for the figures is set to jet.
set(0,'DefaultFigureColormap', jet)

%Titles for MATLAB plots
trace_1_plot_title = "Reference AC Mains Power Trace";
if analysis_type == 1
    trace_2_plot_title = "Ambient EM Trace";
else
    trace_2_plot_title = "FPGA Power Trace";
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input File
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%For reference AC mains power trace recording
full_file_1_path_wav = file_path + file_1_name + ".wav";

%For sensed trace from picoscope
full_file_2_path_wav = file_path + file_2_name + ".wav";        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main ENF analysis code (calls the pre-compiled executable which contains proprietory code)
% Handles spectrogram computation, ENF extraction, ENF
% matching and plotting all the figures
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
proc_enf_analysis(full_file_1_path_wav, full_file_2_path_wav, ...
                      nfft, frame_size, overlap_size, ...
                      harmonics_arr_1, nominal_freq_1, harmonics_arr_2, nominal_freq_2,...
                      trace_1_freq_est_method, trace_1_est_freq, trace_1_freq_est_spec_comb_harmonics, ...
                      trace_2_freq_est_method, trace_2_est_freq, trace_2_freq_est_spec_comb_harmonics, ...
                      trace_1_plot_title, trace_2_plot_title);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Check input file path and names
function [fp, fn_1, fn_2] = config_input_files(analysis_type,pow_trace_type,board_type,adapter_type,enable_em_baseline,em_baseline_type)
    %% Input trace file information
    % Note 1: file name specified without file extension
    % Note 2: file path specified relative to script location
    
    if analysis_type == 1
        if enable_em_baseline == 1
            if em_baseline_type == 1
                fp = "../exp_inputs/em_traces/baseline_em/without_faraday_bag/";
            elseif em_baseline_type == 2
                fp = "../exp_inputs/em_traces/baseline_em/with_faraday_bag/";
            else
                error('ERROR: Incorrect baseline_type analysis type value configured');
            end
        else
            if board_type == 1
                fp = "../exp_inputs/em_traces/fpga_evalb_sakura_g/dc_adapter_"+adapter_type+"/";
            elseif board_type == 2
                fp = "../exp_inputs/em_traces/fpga_evalb_cw_305/dc_adapter_"+adapter_type+"/";
            else
                error('ERROR: Incorrect FPGA board type value configured');
            end
        end
    elseif  analysis_type == 2
        if board_type == 1
            fp = "../exp_inputs/pow_traces/fpga_evalb_sakura_g/dc_adapter_"+adapter_type+"/";
        elseif board_type == 2
            fp = "../exp_inputs/pow_traces/fpga_evalb_cw_305/dc_adapter_"+adapter_type+"/";
        else
            error('ERROR: Incorrect FPGA board type value configured');
        end
    else
       error('ERROR: Incorrect analysis type value configured'); 
    end
   
    
    % Reference AC Mains Power Trace 
    fn_1 = "mains_pow_trace_ac";

    % For Sensed Trace = Ambient EM Trace
    if analysis_type == 1
        fn_2 = "fpga_em_trace_dc";
    elseif analysis_type == 2
        if pow_trace_type == 1
            fn_2 = "fpga_pow_trace_dc_a";       %VREG_IN
        elseif pow_trace_type == 2
            fn_2 = "fpga_pow_trace_dc_b";       %VREG_OUT
        else
            error('ERROR: Incorrect pow_trace_type value configured');
        end
    else
        error('ERROR: Incorrect analysis type value configured');
    end

end

function [fp, fn_1, fn_2] = config_input_files_multi_loc(multi_loc_grid_freq, multi_loc_city, enable_50_vs_60_comparison)
    %% Input trace file information
    % Note 1: file name specified without file extension
    % Note 2: file path specified relative to script location
    if multi_loc_grid_freq == 60
        fp = "../exp_inputs/multi_loc_exp/loc_60hz/";
        if multi_loc_city ~= "city_a_lab" && multi_loc_city ~= "city_a_home" && multi_loc_city ~= "worcester" && multi_loc_city ~= "richardson" && multi_loc_city ~= "tucson"
            error('ERROR: Incorrect city configured for 60Hz grids'); 
        end
        
    elseif multi_loc_grid_freq == 50
        fp = "../exp_inputs/multi_loc_exp/loc_50hz/";
        if enable_50_vs_60_comparison == 0
            multi_loc_city = "city_a_lab";     %US Eastern Connection Power Grid
        else
            multi_loc_city = "dresden";       %German Power Grid
        end
    else
       error('ERROR: Incorrect multi_loc_grid_freq configured'); 
    end
    
    % Reference AC Mains Power Trace 
    fn_1 = multi_loc_city + "/mains_pow_trace_ac";
    % For Sensed Trace = Ambient EM Trace
    fn_2 = "city_a_lab/fpga_em_trace_dc"; 

end
