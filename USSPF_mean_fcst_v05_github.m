%% Replicate Section 3.1: corrected mean US SPF forecasts
% USSPF_mean_fcst_v05_github combines v03, v04a and v04b in one script.
% Run this file to calculate all four indicators, all four horizons and
% all three correction methods. Requires MATLAB with Optimization Toolbox.
% No other .m files are needed; all helper functions are included below.
%
% INPUT: Mean_forecast.xlsx. Put it beside this script for a GitHub release.
% In the research folder, the script also finds ../Data/US_SPF automatically.
% Use the original quarterly workbook to replicate the draft (most sheets end
% in 2025Q3; the supplied RGDP sheet has one additional survey in 2025Q4).
% RGDP and INDPROD use the workbook's levels, as in the three source scripts.
%
% METHODS, with target quarter t, forecast horizon h, and error e(t,h):
%   previous_error (v03): e(t,h) - gamma*e(t-h,h).
%     Benchmark in tab:CorrMeanF and the h=2,3,4 appendix tables. Its
%     immediately preceding error is not yet observable at survey t-h.
%   lagged_error (v04a): e(t,h) - gamma*e(t-h-1,h).
%     Uses the latest realized same-horizon error; tab:CorrMeanF-realtime-v04a.
%   nowcast_proxy (v04b): e(t,h) - gamma*p(t-h,h), where
%     p(q,h) = nowcast(q|q) - forecast(q|q-h).
%     Uses the survey's mean nowcast; tab:CorrMeanF-realtime.
% Each method estimates gamma recursively with its own information cutoff.
%
% OUTPUTS in the workspace:
%   results.UNEMP.previous_error (and each other indicator/method) contains
%     TTable, RMSFE, RMSFEv, baseline RMSFEs, sample sizes, rho estimates and
%     rel_RMSFE_by_horizon{h}: the original rounded 9-by-11 paper panels.
%     Array order: evaluation period x horizon x correction factor.
%   paper_tables.<method>.h1 ... h4: labelled panels for all four indicators.
%   sample_counts: evaluation counts for fixed and recursive corrections.
% When write_outputs is true, output_USSPF_mean beside this script receives
% one MAT file with full-precision results, 12 rounded CSV tables, 12 LaTeX
% tabular fragments (bold minima selected before rounding), and sample counts.
% The UNEMP historical-factor figure reproduces the figure in Section 3.1.
%
% REPLICATION CONVENTIONS retained from the sources:
% - Fixed factors 0:0.1:1; gamma=0 is the method's matched-sample baseline.
% - Recursive warm-up: gamma=0.5 through row 50; CPI uses 0.3 through row 100.
% - fminunc is retained with its original options and no coefficient bounds.
%   The draft mentions a (-1,1) restriction, but the source scripts do not
%   impose it. Adding bounds would change the replication calculation.
% - COVID rows 206:213 are 2020Q1--2021Q4 in the supplied workbook. They are
%   excluded from starred evaluations and from both sides of training pairs.
%   Some draft captions instead say 2020Q1--2022Q4; we retain the code's dates.
% - Paper period labels are nominal: finite-pair filtering can move the first
%   evaluated quarter later, and each method/horizon has its own sample.
%   The extra RGDP survey also lets the original scripts evaluate 2025Q3,
%   although the draft's nominal period labels end at 2025Q2.
% - The historical column includes the fixed warm-up; estimation then uses
%   expanding history and drops pairs involving the COVID rows.
% - The separate lag-one nowcast exercise RMSNE is retained for completeness;
%   it is not the nowcast-proxy forecast correction and is not a paper column.
%
% Validation against the original scripts: all 12 indicator/method cases
% matched exactly in MATLAB R2026a. Three draft CPI h=1 recursive entries
% differ from v03: complete 0.97 vs 0.98, after-2000 0.97 vs 0.98, and
% after-COVID 0.84 vs 0.88 (draft vs code). The code results are retained.

clear variables
close all

