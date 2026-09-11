%% USSPF_opt_fcst_v05_github: documented optimal-combination illustration
% Based on USSPF_opt_fcst_v04.m. Numerical calculations, solver settings,
% sample selection, defaults and plots are retained. Changes are explanatory
% comments and portable input/output paths. All helper functions are included.
%
% RUNNING THE SCRIPT
% Requires MATLAB, Optimization Toolbox (quadprog, fminunc, fmincon), and
% Econometrics Toolbox (autocorr). Place Individual_forecast.xlsx beside this
% script for a standalone GitHub copy; the original ../Data/US_SPF layout is
% also supported. Run the complete script. It clears the workspace and closes
% existing figures, then displays diagnostic plots and the MSE_print table.
% PDF export lines remain commented out, as in v04. If enabled, they save
% beside the script. Some figures contain multiple panels; an export of a
% whole figure is not automatically a separate PDF for each paper subfigure.
%
% DEFAULT ILLUSTRATION (Section 3.2)
% UNEMP, surveys in 2000--2019, forecasters with at least 70 survey rows,
% missing forecasts filled from their previous available value (imp_type=2),
% and recursive fits starting at retained observation 25. The original script
% has only been checked for the optimal-weight UNEMP illustration. Other
% indicators can be selected but their regression results need separate checks.
% my_period=1 selects 2000--2008 with a 30-row threshold. my_period=3 creates
% the full-period data plot and deliberately stops with the inherited error.
%
% METHODS COMPUTED IN ONE RUN
% MEAN: equal-weight average of available reports, with fixed and recursively
%   estimated error corrections. The default fixed coefficient here is 0.65.
% REGR_IN / REGR_OUT: restricted least squares with weights summing to one,
%   estimated on the complete retained sample / expanding historical sample.
%   Weights may be negative; these regressions have no intercept.
% REGR_OUT_CORR_HO: correct the recursive OLS forecast using the preceding
%   errors of previously issued OLS combinations (not refitted residuals).
% REGR_GLS: jointly estimate weights and an AR(1) error parameter using
%   quasi-differenced least squares, then add the last residual correction.
% REGR_CR4 / REGR_CR5: the dynamic-level and error-correction benchmarks
%   implemented from Coulson and Robins (1993), both fitted recursively.
% CLEM_CTC_MEAN: estimate an intercept and slope for each reported individual
%   forecast, correct it, then average the available corrected forecasts.
%   This Clements-based benchmark uses raw, not imputed, individual reports.
% Fixed corrections to both in-sample and recursive OLS are also computed.
% The legacy in_out_sample flag does not select a method: its if/else guards
% are commented out in v04, so all of the above methods run regardless.
%
% MAIN WORKSPACE OUTPUTS
% selected_table / fcst_cols: selected forecaster IDs and regression columns.
% my_pdata_fcst_aligned_TT: target-aligned data and combined forecasts.
% my_pdata_fcst_errors_TT: individual, mean and method-specific forecast errors.
% MSE / MSE_print: full-precision / four-decimal MSFE and relative-MSFE tables.
%   rMSFE divides by the FIRST MSE row (ERR_MEAN in the default illustration).
%   These are squared-error ratios, not relative root mean squared errors.
% w_hat_GLS_set, rho_opt_set, rho_opt_GLS_set: recursive parameter histories.
% beta_hat_CR4_set / beta_hat_CR5_set: dynamic benchmark coefficient histories.
% X_corr_CLEM, delta0_CLEM_set / delta1_CLEM_set: corrected individual reports
%   and their efficiency-regression coefficient histories.
%
% CONVENTIONS THAT MATTER FOR REPLICATION
% Selection counts survey rows across the selected period, not nonmissing
% forecasts at each horizon. Panel membership is therefore fixed ex post.
% All models use the source script's one-quarter-ahead target alignment and
% history cutoffs; no additional publication lag is imposed in this version.
% Only regression inputs are imputed. Individual/mean forecast errors keep
% the available-report convention of v04. MSFEs use the original timetable
% window T_out_start+1:end with NaNs omitted separately for each series.
% Optimizers for mean-error correction are unconstrained. fmincon bounds the
% recursive OLS correction and GLS AR parameter to [-1,1] (endpoints allowed).
% Full-sample corr_factor_opt estimates are diagnostic: fixed corrections
% use the explicitly assigned coefficients, not these estimated optima.
% To reproduce the table's additional fixed-factor rows, rerun with the mean
% coefficient 0.5 instead of 0.65, or the OLS coefficient 0.7 instead of 0.5,
% at the documented correction sections below. v04 computes one of each
% fixed-coefficient choice per run; that behaviour is preserved here.
%
% VALIDATION: in MATLAB R2026a, all 33 compared numerical/data outputs matched
% v04 exactly for the full default UNEMP run. Standalone workbook discovery
% and the output location were checked; Code Analyzer diagnostics were unchanged.

clear all
close all

% import the data 
my_variable = "UNEMP"; % "UNEMP", "CPI" or "INDPROD" or "RGDP"
                       % optimal weight code only checked for UNEMP, 
                       % other variables only the first graph is saved, the rest needs checks
% Locate files relative to this script, independently of MATLAB's current folder.
script_dir = fileparts(mfilename('fullpath'));
output_dir = script_dir;
data_file = find_data_file(script_dir);
my_data = importfile(data_file, my_variable, [2, Inf]);

% collect all branching variables here
in_out_sample = 4; % 1 for in-sample, 
                   % 2 for out-of-sample optimal weight computed via restricted regression
                   % 3 for out-of-sample and corrected at the same time
                   % 4 GLS
                   % legacy flag: all methods are computed in this version
