%% script to correct the average US SPF forecast

clear all
close all

% import the data 
my_variable = "UNEMP"; % "UNEMP", "CPI" or "INDPROD" or "RGDP"
my_data = importfile("/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Data/US_SPF/Mean_forecast.xlsx", my_variable, [2, Inf]);
my_year = my_data.YEAR;
my_quarter = my_data.QUARTER;
% alling with the data stamp: each period we have actual, nowcast and forecast
if my_variable == "UNEMP"
    my_data.ACTUAL = [my_data.UNEMP1(2:end); NaN];
    my_data.NOWCAST = my_data.UNEMP2;
    my_data.FORECAST = [NaN; my_data.UNEMP3(1:end-1)];
elseif my_variable == "CPI"
    my_data.ACTUAL = [my_data.CPI1(2:end); NaN];
    my_data.NOWCAST = my_data.CPI2;
    my_data.FORECAST = [NaN; my_data.CPI3(1:end-1)];
elseif my_variable == "INDPROD"
    my_data.ACTUAL = [my_data.INDPROD1(2:end); NaN];
    my_data.NOWCAST = my_data.INDPROD2;
    my_data.FORECAST = [NaN; my_data.INDPROD3(1:end-1)];
elseif my_variable == "RGDP"
    my_data.ACTUAL = [my_data.RGDP1(2:end); NaN];
    my_data.NOWCAST = my_data.RGDP2;
    my_data.FORECAST = [NaN; my_data.RGDP3(1:end-1)];
else
    error("this variable not implemented yet")
end

% Define quarterly dates
%t = datetime(my_year, my_quarter*3 - 1, 15); % ancor the date to middle of the quarter
%t.Format = "yQQQ";
t = datetime(my_year, 1, 1) + calquarters(my_quarter - 1); % alternative
t.Format = "yQQQ";

%y = my_data.UNEMP3; % UNEMP1: quarterly historical value, i.e., actual of the previous quarter
                    % UNEMP2: nowcast of the current quarter
                    % UNEMP3: forecast of the next quarter

% Create a timetable
%TTable = timetable(t, my_data.ACTUAL, my_data.NOWCAST, my_data.FORECAST);
TTable = timetable(t, my_data.ACTUAL, my_data.NOWCAST, my_data.FORECAST, ...
               'VariableNames', {'ACTUAL', 'NOWCAST', 'FORECAST'});

scrsz = get(0,'ScreenSize'); 
gcf = figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(4)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]
plot(TTable.t, TTable.ACTUAL, 'LineWidth', 1); hold on;
%title(my_variable);
plot(TTable.t, TTable.FORECAST, '.')
file_out = '/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Draft/fig-' + my_variable + '.pdf';
%exportgraphics(gcf,file_out,'ContentType','vector');

%% error analysis
TTable.FCST_ERROR = TTable.ACTUAL - TTable.FORECAST; % forecasting error
TTable.NCST_ERROR = TTable.ACTUAL - TTable.NOWCAST;  % nowcasting error
T = size(TTable,1);

time_periods.complete = [3:T-1]; % complete dataset
time_periods.before2000 = [3:125]; % before 2000
time_periods.after2000 = [126:T-1]; % after 2000
time_periods.beforeGFC = [126:161]; % 2000-2008 before GFC
time_periods.beforeCOVID = [126:205]; % 2000-2019 before COVID
time_periods.betweenGFCcovid = [166:205]; % 2010-2019 between GFC and COVID
time_periods.afterCOVID = [214:T-1]; % 2022-2025 after COVID
time_periods.complete_excl_COVID = [3:205 214:T-1]; % exclude COVID due to outliers
time_periods.after2000_excl_COVID = [126:205 214:T-1]; % exclude COVID due to outliers