%% Settings and portable locations
script_dir = fileparts(mfilename('fullpath'));
data_file = find_data_file(script_dir);
output_dir = fullfile(script_dir, 'output_USSPF_mean');
variables = ["UNEMP", "RGDP", "INDPROD", "CPI"];
method_names = ["previous_error", "lagged_error", "nowcast_proxy"];
forecast_horizons = 1:4;
write_outputs = true;       % Save tables and full-precision results.
make_figure = true;         % Plot the Section 3.1 UNEMP historical factors.
export_figure = false;       % Save the plot as a vector PDF when it is made.

if write_outputs || (make_figure && export_figure)
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
end
fprintf('Input workbook: %s\n', data_file);

%% Run all indicator/method combinations
results = struct();
for my_variable = variables
    my_data = importfile(data_file, my_variable, [2, Inf]);
    aligned = align_forecasts(my_data, my_variable, forecast_horizons);
    for method = method_names
        fprintf('Calculating %s / %s\n', my_variable, method);
        results.(my_variable).(method) = evaluate_method( ...
            aligned, my_variable, method, forecast_horizons);
    end
end

%% Assemble the paper panels in draft order
paper_tables = struct();
sample_counts = table();
column_names = ["gamma_01", "gamma_02", "gamma_03", "gamma_04", ...
    "gamma_05", "gamma_06", "gamma_07", "gamma_08", "gamma_09", ...
    "gamma_10", "recursive_hist"];
for method = method_names
    for h = forecast_horizons
        panel = table();
        full_values = [];
        for my_variable = variables
            r = results.(my_variable).(method);
            labels = period_labels(my_variable);
            numeric_panel = r.rel_RMSFE_by_horizon{h};
            block = [table(repmat(my_variable,9,1), labels, ...
                'VariableNames', {'Variable','Period'}), ...
                array2table(numeric_panel, 'VariableNames', column_names)];
            panel = [panel; block]; %#ok<AGROW>
            full_values = [full_values; squeeze(r.rel_RMSFE(:,h,:))]; %#ok<AGROW>
            counts = table(repmat(my_variable,9,1), repmat(method,9,1), ...
                repmat(h,9,1), labels, r.N_RMSFE(:,h), r.N_RMSFEv(:,h), ...
                'VariableNames', {'Variable','Method','Horizon','Period', ...
                'NFixed','NRecursive'});
            sample_counts = [sample_counts; counts]; %#ok<AGROW>
        end
        horizon_name = "h" + h;
        paper_tables.(method).(horizon_name) = panel;
        if write_outputs
            stem = "table-" + method + "-h" + h;
            writetable(panel, fullfile(output_dir, stem + ".csv"));
            write_latex_panel(fullfile(output_dir, stem + ".tex"), ...
                panel, full_values, method, h);
        end
    end
    fprintf('\nSection 3.1, %s, h=1:\n', method);
    disp(paper_tables.(method).h1);
end

if write_outputs
    writetable(sample_counts, fullfile(output_dir, 'sample-counts.csv'));
    save(fullfile(output_dir, 'USSPF_mean_section_3_1.mat'), ...
        'results', 'paper_tables', 'sample_counts', 'variables', ...
        'method_names', 'forecast_horizons', 'data_file');
    fprintf('Tables and full-precision results saved in: %s\n', output_dir);
end

%% Historical correction factors: the Section 3.1 figure
if make_figure
    r = results.UNEMP.previous_error;
    T = height(r.TTable);
    scrsz = get(0,'ScreenSize');
    fig = figure('PaperPositionMode','auto', ...
        'Position',[scrsz(3)/20 scrsz(4)/3 scrsz(3)/2 scrsz(4)/2], ...
        'PaperOrientation','landscape');
    rho_lines = plot(r.TTable.t(r.T0+1:T-1), ...
        r.TTable.rho_opt(r.T0+1:T-1,:), 'LineWidth',1.2);
    hold on;
    yline(0,'--k','LineWidth',1.2,'HandleVisibility','off');
    legend(rho_lines,"h=" + string(forecast_horizons),'Location','best');
    xlabel('Quarter');
    ylabel('Historically optimal correction factor');
    if export_figure
        exportgraphics(fig, fullfile(output_dir, ...
            'fig-HistOpt-corr-factor-UNEMP-all-horizons.pdf'), ...
            'ContentType','vector');
    end
