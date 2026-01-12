%% script to correct the opimal US SPF forecast
%  v02 implements GLS from my notes 15/12/2025
%  v03 added restriction -1 < optimal historical correction factor < 1 (Chu_An's email 29/12/2025)
%  change fixed weight in line 270 for mean fcst correction, in line 460 for optimal weight forecast correction

clear all
close all

% import the data 
my_variable = "UNEMP"; % "UNEMP", "CPI" or "INDPROD" or "RGDP"
                       % optimal weight code only checked for UNEMP, 
                       % other variables only the first graph is saved, the rest needs checks
path = "/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Data/US_SPF/"; % MacBook
%path = "C:\Users\avasnev\Sydney Uni Dropbox\Andrey Vasnev\Research\2025\GLS project\Data\US_SPF\"; % office PC
my_data = importfile(fullfile(path, "Individual_forecast.xlsx"), my_variable, [2, Inf]);

% collect all branching variables here
in_out_sample = 4; % 1 for in-sample, 
                   % 2 for out-of-sample optimal weight computed via restricted regression
                   % 3 for out-of-sample and corrected at the same time
                   % 4 GLS
                   % now it only matters if this param is 1 or not
my_period = 2; % 1 for before GFC, 2 for before COVID
imp_type = 2; % imputation type to balance the panel: 
              % 1 - mean of other forecasters
              % 2 - previous observed forecast

if my_period == 1
    % 2000-2008 before GFC
    my_data = my_data(my_data.YEAR >= 2000 & my_data.YEAR <= 2008, :);
    T_threshold = 30; % minimum number of forecasts
    % 2000-2008 has 9*4=36 observations, 16.7% missing allowed
else
    % or 2000-2019 before COVID
    my_data = my_data(my_data.YEAR >= 2000 & my_data.YEAR <= 2019, :);
    T_threshold = 70; % 20*4=80, 12.5% missing allowed
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

% Actual line
plot(my_pdata_fcst_aligned_TT.Time, my_pdata_fcst_aligned_TT.(actual_col), 'b-', 'LineWidth', 3);

% Forecasts as colored points
for j = 1:length(forecast_cols)
    plot(my_pdata_fcst_aligned_TT.Time, my_pdata_fcst_aligned_TT.(forecast_cols{j}), 'kx', 'MarkerSize', 6);
end

xlabel('Time');
%ylabel('Unemployment');
%title('Actual vs Forecasts (Aligned Panel)');
grid on;

hold off;
file_out = '/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Draft/fig-' + my_variable + '.pdf';
%exportgraphics(gcf,file_out,'ContentType','vector');


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

%% correct the mean forecast
corr_factor_fixed = 0.65; % for the table use 0.5 or 0.65 (close to optimal)
fun = @(x)sum((my_pdata_fcst_errors_TT.ERR_MEAN(2:end) - x * my_pdata_fcst_errors_TT.ERR_MEAN(1:end-1)).^2,'omitnan'); % MSE of corrected residuals
[corr_factor_opt,fval] = fminunc(fun,corr_factor_fixed);
corr_factor = corr_factor_fixed;
my_pdata_fcst_errors_TT.ERR_MEAN_CORR_F = [NaN; my_pdata_fcst_errors_TT.ERR_MEAN(2:end) - corr_factor * my_pdata_fcst_errors_TT.ERR_MEAN(1:end-1)];
% use the first error without correction to allign the number of observation in ERR_MEAN and ERR_MEAN_CORR
my_pdata_fcst_errors_TT.ERR_MEAN_CORR_F(2) = my_pdata_fcst_errors_TT.ERR_MEAN(2);

%% autocorrelation of ERR_MEAN before and after correction

scrsz = get(0,'ScreenSize'); 
gcf=figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(4)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]
subplot(1,2,1); 
autocorr(my_pdata_fcst_errors_TT.ERR_MEAN, 'NumLags', 12);   % 12 lags (3 years of quarters)
title('Autocorrelation of ERR\_MEAN');
subplot(1,2,2);
autocorr(my_pdata_fcst_errors_TT.ERR_MEAN_CORR_F, 'NumLags', 12);   % 12 lags (3 years of quarters)
title('Autocorrelation of ERR\_MEAN\_CORR');
%file_out = '/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Draft/fig-autocorr-mean.pdf';
file_out = '/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Draft/fig-autocorr-mean-corr.pdf';
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

% impute missing observations 
% Y = ACTUAL (T×1), X = individual forecasts (T×N)
% Some entries in X can be NaN because certain forecasters missed a quarter.

X_imp = X;    % start from original X


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
valid = all(~isnan([Y X]), 2);
Y = Y(valid);
X = X(valid, :);

% --- Build restricted regression with in-sample optimal weights
% Minimize:  (Y - Xw)'(Y - Xw)   subject to:  sum(w) = 1
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

% Restriction -1 < rho < 1
options1 = optimoptions(@fmincon,'Algorithm','sqp','Display','off');
Aineq = [zeros(1,N-1),1;zeros(1,N-1),-1];
bineq = [1;1];