N_time_periods = numel(fieldnames(time_periods));
names = fieldnames(time_periods);
rho_set = [0:0.1:1]; % different correction factors 
RMSFE = NaN(N_time_periods,length(rho_set)); % preallocation
RMSNE = RMSFE;
for j = 1:length(rho_set)
    TTable.FCST_ERROR_CORRECTED = [NaN; TTable.FCST_ERROR(2:end) - rho_set(j) * TTable.FCST_ERROR(1:end-1)]; % corrected forecast errors
    TTable.NCST_ERROR_CORRECTED = [NaN; TTable.NCST_ERROR(2:end) - rho_set(j) * TTable.NCST_ERROR(1:end-1)]; % corrected nowcast errors
    for i = 1:N_time_periods
        % compute root mean squared forecasting/nowcasting errors
        %RMSFE(i,1) = sum(TTable.FCST_ERROR(time_periods.(names{i})).^2)/length(time_periods.(names{i}));
        RMSFE(i,j) = sqrt(mean(TTable.FCST_ERROR_CORRECTED(time_periods.(names{i})).^2,"omitnan"));
        RMSNE(i,j) = sqrt(mean(TTable.NCST_ERROR_CORRECTED(time_periods.(names{i})).^2,"omitnan"));
    end
end

%% graph to compare original and corrected errors
if my_variable == "UNEMP" || my_variable == "INDPROD" || my_variable == "RGDP"
    rho_fixed = 0.5;
elseif my_variable == "CPI"
    rho_fixed = 0.3;
else
    error("this variable not implemented yet")
end 
TTable.FCST_ERROR_CORRECTED = [NaN; TTable.FCST_ERROR(2:end) - rho_fixed * TTable.FCST_ERROR(1:end-1)];
figure;
plot(TTable.t,TTable.FCST_ERROR); hold on
plot(TTable.t,TTable.FCST_ERROR_CORRECTED,'x');
yline(0, '--k', 'LineWidth', 1.2); % horizontal line at y = 0
legend('FCST\_ERROR','FCST\_ERROR\_CORRECTED')
ylim([-2 2]);

%% out of sample forecast with historical correction factor

if my_variable == "UNEMP" || my_variable == "INDPROD" || my_variable == "RGDP"
    T0 = 50; % use correction factor 0.5 within this period, then start validation
elseif my_variable == "CPI"
    T0 = 100; % CPI data starts at t = 52
else
    error("this variable not implemented yet")
end    
rho_old = rho_fixed;
TTable.FCST_ERROR_CORRECTED(1:T0) = [NaN; TTable.FCST_ERROR(2:T0) - rho_old * TTable.FCST_ERROR(1:T0-1)]; % corrected forecast errors

for t = T0+1:T
    % find historical optimal rho
    if (t <= 205)
        fun = @(x)sum((TTable.FCST_ERROR(2+1:t-1) - x * TTable.FCST_ERROR(1+1:t-1-1)).^2,"omitnan");
    % remove COVID period from training sample (end at 205 restart 214)
    elseif (205 < t) && (t < 214) % COVID period
        fun = @(x)sum((TTable.FCST_ERROR(2+1:205-1) - x * TTable.FCST_ERROR(1+1:205-1-1)).^2,"omitnan");
    elseif (t >= 214) % post COVID
        fun = @(x)sum((TTable.FCST_ERROR([2+1:205-1 214-1:t-1]) - x * TTable.FCST_ERROR([1+1:205-1-1 214-1:t-1])).^2,"omitnan");
    end
    [rho_opt,fval] = fminunc(fun,rho_old);
    rho_old = rho_opt;
    % use if for correction
    TTable.FCST_ERROR_CORRECTED(t) = TTable.FCST_ERROR(t) - rho_opt * TTable.FCST_ERROR(t-1);
    TTable.rho_opt(t) = rho_opt;
end

% compute RMSFE for validated correction
RMSFEv = NaN(N_time_periods,1); % preallocation
for i = 1:N_time_periods
    %time_periods.(names{i})
    RMSFEv(i) = sqrt(mean(TTable.FCST_ERROR_CORRECTED(time_periods.(names{i})).^2,"omitnan"));
end

% look at validated correction factor

scrsz = get(0,'ScreenSize'); 
gcf=figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(4)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]
plot(TTable.t(T0+1:end),TTable.rho_opt(T0+1:end)); hold on
file_out = '/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Draft/fig-HistOpt-corr-factor.pdf';
%exportgraphics(gcf,file_out,'ContentType','vector');


%% functions
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