end

%% Local helpers (this program does not call the old scripts)
function data_file = find_data_file(script_dir)
% Prefer the standalone GitHub layout, then the original research layout.
candidates = [string(fullfile(script_dir, 'Mean_forecast.xlsx')); ...
    string(fullfile(script_dir, '..', 'Data', 'US_SPF', 'Mean_forecast.xlsx'))];
found = find(isfile(candidates),1);
if isempty(found)
    error('USSPF:MissingData', ...
        'Place Mean_forecast.xlsx beside this script or in ../Data/US_SPF.');
end
data_file = candidates(found);
end

function TTable = align_forecasts(my_data, my_variable, forecast_horizons)
% At survey row s: suffix 1 is the previous-quarter realization, suffix 2
% is the current-quarter nowcast, and suffixes 3:6 forecast s+1,...,s+4.
% Shift the realization backward one row and each forecast forward h rows
% so every row of the timetable refers to the same target quarter.
T = height(my_data);
H = length(forecast_horizons);
actual_name = my_variable + "1";
nowcast_name = my_variable + "2";
forecast_names = my_variable + string(3:6);
actual_values = my_data.(actual_name);
ACTUAL = [actual_values(2:end); NaN];
NOWCAST = my_data.(nowcast_name);
raw_forecasts = my_data{:,forecast_names};
FORECAST = NaN(T,H);
for h = forecast_horizons
    FORECAST(h+1:end,h) = raw_forecasts(1:end-h,h);