my_period = 2; % 1 for before GFC, 
               % 2 for before COVID, 
               % 3 for figures spanning full period
imp_type = 2; % imputation type to balance the panel: 
              % 1 - mean of other forecasters
              % 2 - previous observed forecast
T_out_start = 25; % start of out-of-sample forecasting for historical factor, OLS and GLS
Clements_n_min = 10; % minimum individual history for the real-time efficiency correction

% The selected period and survey-count threshold determine panel membership
% before any imputation. The default 70-of-80 rule yields six UNEMP forecasters.
if my_period == 1
    % 2000-2008 before GFC
    my_data = my_data(my_data.YEAR >= 2000 & my_data.YEAR <= 2008, :);
    T_threshold = 30; % minimum number of forecasts
    % 2000-2008 has 9*4=36 observations, 16.7% missing allowed
elseif my_period == 2
    % or 2000-2019 before COVID
    my_data = my_data(my_data.YEAR >= 2000 & my_data.YEAR <= 2019, :);
    T_threshold = 70; % 20*4=80, 12.5% missing allowed
elseif my_period == 3
    % all period do create Figure 2 in the draft
    my_data = my_data(my_data.YEAR >= 1969 & my_data.YEAR <= 2026, :);
    T_threshold = 0; 
else 
    error("this period is not implemented")
end

% find a small balanced panel in some period;
% compute optimal forecast and corrected optimal forecast

% the industry coded as a “1” for a financial service provider, “2” for a nonfinancial service provider, and “3” if we are uncertain.
% it is characteristic of the forecaster, no need to filter it out =>
% remove it
my_data.INDUSTRY = [];
if my_variable == "UNEMP"
    % keep only UNEMP1, 2, 3
    my_data.UNEMP4 = []; my_data.UNEMP5 = []; my_data.UNEMP6 = []; my_data.UNEMPA = []; my_data.UNEMPB = []; my_data.UNEMPC = []; my_data.UNEMPD = [];
elseif my_variable == "CPI"
    my_data.CPI4 = []; my_data.CPI5 = []; my_data.CPI6 = []; my_data.CPIA = []; my_data.CPIB = []; my_data.CPIC = []; 
elseif my_variable == "INDPROD"
    my_data.INDPROD4 = []; my_data.INDPROD5 = []; my_data.INDPROD6 = []; my_data.INDPRODA = []; my_data.INDPRODB = [];
elseif my_variable == "RGDP"
    my_data.RGDP4 = []; my_data.RGDP5 = []; my_data.RGDP6 = []; my_data.RGDPA = []; my_data.RGDPB = []; my_data.RGDPC = []; my_data.RGDPD = [];
else
    error("this variable not implemented yet")
end

% Reshape the long SPF data (one row per survey/forecaster) into wide panels.
% Suffix 1 is the previous quarter's realization, 2 the survey-quarter nowcast,
% and 3 the next-quarter forecast; longer horizons are removed above.
%% transform the data for the analysis
% find forecasters present in this period
unique_ids = unique(my_data.ID);
% check how many forecasts each of them delivered
[~,~,idx] = unique(my_data.ID);
counts = accumarray(idx, 1);
id_count_table = table(unique_ids, counts, ...
    'VariableNames', {'ID','NumObservations'});

idx = (counts >= T_threshold);          % logical index
selected_ids = unique_ids(idx);
selected_counts = counts(idx);
selected_table = table(selected_ids, selected_counts, ...
    'VariableNames', {'ID','NumObservations'});

% The realization is repeated across individual records. The cross-sectional
% median summarizes the available copies for each survey quarter.
%% create table with actuals
% 1. Keep only rows with selected_ids
idx = ismember(my_data.ID, selected_ids);
tmp = my_data(idx, :);

% 2. Keep only the variables needed
tmp = tmp(:, {'YEAR','QUARTER','ID',char(my_variable + '1')});

% (optional) sort by time then ID
tmp = sortrows(tmp, {'YEAR','QUARTER','ID'});

% 3. Unstack so that:
%    - rows = (YEAR, QUARTER)
%    - columns = IDs
%    - cells = UNEMP1
my_pdata_actual = unstack(tmp, char(my_variable + '1'), 'ID');

% add median
% Identify all ID columns (all columns except YEAR and QUARTER)
id_cols = my_pdata_actual(:, setdiff(my_pdata_actual.Properties.VariableNames, {'YEAR','QUARTER'}));

% Compute row-wise median, ignoring missing values
med_values = median(table2array(id_cols), 2, 'omitnan');

% Add the new column
my_pdata_actual.MEDIAN = med_values;

% Retain a nowcast panel for inspection; its mean does not enter the
% combination/regression calculations below.
%% create table with nowcast
% 1. Keep only rows with selected_ids
idx = ismember(my_data.ID, selected_ids);
tmp = my_data(idx, :);

% 2. Keep only variables needed
tmp = tmp(:, {'YEAR','QUARTER','ID',char(my_variable + '2')});

% (optional) sort by time then ID
tmp = sortrows(tmp, {'YEAR','QUARTER','ID'});

% 3. Unstack to create time × ID wide table
my_pdata_nowcast = unstack(tmp, char(my_variable + '2'), 'ID');

% 4. Identify ID columns (ignore YEAR and QUARTER)
id_cols = my_pdata_nowcast(:, setdiff(my_pdata_nowcast.Properties.VariableNames, {'YEAR','QUARTER'}));

% 5. Compute mean across IDs (row-wise)
mean_values = mean(table2array(id_cols), 2, 'omitnan');