% ---- OUT-OF-SAMPLE
fitted_out = fitted * NaN; % preallocation
fitted_out_corr = fitted_out;
fitted_out_GLS1 = fitted_out;
fitted_out_GLS2 = fitted_out;
w_hat_GLS_set = NaN(T,N);
rho_opt_GLS_set = NaN(T,1);
T_out_start = 25; % start of out-of-sample forecasting
rho_old = 0.5; % initial value for optimization of correction factor
rho_opt_set = NaN(T,1);
%fitted_out(1:T_out_start-1,:) = mean(X(1:T_out_start-1,:),2); % use mean to warm up the start of regression
for t = T_out_start:size(X,1) 
    H = 2 * (X(1:t-1,:)' * X(1:t-1,:));
    f = -2 * (X(1:t-1,:)' * Y(1:t-1,:));
    w_hat = quadprog(H, f, [], [], Aeq, beq, [], [], [], options);
    fitted_out(t,:) = X(t,:) * w_hat;
    % I can add the optimization for the correction factor here, so the
    % weights and correction are done out of sample:
    %fitted_resid = Y(1:t-1,:) - X(1:t-1,:) * w_hat; % residual using optimal weights for current period
    fitted_resid = Y(1:t-1,:) - fitted_out(1:t-1); % it's better to use optimal forecasts from previous periods
    fun = @(x)sum((fitted_resid(2:end) - x * fitted_resid(1:end-1)).^2,'omitnan'); % MSE of corrected residuals
    %[rho_opt,fval] = fminunc(fun,rho_old);
    [rho_opt,fval] = fmincon(fun,rho_old,[],[],[],[],-1,1,[],options1); % restriction -1 < rho < 1
    %rho_opt = 0.5; % try fixed correcton factor; not very eligant way to do it but quick
    rho_old = rho_opt;
    rho_opt_set(t) = rho_opt;
    %fitted_out_corr(t,:) = fitted_out(t,:) + rho_opt * fitted_resid(end); % corrected optimal forecast
    if t == T_out_start % 
        fitted_out_corr(t,:) = fitted_out(t,:); % nothing to use for correction yet
    else
        fitted_out_corr(t,:) = fitted_out(t,:) + rho_opt * fitted_resid(end); % corrected optimal forecast
    end
    
    % GLS: new structure; see notes from 15/12/2025
    fun_GLS = @(x)GLS(Y(1:t-1,:),X(1:t-1,:),x);
    x0 = [w_hat(1:end-1); rho_opt]; % program restriction sum(w)=1 into the function via the last weight = 1 - other weights
    %[x_opt,fval] = fminunc(fun_GLS,x0);
    [x_opt,fval] = fmincon(fun_GLS,x0, Aineq, bineq, [], [], [], [], [], options1); % restriction -1 < rho < 1
    w_hat_GLS = x_opt(1:end-1);
    w_hat_GLS = [w_hat_GLS; 1-sum(w_hat_GLS)]; % last weight is 1 - other weights
    rho_opt_GLS = x_opt(end);
    w_hat_GLS_set(t,:) = w_hat_GLS';
    rho_opt_GLS_set(t) = rho_opt_GLS;
    fitted_resid_GLS = Y(1:t-1,:) - X(1:t-1,:) * w_hat_GLS;
    fitted_out_GLS1(t,:) = X(t,:) * w_hat_GLS + rho_opt_GLS * fitted_resid_GLS(end); % correction with the last forecasting error
 
end

% --- look at the historically optimal correction factor

figure; 
subplot(2,1,1);
plot(rho_opt_set);
title('rho\_opt\_set');
subplot(2,1,2);
plot(rho_opt_GLS_set);
title('rho\_opt\_GLS\_set');

% --- Insert fitted values back into timetable
my_pdata_fcst_aligned_TT.REGR_IN = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.REGR_OUT = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.REGR_OUT_CORR_HO = NaN(height(my_pdata_fcst_aligned_TT), 1);
my_pdata_fcst_aligned_TT.REGR_GLS = NaN(height(my_pdata_fcst_aligned_TT), 1);

my_pdata_fcst_aligned_TT.REGR_IN(valid) = fitted; % in-sample
my_pdata_fcst_aligned_TT.REGR_OUT(valid) = fitted_out; % out-of-sample
my_pdata_fcst_aligned_TT.REGR_OUT_CORR_HO(valid) = fitted_out_corr; % out-of-sample and corrected
my_pdata_fcst_aligned_TT.REGR_GLS(valid) = fitted_out_GLS1; % GLS procedure


% Display weights
%disp('Estimated weights (sum to 1):');
%disp(table(fcst_cols', w_hat, 'VariableNames', {'Forecaster','Weight'}));

my_pdata_fcst_errors_TT.ERR_REGR_IN = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_IN;
my_pdata_fcst_errors_TT.ERR_REGR_OUT = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_OUT;
my_pdata_fcst_errors_TT.ERR_REGR_OUT_CORR_HO = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_OUT_CORR_HO;
my_pdata_fcst_errors_TT.ERR_REGR_GLS = my_pdata_fcst_aligned_TT.ACTUAL - my_pdata_fcst_aligned_TT.REGR_GLS;

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
%file_out = '/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Draft/fig-autocorr-regr.pdf';
%file_out = '/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Draft/fig-autocorr-GLS.pdf';
%exportgraphics(gcf,file_out,'ContentType','vector'); % export one plot at the time, latex does subplots


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

%% TO DO
% 
% 
% 


%% functions

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
%  Result = importfile("/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Data/US_SPF/Result.xlsx", "UNEMP", [2, Inf]);
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