end
t = datetime(my_data.YEAR,1,1) + calquarters(my_data.QUARTER-1);
t.Format = "yQQQ";
% The inherited evaluation/warm-up/COVID rules use row indices. Check the
% source snapshot's dates so another workbook cannot silently shift them.
expected_length = 228 + double(my_variable == "RGDP");
expected_dates = datetime(1968,10,1) + calquarters((0:expected_length-1)');
if ~isequal(t(:),expected_dates)
    error('USSPF:UnexpectedDates', ...
        'Use the original Mean_forecast.xlsx snapshot: 1968Q4--2025Q3, or 2025Q4 for RGDP.');
end
TTable = timetable(t, ACTUAL, NOWCAST, FORECAST);
TTable.FCST_ERROR = TTable.ACTUAL - TTable.FORECAST;
TTable.NCST_ERROR = TTable.ACTUAL - TTable.NOWCAST;
end

function result = evaluate_method(TTable, my_variable, method, forecast_horizons)
% One calculation engine for the three original scripts. correction_lags
% controls which signal corrects each target; estimation_extra_lag controls
% the latest dependent error allowed in the expanding estimation sample.
H = length(forecast_horizons);
T = height(TTable);
switch method
    case "previous_error"
        signal = TTable.FCST_ERROR;
        correction_lags = forecast_horizons;
        estimation_extra_lag = 0;
        source_version = "v03";
    case "lagged_error"
        signal = TTable.FCST_ERROR;
        correction_lags = forecast_horizons + 1;
        estimation_extra_lag = 1;
        source_version = "v04a";
    case "nowcast_proxy"
        TTable.PROXY_ERROR = TTable.NOWCAST - TTable.FORECAST;
        signal = TTable.PROXY_ERROR;
        correction_lags = forecast_horizons;
        estimation_extra_lag = 1;
        source_version = "v04b";
    otherwise
        error('USSPF:UnknownMethod','Unknown correction method: %s',method);
end
% Below, the numerical operations and fminunc options follow the sources.
% Only the signal and the two timing offsets differ between methods.
%% error analysis

time_periods.complete = [3:T-1]; % complete dataset
time_periods.complete_excl_COVID = [3:205 214:T-1]; % exclude COVID due to outliers
time_periods.before2000 = [3:125]; % before 2000
time_periods.after2000 = [126:T-1]; % after 2000
time_periods.after2000_excl_COVID = [126:205 214:T-1]; % exclude COVID due to outliers
time_periods.beforeGFC = [126:161]; % 2000-2008 before GFC
time_periods.beforeCOVID = [126:205]; % 2000-2019 before COVID
time_periods.betweenGFCcovid = [166:205]; % 2010-2019 between GFC and COVID
time_periods.afterCOVID = [214:T-1]; % 2022-2025 after COVID

N_time_periods = numel(fieldnames(time_periods));
names = fieldnames(time_periods);
rho_set = [0:0.1:1]; % different correction factors 
N_rho = length(rho_set);

% Dimensions: time period x forecast horizon x correction factor.
RMSFE = NaN(N_time_periods,H,N_rho);
N_RMSFE = NaN(N_time_periods,H);

for h = forecast_horizons
    pair_idx = ((h+1+correction_lags(h)):(T-1))';
    pair_valid = isfinite(TTable.FCST_ERROR(pair_idx,h)) ...
        & isfinite(signal(pair_idx-correction_lags(h),h));
    pair_idx = pair_idx(pair_valid);

    for j = 1:N_rho
        fixed_error = NaN(T,1);
        fixed_error(pair_idx) = TTable.FCST_ERROR(pair_idx,h) ...
            - rho_set(j) * signal(pair_idx-correction_lags(h),h);

        for i = 1:N_time_periods
            period_idx = time_periods.(names{i});
            period_idx = period_idx(:);
            valid_idx = period_idx(isfinite(fixed_error(period_idx)));
            RMSFE(i,h,j) = sqrt(mean(fixed_error(valid_idx).^2,"omitnan"));
            if j == 1
                N_RMSFE(i,h) = length(valid_idx);
            end
        end
    end
end

% The nowcast remains a separate lag-one exercise; it is not replicated
% across forecast horizons.
RMSNE = NaN(N_time_periods,N_rho);
for j = 1:N_rho
    TTable.NCST_ERROR_CORRECTED = [NaN; TTable.NCST_ERROR(2:end) ...
        - rho_set(j) * TTable.NCST_ERROR(1:end-1)];
    for i = 1:N_time_periods
        period_idx = time_periods.(names{i});
        period_idx = period_idx(:);
        RMSNE(i,j) = sqrt(mean(TTable.NCST_ERROR_CORRECTED(period_idx).^2,"omitnan"));
    end
end

%% Fixed-factor diagnostic errors
if my_variable == "UNEMP" || my_variable == "INDPROD" || my_variable == "RGDP"
    rho_fixed = 0.5;
elseif my_variable == "CPI"
    rho_fixed = 0.3;
else
    error("this variable not implemented yet")
end 
TTable.FCST_ERROR_FIXED = NaN(T,H);
for h = forecast_horizons
    pair_idx = ((h+1+correction_lags(h)):(T-1))';
    pair_valid = isfinite(TTable.FCST_ERROR(pair_idx,h)) ...
        & isfinite(signal(pair_idx-correction_lags(h),h));
    pair_idx = pair_idx(pair_valid);
    TTable.FCST_ERROR_FIXED(pair_idx,h) = TTable.FCST_ERROR(pair_idx,h) ...
        - rho_fixed * signal(pair_idx-correction_lags(h),h);
end

%% out of sample forecast with historical correction factor

if my_variable == "UNEMP" || my_variable == "INDPROD" || my_variable == "RGDP"
    T0 = 50; % use correction factor 0.5 within this period, then start validation
elseif my_variable == "CPI"
    T0 = 100; % CPI data starts at t = 52
else
    error("this variable not implemented yet")
end

% Before recursive estimation starts, use the fixed correction factor over
% the warm-up sample, matching the convention in the source scripts.
TTable.FCST_ERROR_RECURSIVE = NaN(T,H);
TTable.rho_opt = NaN(T,H);
covid_idx = 206:213;
optim_options = optimoptions('fminunc','Display','off');

for h = forecast_horizons
    rho_old = rho_fixed;

    warmup_idx = ((h+1+correction_lags(h)):min(T0,T-1))';
    warmup_valid = isfinite(TTable.FCST_ERROR(warmup_idx,h)) ...
        & isfinite(signal(warmup_idx-correction_lags(h),h));
    warmup_idx = warmup_idx(warmup_valid);
    TTable.FCST_ERROR_RECURSIVE(warmup_idx,h) = ...
        TTable.FCST_ERROR(warmup_idx,h) ...
        - rho_fixed * signal(warmup_idx-correction_lags(h),h);

    for target_idx = T0+1:T-1
        % Only the method-specific history is used: through t-h for the
        % v03 benchmark, and through t-h-1 for both real-time alternatives.
        train_idx = ((h+1+correction_lags(h)):(target_idx-h-estimation_extra_lag))';
        lag_idx = train_idx-correction_lags(h);

        keep_pair = ~ismember(train_idx,covid_idx) ...
            & ~ismember(lag_idx,covid_idx) ...
            & isfinite(TTable.FCST_ERROR(train_idx,h)) ...
            & isfinite(signal(lag_idx,h));
        train_idx = train_idx(keep_pair);
        lag_idx = lag_idx(keep_pair);

        if ~isempty(train_idx)
            dependent = TTable.FCST_ERROR(train_idx,h);
            regressor = signal(lag_idx,h);
            fun = @(x)sum((dependent - x * regressor).^2);
            [rho_new,~] = fminunc(fun,rho_old,optim_options);
            rho_old = rho_new;
        end

        TTable.rho_opt(target_idx,h) = rho_old;
        if isfinite(TTable.FCST_ERROR(target_idx,h)) ...
                && isfinite(signal(target_idx-correction_lags(h),h))
            TTable.FCST_ERROR_RECURSIVE(target_idx,h) = ...
                TTable.FCST_ERROR(target_idx,h) ...
                - rho_old * signal(target_idx-correction_lags(h),h);
        end
    end
end

% Compute recursive and uncorrected RMSFEs on exactly the same evaluation
% observations for each time period and horizon.
RMSFEv = NaN(N_time_periods,H);
baseline_RMSFEv = NaN(N_time_periods,H);
N_RMSFEv = NaN(N_time_periods,H);
for h = forecast_horizons
    for i = 1:N_time_periods
        period_idx = time_periods.(names{i});
        period_idx = period_idx(:);
        valid_idx = period_idx(isfinite(TTable.FCST_ERROR_RECURSIVE(period_idx,h)) ...
            & isfinite(TTable.FCST_ERROR(period_idx,h)));
        RMSFEv(i,h) = sqrt(mean(TTable.FCST_ERROR_RECURSIVE(valid_idx,h).^2,"omitnan"));
        baseline_RMSFEv(i,h) = sqrt(mean(TTable.FCST_ERROR(valid_idx,h).^2,"omitnan"));
        N_RMSFEv(i,h) = length(valid_idx);
    end
end

%% produce the relative-RMSFE panels
% Dimensions of rel_RMSFE: time period x horizon x method. The method
% dimension contains rho = 0.1,...,1 followed by the recursive correction.
baseline_RMSFE = RMSFE(:,:,rho_set == 0);
rel_RMSFE_fixed = RMSFE(:,:,rho_set ~= 0) ./ baseline_RMSFE;
rel_RMSFE_recursive = RMSFEv ./ baseline_RMSFEv;
rel_RMSFE = cat(3,rel_RMSFE_fixed,reshape(rel_RMSFE_recursive,[N_time_periods,H,1]));

rel_RMSFE_print = round(rel_RMSFE, 2);

% Each cell contains a 9-by-11 paper panel for one forecast horizon.
rel_RMSFE_by_horizon = cell(1,H);
for h = forecast_horizons
    rel_RMSFE_by_horizon{h} = squeeze(rel_RMSFE_print(:,h,:));
end



% Keep both raw and rounded results, matched baselines, counts and all
% aligned/corrected errors so every table and diagnostic can be inspected.
result = struct('source_version',source_version, 'TTable',TTable, ...
    'RMSFE',RMSFE, 'N_RMSFE',N_RMSFE, 'RMSNE',RMSNE, ...
    'RMSFEv',RMSFEv, 'baseline_RMSFEv',baseline_RMSFEv, ...
    'N_RMSFEv',N_RMSFEv, 'baseline_RMSFE',baseline_RMSFE, ...
    'rel_RMSFE_fixed',rel_RMSFE_fixed, ...
    'rel_RMSFE_recursive',rel_RMSFE_recursive, ...
    'rel_RMSFE',rel_RMSFE, 'rel_RMSFE_print',rel_RMSFE_print, ...
    'rel_RMSFE_by_horizon',{rel_RMSFE_by_horizon}, ...
    'rho_set',rho_set, 'rho_fixed',rho_fixed, 'T0',T0, ...
    'time_periods',time_periods, 'period_names',{names}, ...
    'correction_lags',correction_lags, ...
    'estimation_extra_lag',estimation_extra_lag);
end

function labels = period_labels(my_variable)
% Nominal labels reproduce the paper; actual evaluation uses finite pairs.
labels = ["1969Q1--2025Q2"; "1969Q1--2025Q2*"; "1969Q1--1999Q4"; ...
    "2000Q1--2025Q2"; "2000Q1--2025Q2*"; "2000Q1--2008Q4"; ...
    "2000Q1--2019Q4"; "2010Q1--2019Q4"; "2022Q1--2025Q2"];
if my_variable == "CPI"
    labels(1:3) = replace(labels(1:3),"1969Q1","1981Q3");
end
end

function write_latex_panel(file_name, panel, full_values, method, h)
% A standalone tabular fragment, suitable for inclusion in a table float.
% Bold only the best improving FIXED factor, selected at full precision;
% the recursive column is deliberately excluded from this selection.
fid = fopen(file_name,'w');
if fid < 0
    error('USSPF:OutputFile','Cannot write %s',file_name);
end
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%% Method: %s; horizon: %d\n',method,h);
fprintf(fid,'%% Starred rows exclude 2020Q1--2021Q4, matching the source scripts.\n');
fprintf(fid,'%s\n','\begin{tabular}{lrrrrrrrrrrr}', '\hline');
fprintf(fid,'%s\n', ...
    'Period & 0.1 & 0.2 & 0.3 & 0.4 & 0.5 & 0.6 & 0.7 & 0.8 & 0.9 & 1 & recurs. hist. \\', ...
    '\hline');
for row = 1:height(panel)
    if row == 1 || panel.Variable(row) ~= panel.Variable(row-1)
        fprintf(fid,'\\multicolumn{12}{c}{%s} \\\\\n',panel.Variable(row));
    end
    label = replace(panel.Period(row),'*','$^*$');
    fprintf(fid,'%s',label);
    [best_value,best_column] = min(full_values(row,1:10));
    for col = 1:11
        if col == best_column && best_value < 1
            fprintf(fid,' & \\textbf{%.2f}',full_values(row,col));
        else
            fprintf(fid,' & %.2f',full_values(row,col));
        end
    end
    fprintf(fid,' \\\\\n');
    if mod(row,9) == 0
        fprintf(fid,'%s\n','\hline');
    end
end
fprintf(fid,'%s\n','\end{tabular}');
end

function Result = importfile(workbookFile, sheetName, dataLines)
%IMPORTFILE Import data from a spreadsheet
%  RESULT = IMPORTFILE(FILE) reads data from the first worksheet in the
%  Microsoft Excel spreadsheet file named FILE.  Returns the data as a
%  table.
%
%  RESULT = IMPORTFILE(FILE, SHEET) reads from the specified worksheet.
%
%  RESULT = IMPORTFILE(FILE, SHEET, DATALINES) reads from the specified
%  worksheet for the specified row interval(s). Specify DATALINES as a
%  positive scalar integer or a N-by-2 array of positive scalar integers
%  for dis-contiguous row intervals.
%
%  Example:
%  Result = importfile("Mean_forecast.xlsx", "UNEMP", [2, Inf]);
%
%  See also READTABLE.
%
% Auto-generated by MATLAB on 06-Nov-2025 14:26:04

%% Input handling

% If no sheet is specified, read from UNEMP
if nargin == 1 || isempty(sheetName)
    sheetName = "UNEMP";
end

% If row start and end points are not specified, define defaults
lastRowOfDataIdx = 0;
if nargin <= 2
    dataLines = [2, Inf];
    lastRowOfDataIdx = 1;
elseif dataLines(end,2) >= Inf
    lastRowOfDataIdx = size(dataLines, 1);
end

%% Set up the Import Options and import the data
if sheetName == "UNEMP"
    opts = spreadsheetImportOptions("NumVariables", 12);
elseif sheetName == "CPI"
    opts = spreadsheetImportOptions("NumVariables", 11);
elseif sheetName == "INDPROD"
    opts = spreadsheetImportOptions("NumVariables", 10);
elseif sheetName == "RGDP"
    opts = spreadsheetImportOptions("NumVariables", 12);
else
    error("this variable not implemented yet")
end

% Specify sheet and range
opts.Sheet = sheetName;
if lastRowOfDataIdx == 1
    opts.DataRange = "A" + dataLines(1, 1);
else
    opts.DataRange = "A" + dataLines(1, 1) + ":L" + dataLines(1, 2);
end

% Specify column names and types
if sheetName == "UNEMP"
    opts.VariableNames = ["YEAR", "QUARTER", "UNEMP1", "UNEMP2", "UNEMP3", "UNEMP4", "UNEMP5", "UNEMP6", "UNEMPA", "UNEMPB", "UNEMPC", "UNEMPD"];
    opts.VariableTypes = ["double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
    % Specify variable properties
    opts = setvaropts(opts, ["UNEMPC", "UNEMPD"], "EmptyFieldRule", "auto");
elseif sheetName == "CPI"
    opts.VariableNames = ["YEAR", "QUARTER", "CPI1", "CPI2", "CPI3", "CPI4", "CPI5", "CPI6", "CPIA", "CPIB", "CPIC"];
    opts.VariableTypes = ["double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
    % Specify variable properties
    opts = setvaropts(opts, ["CPIC"], "EmptyFieldRule", "auto");
elseif sheetName == "INDPROD"
    opts.VariableNames = ["YEAR", "QUARTER", "INDPROD1", "INDPROD2", "INDPROD3", "INDPROD4", "INDPROD5", "INDPROD6", "INDPRODA", "INDPRODB"];
    opts.VariableTypes = ["double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
elseif sheetName == "RGDP"
    opts.VariableNames = ["YEAR", "QUARTER", "RGDP1", "RGDP2", "RGDP3", "RGDP4", "RGDP5", "RGDP6", "RGDPA", "RGDPB", "RGDPC", "RGDPD"];
    opts.VariableTypes = ["double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
    % Specify variable properties
    opts = setvaropts(opts, ["RGDPC", "RGDPD"], "EmptyFieldRule", "auto");
else
    error("this variable not implemented yet")
end



% Import the data
Result = readtable(workbookFile, opts, "UseExcel", false);

for idx = 2:size(dataLines, 1)
    if idx == lastRowOfDataIdx
        opts.DataRange = "A" + dataLines(idx, 1);
    else
        opts.DataRange = "A" + dataLines(idx, 1) + ":L" + dataLines(idx, 2);
    end
    tb = readtable(workbookFile, opts, "UseExcel", false);
    Result = [Result; tb]; %#ok<AGROW>
end

end