% 6. Add mean column
my_pdata_nowcast.MEAN = mean_values;

% The mean is computed from available reports before regression imputation.
% It is not recomputed from X_imp, so it preserves the original benchmark.
%% create table with forecasts
% 1. Keep only rows with selected_ids
idx = ismember(my_data.ID, selected_ids);
tmp = my_data(idx, :);

% 2. Keep only variables needed
tmp = tmp(:, {'YEAR','QUARTER','ID',char(my_variable + '3')});

% (optional) sort by time then ID
tmp = sortrows(tmp, {'YEAR','QUARTER','ID'});

% 3. Unstack to create time × ID wide table
my_pdata_forecast = unstack(tmp, char(my_variable + '3'), 'ID');

% 4. Identify ID columns (ignore YEAR and QUARTER)
id_cols = my_pdata_forecast(:, setdiff(my_pdata_forecast.Properties.VariableNames, {'YEAR','QUARTER'}));

% 5. Compute row-wise mean across IDs
mean_values = mean(table2array(id_cols), 2, 'omitnan');

% 6. Add mean column
my_pdata_forecast.MEAN = mean_values;

% Target-quarter alignment: move suffix-3 forecasts forward one row and
% suffix-1 realizations backward one row. The first forecast and the last
% actual are consequently unavailable. Row shifts assume consecutive quarters.
%% create alligned table with forecast and actuals
% Copy original table
my_pdata_fcst_aligned = my_pdata_forecast;

% Identify columns to shift (all except YEAR and QUARTER)
cols_to_shift = setdiff(my_pdata_fcst_aligned.Properties.VariableNames, {'YEAR','QUARTER'});

% Extract as array
A = table2array(my_pdata_fcst_aligned(:, cols_to_shift));

% Shift down: first row becomes NaN
A_shifted = [nan(1, size(A,2)); A(1:end-1, :)];

% Replace the shifted columns
my_pdata_fcst_aligned(:, cols_to_shift) = array2table(A_shifted, ...
    'VariableNames', cols_to_shift);

% add actual
my_pdata_fcst_aligned.ACTUAL = [my_pdata_actual.MEDIAN(2:end); NaN];


%% plot the data

% Construct proper quarterly datetime
t = datetime(my_pdata_fcst_aligned.YEAR, 1, 1) + ...
    calquarters(my_pdata_fcst_aligned.QUARTER - 1);
t.Format = "yQQQ";

% Add it to the table
my_pdata_fcst_aligned.Time = t;

% Move Time to the first column (optional)
my_pdata_fcst_aligned = movevars(my_pdata_fcst_aligned, 'Time', 'Before', 1);

% Convert to timetable
my_pdata_fcst_aligned_TT = table2timetable(my_pdata_fcst_aligned, 'RowTimes', 'Time');

actual_col = 'ACTUAL';

forecast_cols = setdiff(my_pdata_fcst_aligned_TT.Properties.VariableNames, ...
                        {'YEAR','QUARTER','ACTUAL','Time'});

%figure; hold on;
scrsz = get(0,'ScreenSize'); 
gcf = figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(4)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]

% Forecasts as colored points
for j = 1:length(forecast_cols)
    plot(my_pdata_fcst_aligned_TT.Time, my_pdata_fcst_aligned_TT.(forecast_cols{j}), 'gx', 'MarkerSize', 3);
end

% Actual line
plot(my_pdata_fcst_aligned_TT.Time, my_pdata_fcst_aligned_TT.(actual_col), 'b-', 'LineWidth', 2);

xlabel('Time');
%ylabel('Unemployment');
%title('Actual vs Forecasts (Aligned Panel)');
grid on;

hold off;
file_out = fullfile(output_dir, 'fig-' + my_variable + '.pdf');

% Preserve the original plot-only mode, including its deliberate early stop.
if my_period == 3
    %exportgraphics(gcf,file_out,'ContentType','vector');
    error("Figure is done, the rest is not implemented for this period")
end


%% create forecast error timetable
errors_TT = my_pdata_fcst_aligned_TT;   % start with same structure

actual_col = 'ACTUAL';

% Identify forecast columns (same logic as in the plotting section)
forecast_cols = setdiff(my_pdata_fcst_aligned_TT.Properties.VariableNames, ...
                        {'YEAR','QUARTER','ACTUAL','Time'});

% For each forecast column: error = actual – forecast
for j = 1:length(forecast_cols)
    fc_col = forecast_cols{j};
    err_col = ['ERR_' fc_col];          % name of the new column
    errors_TT.(err_col) = errors_TT.(actual_col) - errors_TT.(fc_col);
end

% Remove the old forecast levels if you want to keep only errors
% (comment out if you want to keep originals)
errors_TT(:, forecast_cols) = [];    

% The result:
my_pdata_fcst_errors_TT = errors_TT;

%% plot forecast errors

figure; hold on;

% --- Plot ERR_MEAN as thick line ---
plot(my_pdata_fcst_errors_TT.Time, ...
     my_pdata_fcst_errors_TT.ERR_MEAN, ...
     'k-', 'LineWidth', 2);

% Identify all other error columns
error_cols = setdiff(my_pdata_fcst_errors_TT.Properties.VariableNames, ...
                     {'YEAR','QUARTER','ACTUAL','ERR_MEAN'});

% --- Plot all other errors as x-marks ---
for j = 1:length(error_cols)
    plot(my_pdata_fcst_errors_TT.Time, ...
         my_pdata_fcst_errors_TT.(error_cols{j}), ...
         'x', 'MarkerSize', 6);
end

xlabel('Time');
ylabel('Forecast error (Actual - Forecast)');
title('Forecast Errors: Mean vs Individual Forecasters');
grid on;

hold off;

%% autocorrelation of ERR_MEAN

%err_mean = my_pdata_fcst_errors_TT.ERR_MEAN;

%figure;
%autocorr(err_mean, 'NumLags', 12);   % 12 lags (3 years of quarters)
%title('Autocorrelation of ERR\_MEAN');

% Mean correction: error(t) becomes error(t)-gamma*error(t-1).
% Set the next fixed coefficient to 0.5 or 0.65 for the corresponding paper row.
% The unrestricted full-sample optimizer below is diagnostic only.
%% correct the mean forecast
corr_factor_fixed = 0.65; % for the table use 0.5 or 0.65 (close to optimal)
fun = @(x)sum((my_pdata_fcst_errors_TT.ERR_MEAN(2:end) - x * my_pdata_fcst_errors_TT.ERR_MEAN(1:end-1)).^2,'omitnan'); % MSE of corrected residuals
[corr_factor_opt,fval] = fminunc(fun,corr_factor_fixed);
corr_factor = corr_factor_fixed;
my_pdata_fcst_errors_TT.ERR_MEAN_CORR_F = [NaN; my_pdata_fcst_errors_TT.ERR_MEAN(2:end) - corr_factor * my_pdata_fcst_errors_TT.ERR_MEAN(1:end-1)];
% use the first error without correction to allign the number of observation in ERR_MEAN and ERR_MEAN_CORR
my_pdata_fcst_errors_TT.ERR_MEAN_CORR_F(2) = my_pdata_fcst_errors_TT.ERR_MEAN(2);
% compute historically optimal correction factor
err_mean = my_pdata_fcst_errors_TT.ERR_MEAN;
err_mean_corr_HO = err_mean * NaN; % preallocation
rho_old = 0.5; % inital value
% Estimate the mean correction from pairs ending at t-1. Earlier entries
% of err_mean_corr_HO remain NaN, rather than receiving a fixed warm-up.
for t = T_out_start:size(err_mean,1)
   fun = @(x)sum((err_mean(2+1:t-1) - x * err_mean(1+1:t-1-1)).^2,"omitnan");
   [rho_opt,fval] = fminunc(fun,rho_old);
   rho_old = rho_opt;
   err_mean_corr_HO(t,1) = err_mean(t) - rho_opt * err_mean(t-1);
end
my_pdata_fcst_errors_TT.ERR_MEAN_CORR_HO = err_mean_corr_HO;

%% autocorrelation of ERR_MEAN before and after correction

scrsz = get(0,'ScreenSize'); 
gcf=figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(4)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]
subplot(1,2,1); 
autocorr(my_pdata_fcst_errors_TT.ERR_MEAN, 'NumLags', 12);   % 12 lags (3 years of quarters)
title('Autocorrelation of ERR\_MEAN');
subplot(1,2,2);
autocorr(my_pdata_fcst_errors_TT.ERR_MEAN_CORR_F, 'NumLags', 12);   % 12 lags (3 years of quarters)
title('Autocorrelation of ERR\_MEAN\_CORR');
%file_out = fullfile(output_dir, 'fig-autocorr-mean.pdf');
file_out = fullfile(output_dir, 'fig-autocorr-mean-corr.pdf');
%exportgraphics(gcf,file_out,'ContentType','vector'); % export one plot at the time, latex does subplots

%% in sample optimal combination
%% Restricted regression: ACTUAL on individual forecasts with sum(weights)=1

TT = my_pdata_fcst_aligned_TT;

% --- Identify individual forecast columns (exclude YEAR, QUARTER, Time, ACTUAL, MEAN)
exclude = {'YEAR','QUARTER','Time','ACTUAL','MEAN'};
fcst_cols = setdiff(TT.Properties.VariableNames, exclude);

% --- Construct Y and X
Y = TT.ACTUAL;
X = TT{:, fcst_cols};      % matrix T × N
[T, N] = size(X);
% Preserve missing individual reports for correct-then-combine. Filling
% these values would change both its estimation samples and averaging set.
X_raw = X;                 % preserve reported forecasts for Clements corrections

% impute missing observations 
% Y = ACTUAL (T×1), X = individual forecasts (T×N)
% Some entries in X can be NaN because certain forecasters missed a quarter.

X_imp = X;    % start from original X


% Imputation is done only for the combination regressions. With imp_type=2,
% the first usable row receives a contemporaneous mean fill, then each later
% missing entry receives the preceding (possibly already imputed) forecast.
if imp_type == 1
    % We impute missing X_ij by the cross-sectional mean of that row.
    for t = 1:T
        row = X_imp(t,:);
        m = mean(row, 'omitnan');     % mean of available forecasts at time t
        if isnan(m)
            % if all are NaN (should not happen except possibly last row), skip
            continue
        end
        row(isnan(row)) = m;          % replace NaN with row mean
        X_imp(t,:) = row;
    end
elseif imp_type == 2
    row = X_imp(2,:); % impute the second row with the mean as before
    m = mean(row, 'omitnan');
    row(isnan(row)) = m;
    X_imp(2,:) = row;
    for t = 3:T % impute everything else with the previous available forecast
        row = X_imp(t,:);
        row(isnan(row)) = X_imp(t-1,isnan(row));
        X_imp(t,:) = row;
    end
end
X = X_imp; 

% Remove rows with missing data
% Keep complete regression rows and remember their positions for reinsertion
% into the quarterly timetable. Subsequent regression loop indices refer to
% these retained rows, not the original timetable row numbers.
valid = all(~isnan([Y X]), 2);
Y = Y(valid);
X = X(valid, :);
X_raw = X_raw(valid, :);

% --- Build restricted regression with in-sample optimal weights
% Minimize:  (Y - Xw)'(Y - Xw)   subject to:  sum(w) = 1
% quadprog uses 0.5*w'*H*w + f'*w. H and f below give the original OLS
% sum of squared errors up to the constant Y'*Y. There are no weight bounds.
Aeq = ones(1, N);
beq = 1;

% OLS objective
H = 2 * (X' * X);
f = -2 * (X' * Y);

% Solve quadratic program
options = optimoptions('quadprog','Display','off');
w_hat = quadprog(H, f, [], [], Aeq, beq, [], [], [], options);

% --- Compute fitted values
fitted = X * w_hat; % in-sample optimal forecast

% Restriction -1 <= rho <= 1
options1 = optimoptions(@fmincon,'Algorithm','sqp','Display','off');
% Joint GLS parameters contain N-1 free weights followed by rho. The last
% weight is reconstructed as 1-sum(other weights). These two inequalities
% constrain only rho, with inclusive bounds -1 <= rho <= 1.
Aineq = [zeros(1,N-1),1;zeros(1,N-1),-1];
bineq = [1;1];

% ---- OUT-OF-SAMPLE
% Recursive forecasts are left missing before the estimation start. The
% histories below retain v04's original T-row allocation, so any unused tail
% rows remain NaN when initial/final observations were removed by valid.
% fitted_out_GLS2 is an unused placeholder retained from v04.
fitted_out = fitted * NaN; % preallocation
fitted_out_corr = fitted_out;
fitted_out_GLS1 = fitted_out;
fitted_out_GLS2 = fitted_out;
fitted_out_CR4 = fitted_out;
fitted_out_CR5 = fitted_out;
fitted_out_CLEM_CTC_MEAN = fitted_out;
w_hat_GLS_set = NaN(T,N);
rho_opt_GLS_set = NaN(T,1);
beta_hat_CR4_set = NaN(T,N+2); % intercept, N forecast coefficients, lagged-actual coefficient
beta_hat_CR5_set = NaN(T,N+1); % intercept and N forecasted-change coefficients
X_corr_CLEM = NaN(size(X_raw)); % real-time efficiency-corrected individual forecasts
delta0_CLEM_set = NaN(size(X_raw));
delta1_CLEM_set = NaN(size(X_raw));

rho_old = 0.5; % initial value for optimization of correction factor
rho_opt_set = NaN(T,1);
%fitted_out(1:T_out_start-1,:) = mean(X(1:T_out_start-1,:),2); % use mean to warm up the start of regression
% Expanding-window estimation: train on retained rows 1:t-1 and forecast t.
% The same loop produces OLS, corrected OLS, GLS and the three benchmarks.
for t = T_out_start:size(X,1) 
    H = 2 * (X(1:t-1,:)' * X(1:t-1,:));
    f = -2 * (X(1:t-1,:)' * Y(1:t-1,:));
    w_hat = quadprog(H, f, [], [], Aeq, beq, [], [], [], options);
    fitted_out(t,:) = X(t,:) * w_hat;
    % I can add the optimization for the correction factor here, so the
    % weights and correction are done out of sample:
    %fitted_resid = Y(1:t-1,:) - X(1:t-1,:) * w_hat; % residual using optimal weights for current period
    % Use errors of previously issued combinations. Initial NaNs are ignored
    % in the objective; do not replace them by in-sample fitted residuals.
    fitted_resid = Y(1:t-1,:) - fitted_out(1:t-1); % it's better to use optimal forecasts from previous periods
    fun = @(x)sum((fitted_resid(2:end) - x * fitted_resid(1:end-1)).^2,'omitnan'); % MSE of corrected residuals
    %[rho_opt,fval] = fminunc(fun,rho_old);
    [rho_opt,fval] = fmincon(fun,rho_old,[],[],[],[],-1,1,[],options1); % restriction -1 <= rho <= 1
    %rho_opt = 0.5; % try fixed correcton factor; not very eligant way to do it but quick
    rho_old = rho_opt;
    rho_opt_set(t) = rho_opt;
    %fitted_out_corr(t,:) = fitted_out(t,:) + rho_opt * fitted_resid(end); % corrected optimal forecast
    % No prior recursive-combination error is available at the first
    % forecast, so keep that OLS forecast uncorrected.
    if t == T_out_start % 
        fitted_out_corr(t,:) = fitted_out(t,:); % nothing to use for correction yet
    else
        fitted_out_corr(t,:) = fitted_out(t,:) + rho_opt * fitted_resid(end); % corrected optimal forecast
    end
    
    % GLS: new structure; see notes from 15/12/2025
    % Jointly fit the combination and AR coefficient on historical data.
    % Unlike the corrected OLS step, this forecast uses the last historical
    % residual evaluated at the newly fitted GLS weights.
    fun_GLS = @(x)GLS(Y(1:t-1,:),X(1:t-1,:),x);
    x0 = [w_hat(1:end-1); rho_opt]; % program restriction sum(w)=1 into the function via the last weight = 1 - other weights
    %[x_opt,fval] = fminunc(fun_GLS,x0);
    [x_opt,fval] = fmincon(fun_GLS,x0, Aineq, bineq, [], [], [], [], [], options1); % restriction -1 <= rho <= 1
    w_hat_GLS = x_opt(1:end-1);
    w_hat_GLS = [w_hat_GLS; 1-sum(w_hat_GLS)]; % last weight is 1 - other weights
    rho_opt_GLS = x_opt(end);
    w_hat_GLS_set(t,:) = w_hat_GLS';
    rho_opt_GLS_set(t) = rho_opt_GLS;
    fitted_resid_GLS = Y(1:t-1,:) - X(1:t-1,:) * w_hat_GLS;
    fitted_out_GLS1(t,:) = X(t,:) * w_hat_GLS + rho_opt_GLS * fitted_resid_GLS(end); % correction with the last forecasting error

    % Coulson and Robins (1993), method (4): unrestricted dynamic
    % combination with an intercept and the lagged actual, but without
    % lagged individual forecasts:
    % Y(s) = beta_0 + X(s,:) * beta + beta_y * Y(s-1) + u(s).
    % The intercept and lagged actual are unrestricted. The first training
    % observation is lost to lagging, and no sum-to-one constraint is applied.
    Z_CR4 = [ones(t-2,1), X(2:t-1,:), Y(1:t-2,:)];
    beta_hat_CR4 = Z_CR4 \ Y(2:t-1,:);
    beta_hat_CR4_set(t,:) = beta_hat_CR4';
    fitted_out_CR4(t,:) = [1, X(t,:), Y(t-1,:)] * beta_hat_CR4;

    % Coulson and Robins (1993), method (5): error-correction form
    % estimated using changes in the actual and forecasted changes:
    % Y(s)-Y(s-1) = beta_0 + (X(s,:)-Y(s-1)) * beta + u(s).
    % Fit the change equation by ordinary least squares, then add the
    % previous actual back to produce a forecast in levels.
    delta_Y_CR5 = Y(2:t-1,:) - Y(1:t-2,:);
    Z_CR5 = [ones(t-2,1), X(2:t-1,:) - Y(1:t-2,:)];
    beta_hat_CR5 = Z_CR5 \ delta_Y_CR5;
    beta_hat_CR5_set(t,:) = beta_hat_CR5';
    fitted_out_CR5(t,:) = Y(t-1,:) + ...
        [1, X(t,:) - Y(t-1,:)] * beta_hat_CR5;

    % Clements (2022) correct-then-combine approach. For every individual
    % forecaster, recursively estimate the Mincer-Zarnowitz regression
    % Y(s) = delta_0 + delta_1 * X_i(s) + u_i(s) using reported forecasts
    % observed through t-1. Correct the current individual forecasts first,
    % then combine them using equal weights. If fewer than Clements_n_min
    % historical observations are available, retain the reported forecast.
    % Missing current reports remain missing; the final mean ignores them.
    % With insufficient history, keep the individual's reported forecast.
    for i = 1:N
        if isnan(X_raw(t,i))
            continue
        end

        X_hist_CLEM = X_raw(1:t-1,i);
        Y_hist_CLEM = Y(1:t-1,:);
        valid_CLEM = ~isnan(X_hist_CLEM) & ~isnan(Y_hist_CLEM);
        if sum(valid_CLEM) >= Clements_n_min
            Z_CLEM = [ones(sum(valid_CLEM),1), X_hist_CLEM(valid_CLEM)];
            delta_hat_CLEM = Z_CLEM \ Y_hist_CLEM(valid_CLEM);
            delta0_CLEM_set(t,i) = delta_hat_CLEM(1);
            delta1_CLEM_set(t,i) = delta_hat_CLEM(2);
            X_corr_CLEM(t,i) = [1, X_raw(t,i)] * delta_hat_CLEM;
        else
            X_corr_CLEM(t,i) = X_raw(t,i);
        end
    end
    fitted_out_CLEM_CTC_MEAN(t,:) = mean(X_corr_CLEM(t,:), 'omitnan');
 
end

% --- look at the historically optimal correction factor

figure; 
subplot(2,1,1);
plot(rho_opt_set);
title('rho\_opt\_set');
subplot(2,1,2);
plot(rho_opt_GLS_set);
title('rho\_opt\_GLS\_set');

% Restore the original quarterly index after complete-row filtering.
% ERR_ columns below always use actual minus the corresponding forecast.
% --- Insert fitted values back into timetable
my_pdata_fcst_aligned_TT.REGR_IN = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.REGR_OUT = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.REGR_OUT_CORR_HO = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.REGR_GLS = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.REGR_CR4 = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.REGR_CR5 = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.CLEM_CTC_MEAN = NaN(height(my_pdata_fcst_aligned_TT), 1);

my_pdata_fcst_aligned_TT.REGR_IN(valid) = fitted; % in-sample
my_pdata_fcst_aligned_TT.REGR_OUT(valid) = fitted_out; % out-of-sample
my_pdata_fcst_aligned_TT.REGR_OUT_CORR_HO(valid) = fitted_out_corr; % out-of-sample and corrected
my_pdata_fcst_aligned_TT.REGR_GLS(valid) = fitted_out_GLS1; % GLS procedure
my_pdata_fcst_aligned_TT.REGR_CR4(valid) = fitted_out_CR4; % Coulson and Robins (1993), method (4)
my_pdata_fcst_aligned_TT.REGR_CR5(valid) = fitted_out_CR5; % Coulson and Robins (1993), method (5)
my_pdata_fcst_aligned_TT.CLEM_CTC_MEAN(valid) = fitted_out_CLEM_CTC_MEAN; % correct individual forecasts, then average


% Display weights
%disp('Estimated weights (sum to 1):');
%disp(table(fcst_cols', w_hat, 'VariableNames', {'Forecaster','Weight'}));

my_pdata_fcst_errors_TT.ERR_REGR_IN = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_IN;
my_pdata_fcst_errors_TT.ERR_REGR_OUT = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_OUT;
my_pdata_fcst_errors_TT.ERR_REGR_OUT_CORR_HO = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_OUT_CORR_HO;
my_pdata_fcst_errors_TT.ERR_REGR_GLS = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_GLS;
my_pdata_fcst_errors_TT.ERR_REGR_CR4 = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_CR4;
my_pdata_fcst_errors_TT.ERR_REGR_CR5 = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_CR5;
my_pdata_fcst_errors_TT.ERR_CLEM_CTC_MEAN = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.CLEM_CTC_MEAN;

% check autocorrelation from regressions
scrsz = get(0,'ScreenSize'); 
gcf=figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(4)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]
subplot(2,2,1);
autocorr(my_pdata_fcst_errors_TT.ERR_REGR_IN, 'NumLags', 12);   % 12 lags (3 years of quarters)
title('Autocorrelation of ERR\_REGR\_IN');
subplot(2,2,2);
autocorr(my_pdata_fcst_errors_TT.ERR_REGR_OUT, 'NumLags', 12);   % 12 lags (3 years of quarters)
title('Autocorrelation of ERR\_REGR\_OUT');
subplot(2,2,3);
autocorr(my_pdata_fcst_errors_TT.ERR_REGR_OUT_CORR_HO, 'NumLags', 12);   % 12 lags (3 years of quarters)
title('Autocorrelation of ERR\_REGR\_OUT\_CORR');
subplot(2,2,4);
autocorr(my_pdata_fcst_errors_TT.ERR_REGR_GLS, 'NumLags', 12);   % 12 lags (3 years of quarters)
title('Autocorrelation of ERR\_REGR\_GLS');
%file_out = fullfile(output_dir, 'fig-autocorr-regr.pdf');
%file_out = fullfile(output_dir, 'fig-autocorr-GLS.pdf');
%exportgraphics(gcf,file_out,'ContentType','vector'); % export one plot at the time, latex does subplots

% Sample autocorrelation functions for the additional benchmark methods.
% Use the same evaluation window as the MSFE calculations below.
% These benchmark ACFs use the same starting row as the MSE table and
% remove missing values before autocorr. Other diagnostic ACFs above retain
% their v04 inputs and are not changed to this evaluation window.
acf_CR4 = my_pdata_fcst_errors_TT.ERR_REGR_CR4(T_out_start+1:end);
acf_CR4 = acf_CR4(~isnan(acf_CR4));
acf_CR5 = my_pdata_fcst_errors_TT.ERR_REGR_CR5(T_out_start+1:end);
acf_CR5 = acf_CR5(~isnan(acf_CR5));
acf_CLEM_CTC = my_pdata_fcst_errors_TT.ERR_CLEM_CTC_MEAN(T_out_start+1:end);
acf_CLEM_CTC = acf_CLEM_CTC(~isnan(acf_CLEM_CTC));

gcf_new_methods = figure('PaperPositionMode','auto', ...
    'Position',[scrsz(3)/20 scrsz(4)/2 3*scrsz(3)/4 scrsz(4)/3], ...
    'PaperOrientation','landscape');
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

nexttile;
autocorr(acf_CR4, 'NumLags', 12); % 12 lags (3 years of quarters)
title('Coulson and Robins method (4)');

nexttile;
autocorr(acf_CR5, 'NumLags', 12); % 12 lags (3 years of quarters)
title('Coulson and Robins method (5)');

nexttile;
autocorr(acf_CLEM_CTC, 'NumLags', 12); % 12 lags (3 years of quarters)
title('Clements correct-then-combine');

sgtitle('Sample autocorrelation functions: additional benchmarks');
%file_out = fullfile(output_dir, 'fig-autocorr-new-methods.pdf');
%exportgraphics(gcf_new_methods,file_out,'ContentType','vector');


% Fixed OLS corrections: the in-sample coefficient is 0.15; change the
% recursive OLS fixed coefficient below from 0.5 to 0.7 for its extra paper row.
% Both calculations execute because the original if/else guards are comments.
%% correct the optimal (regression) forecast REGR_IN or REGR_OUT

%if in_out_sample == 1
    corr_factor = 0.15; % works for in-sample regr forecast
    my_pdata_fcst_errors_TT.ERR_REGR_IN_CORR_F = [NaN; my_pdata_fcst_errors_TT.ERR_REGR_IN(2:end) - corr_factor * my_pdata_fcst_errors_TT.ERR_REGR_IN(1:end-1)];
%else
    corr_factor_fixed = 0.5; % 0.7 and 0.5 used for the paper
    fun = @(x)sum((my_pdata_fcst_errors_TT.ERR_REGR_OUT(2:end) - x * my_pdata_fcst_errors_TT.ERR_REGR_OUT(1:end-1)).^2,'omitnan'); % MSE of corrected residuals
    [corr_factor_opt,fval] = fminunc(fun,corr_factor_fixed);
    corr_factor = corr_factor_fixed; % 0.7 and 0.5 used for the paper
    % correction
    my_pdata_fcst_errors_TT.ERR_REGR_OUT_CORR_F = [NaN; my_pdata_fcst_errors_TT.ERR_REGR_OUT(2:end) - corr_factor * my_pdata_fcst_errors_TT.ERR_REGR_OUT(1:end-1)];
%end


% use the first error without correction to allign the number of observation in ERR_MEAN and ERR_MEAN_CORR
%if in_out_sample == 1
    my_pdata_fcst_errors_TT.ERR_REGR_IN_CORR_F(2) = my_pdata_fcst_errors_TT.ERR_REGR_IN(2); % in-sample
%else
    my_pdata_fcst_errors_TT.ERR_REGR_OUT_CORR_F(T_out_start+1) = my_pdata_fcst_errors_TT.ERR_REGR_OUT(T_out_start+1); % out-of-sample
%end

% A common start row is imposed, but missing errors are omitted separately
% for each series. This is the inherited evaluation rule, not an intersection
% of complete observations across all methods. Keep MSE for full precision.
%% Compute Mean Squared Errors (MSE) for all error columns

% Identify error columns (anything starting with ERR_)
err_cols = startsWith(my_pdata_fcst_errors_TT.Properties.VariableNames, 'ERR_');
error_varnames = my_pdata_fcst_errors_TT.Properties.VariableNames(err_cols);

% Prepare output MSE table
MSE = table('Size',[length(error_varnames) 3], ...
            'VariableTypes', {'string','double','double'}, ...
            'VariableNames', {'ErrorSeries','MSFE','rMSFE'});

% Compute MSE for each column
for j = 1:length(error_varnames)
    col = error_varnames{j};
    err = my_pdata_fcst_errors_TT.(col);
    err = err(T_out_start+1:end); % to allign evaluation window for all forecasts, see Chu-An's email 16/12/2025
                                  % one observation lost because of 'valid'

    % MSE = mean(error^2), omitting NaN
    mse_val = mean(err.^2, 'omitnan'); 

    MSE.ErrorSeries(j) = col;
    MSE.MSFE(j) = mse_val;
    MSE.rMSFE(j) = MSE.MSFE(j)/MSE.MSFE(1);
end

% Display the result
disp('Mean Squared Errors for all forecast errors:');
%disp(MSE);
% MSE.MSE(end)/MSE.MSE(1) % ratio of corr mean fcst err to mean fcst err
% round the numbers for the table 
MSE_print = MSE;                          % keep original numeric table intact
MSE_print.MSFE  = round(MSE_print.MSFE,  4);
MSE_print.rMSFE = round(MSE_print.rMSFE, 4);

disp(MSE_print);


%% functions

% The GLS objective quasi-differences adjacent errors; it drops the initial
% observation rather than including a stationary initial-error likelihood.
% The commented MA(1) objective below is an inactive historical alternative.
function GLS_SSR = GLS(Y,X,x)

w = x(1:end-1);
w = [w; 1 - sum(w)]; % restriction that all weights sum up to 1
phi = x(end);

N   = size(Y,1);      % matrix size

% MA(1) structure
%Omega = diag(ones(N,1)) + phi*diag(ones(N-1,1),1) + phi*diag(ones(N-1,1),-1);
%GLS_SSR = (Y - X * w)' * inv(Omega) * (Y - X * w);

% structure from my notes 15/12/2025
Y_d = Y(2:end) - phi * Y(1:end-1);
X_d = X(2:end,:) - phi * X(1:end-1,:);
GLS_SSR = (Y_d - X_d * w)' * (Y_d - X_d * w);

end


function data_file = find_data_file(script_dir)
% Prefer the standalone GitHub layout, then the original research layout.
candidates = [string(fullfile(script_dir, 'Individual_forecast.xlsx')); ...
    string(fullfile(script_dir, '..', 'Data', 'US_SPF', 'Individual_forecast.xlsx'))];
found = find(isfile(candidates),1);
if isempty(found)
    error('USSPF:MissingData', ...
        'Place Individual_forecast.xlsx beside this script or in ../Data/US_SPF.');
end
data_file = candidates(found);
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
%  Result = importfile("Individual_forecast.xlsx", "UNEMP", [2, Inf]);
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
opts = spreadsheetImportOptions("NumVariables", 14);

% Specify sheet and range
opts.Sheet = sheetName;
if lastRowOfDataIdx == 1
    opts.DataRange = "A" + dataLines(1, 1);
else
    opts.DataRange = "A" + dataLines(1, 1) + ":L" + dataLines(1, 2);
end

% Specify column names and types
if sheetName == "UNEMP"
    opts.VariableNames = ["YEAR", "QUARTER", "ID", "INDUSTRY", "UNEMP1", "UNEMP2", "UNEMP3", "UNEMP4", "UNEMP5", "UNEMP6", "UNEMPA", "UNEMPB", "UNEMPC", "UNEMPD"];
    opts.VariableTypes = ["double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
    % Specify variable properties
    opts = setvaropts(opts, ["UNEMPC", "UNEMPD"], "EmptyFieldRule", "auto");
elseif sheetName == "CPI"
    opts.VariableNames = ["YEAR", "QUARTER", "ID", "INDUSTRY", "CPI1", "CPI2", "CPI3", "CPI4", "CPI5", "CPI6", "CPIA", "CPIB", "CPIC"];
    opts.VariableTypes = ["double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
    % Specify variable properties
    opts = setvaropts(opts, ["CPIC"], "EmptyFieldRule", "auto");
elseif sheetName == "INDPROD"
    opts.VariableNames = ["YEAR", "QUARTER", "ID", "INDUSTRY", "INDPROD1", "INDPROD2", "INDPROD3", "INDPROD4", "INDPROD5", "INDPROD6", "INDPRODA", "INDPRODB"];
    opts.VariableTypes = ["double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
elseif sheetName == "RGDP"
    opts.VariableNames = ["YEAR", "QUARTER", "ID", "INDUSTRY", "RGDP1", "RGDP2", "RGDP3", "RGDP4", "RGDP5", "RGDP6", "RGDPA", "RGDPB", "RGDPC", "RGDPD"];
    opts.VariableTypes = ["double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
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
