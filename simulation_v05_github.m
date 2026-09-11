%% simulation_v05_hithub: documented copy of simulation_v04
% Purpose: assess when correcting an equal-weight forecast combination
% reduces its mean squared forecast error (MSFE).
%
% Experiment 1 varies the persistence of two independent AR(1) forecast
% errors. Experiment 2 changes their persistence halfway through the sample.
% Both compare a fixed correction (gamma = 0.5) with a recursively estimated,
% historically optimal correction, using the uncorrected mean as the baseline.
%
% Requirements: MATLAB with Parallel Computing Toolbox. No input data files
% are needed: all forecast errors are simulated. Run the complete script.
% The default grid has 91 x 91 points and 5,000 replications per point;
% this is a substantial computation (41,405,000 simulated pairs of series).
%
% Main workspace outputs:
%   relative_msfe_cfec     - fixed-correction ratios, indexed by (rho1,rho2).
%   relative_msfe_ho_cfec  - historical-correction ratios, same indexing.
%   relative_msfe_break_fixed / relative_msfe_break_hist
%                         - scenario-by-window ratios for the break study.
%   break_results         - labelled table of the break-study results.
% A ratio below 1 means that correction improves accuracy. Figures show
% two persistence heat maps and full-sample/post-break bar charts.
%
% Version scope: the simulation calculations, default parameters and plotting
% instructions from v04 are retained, with added comments and portable output
% paths. PDF export is off by default. The two heat maps can be exported
% by setting print_figures = true; the break-figure export remains commented
% out. PDF files are saved beside this script, regardless of the current folder.
%
% Reproducibility: rng('default') resets the client random stream, but does
% not by itself fix the assignment of worker random draws to parfor grid
% iterations. Independent parallel runs can therefore differ through Monte
% Carlo variation. In the break experiment the innovations are generated on
% the client before parfor and reused across scenarios. These v04 behaviours
% are preserved; v05 introduces no random-stream or algorithm changes.
%
% Session effects inherited from v04: clears the workspace, closes figures,
% starts a parallel pool if needed, and deletes the pool at the end (including
% an existing pool reused by this script).

%% simulation to assess when it is worthwhile to correct the combination
% v04 is created for the IJF revision 1

clear all
close all

% Resolve output files relative to this script's location on any machine.
output_dir = fileparts(mfilename('fullpath'));

% Innovations have standard deviations sigma1 and sigma2; these are not
% the stationary standard deviations, which also depend on persistence.
% T_gamma is the first time at which a historical coefficient is estimated;
% earlier corrected observations use the fixed coefficient.
%% parameters
gamma = 0.5;        % correction parameter
T_gamma = 20;       % minimum length required to fit hist opt gamma
T = 12*10;          % length of series: 10 years of monthly forecasts
sigma1 = 1;         % innovation std for series 1
sigma2 = 1;         % innovation std for series 2
print_figures = false; % set to true to export figures as PDF

% Values strictly inside (-1,1) permit stationary AR(1) initialization.
% Matrix row i corresponds to rho_grid(i) for process 1; column j to process 2.
rho_grid = 0:0.01:0.9;   % grid for rho1 and rho2
Nrho = length(rho_grid);

%% Monte Carlo settings

% Each grid cell averages replication-specific MSFE ratios, rather than
% taking the ratio of MSFEs pooled over all replications.
Nrep = 5000;

relative_msfe_cfec = NaN(Nrho, Nrho);
relative_msfe_ho_cfec = NaN(Nrho, Nrho);

%% start parallel pool

% Parallelize over the first persistence parameter. Inner grid cells and
% replications run sequentially within each worker's assigned iteration.
if isempty(gcp('nocreate'))
    parpool;
end

rng('default');

%% loop over rho1 and rho2

parfor i = 1:Nrho

    rho1 = rho_grid(i);

    for j = 1:Nrho

        rho2 = rho_grid(j);
        % Progress messages from different workers may appear out of order.
        display([rho1 rho2]);

        relative_msfe_rep = NaN(Nrep,1);
        relative_msfe_ho_rep = NaN(Nrep,1);

        for r = 1:Nrep

            % New independent Gaussian innovations for each replication.
            %% generate innovations
            eps1 = sigma1 * randn(T,1);
            eps2 = sigma2 * randn(T,1);

            %% preallocate series
            fe1 = zeros(T,1);
            fe2 = zeros(T,1);

            % Var(fe_i) = sigma_i^2/(1-rho_i^2). Scaling the first innovation
            % draws the initial error from this distribution without burn-in.
            %% initialize first value from stationary distribution
            fe1(1) = eps1(1) / sqrt(1 - rho1^2);
            fe2(1) = eps2(1) / sqrt(1 - rho2^2);

            %% generate AR(1) series
            for t = 2:T
                fe1(t) = rho1 * fe1(t-1) + eps1(t);
                fe2(t) = rho2 * fe2(t-1) + eps2(t);
            end

            % With errors defined as actual minus forecast, adding gamma
            % times the previous combined error to the forecast subtracts
            % that quantity from its current error. No lag exists at t = 1,
            % so the first combined error is retained without correction.
            %% equal-weight combination and correction
            fec = (fe1 + fe2)/2;
            % correction with fixed gamma
            cfec = [fec(1); fec(2:end) - gamma * fec(1:end-1)];
            % historically optimal correction
            % Begin with the fixed correction for the whole sample, then
            % replace observations t >= T_gamma by the historical correction.
            cfec_ho = cfec;
            %gamma_old = 0.5;
            %options = optimoptions('fminunc', 'Display', 'off');
            for t = T_gamma:T
                % optimization (has explicit solution)
                %fun = @(x)sum((fec(2:t-1) - x * fec(1:t-2)).^2, "omitnan");
                %[gamma_opt,fval] = fminunc(fun, gamma_old, options);
                %gamma_old = gamma_opt;
                % explicit solution
                % Expanding-window least squares without an intercept:
                % regress fec(2:t-1) on fec(1:t-2), using only past errors.
                % At t = T_gamma = 20 this uses 18 lagged-error pairs.
                % The coefficient is unconstrained and is not clipped.
                gamma_opt = (fec(2:t-1)'*fec(1:t-2))/(fec(1:t-2)'*fec(1:t-2));
                cfec_ho(t,1) = fec(t) - gamma_opt * fec(t-1);
            end

            % Evaluation includes all T observations, including the first
            % uncorrected error and the historical method's fixed warm-up.
            %% MSFE ratio
            msfe_fec  = mean(fec.^2);
            msfe_cfec = mean(cfec.^2);
            msfe_cfec_ho = mean(cfec_ho.^2);

            relative_msfe_rep(r) = msfe_cfec / msfe_fec;
            relative_msfe_ho_rep(r) = msfe_cfec_ho / msfe_fec;

        end

        %% average relative MSFE over replications
        relative_msfe_cfec(i,j) = mean(relative_msfe_rep);
        relative_msfe_ho_cfec(i,j) = mean(relative_msfe_ho_rep);

    end
end


% Both heat maps share a colour scale for direct comparison. Transpose
% the result matrices so rho1 is horizontal and rho2 is vertical; meshgrid
% is retained for the inactive 3D plotting alternatives below.
%% figure with fixed gamma
[RHO1, RHO2] = meshgrid(rho_grid, rho_grid);
zmin = min([relative_msfe_cfec(:); relative_msfe_ho_cfec(:)], [], 'omitnan');
zmax = max([relative_msfe_cfec(:); relative_msfe_ho_cfec(:)], [], 'omitnan');

%figure;
scrsz = get(0,'ScreenSize'); 
gcf = figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(3)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]

%% 3D plot (retained for reference)
%{
surf(RHO1, RHO2, relative_msfe_cfec', 'EdgeColor', 'none');
hold on;

contour3(RHO1, RHO2, relative_msfe_cfec', [1 1], 'r', 'LineWidth', 4);
axis square

xlabel('\rho_1');
ylabel('\rho_2');
%zlabel('Relative MSFE of corrected combination');

%title('Relative MSFE of CFEC as a function of \rho_1 and \rho_2');

%grid on;
box on;
clim([zmin zmax])
zlim([zmin zmax])
colorbar;
%view(135, 30);
view(2)
%}

% The red contour at ratio = 1 separates accuracy gains from losses.
%% 2D heat map
Z_fixed = relative_msfe_cfec';
imagesc(rho_grid, rho_grid, Z_fixed);
set(gca, 'YDir', 'normal');
hold on;

% White underlay keeps the MSFE = 1 boundary visible on every color.
contour(rho_grid, rho_grid, Z_fixed, [1 1], 'w', 'LineWidth', 4);
contour(rho_grid, rho_grid, Z_fixed, [1 1], 'r', 'LineWidth', 2.5);

axis square
xticks(0:0.1:0.9);
yticks(0:0.1:0.9);
set(gca, 'TickDir', 'out', 'TickLength', [0.02 0.02]);
xlabel('\rho_1');
ylabel('\rho_2');
box on;
clim([zmin zmax])
colorbar;

file_out = fullfile(output_dir, 'fig-simul-gamma-05.pdf');
if print_figures
    exportgraphics(gcf,file_out,'ContentType','vector');
end


% Apply the same orientation, axes and colour limits to the historical
% correction so differences between panels reflect their MSFE ratios.
%% figure with hist opt gamma
%figure;
gcf1 = figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(3)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]

%% 3D plot (retained for reference)
%{
surf(RHO1, RHO2, relative_msfe_ho_cfec', 'EdgeColor', 'none');
hold on;

contour3(RHO1, RHO2, relative_msfe_ho_cfec', [1 1], 'r', 'LineWidth', 4);
axis square

xlabel('\rho_1');
ylabel('\rho_2');
%zlabel('Relative MSFE of corrected combination');

%title('Relative MSFE of CFEC_HO as a function of \rho_1 and \rho_2');

%grid on;
box on;
clim([zmin zmax])
zlim([zmin zmax])
colorbar;
%view(135, 30);
view(2)
%}

%% 2D heat map
Z_hist = relative_msfe_ho_cfec';
imagesc(rho_grid, rho_grid, Z_hist);
set(gca, 'YDir', 'normal');
hold on;

% White underlay keeps the MSFE = 1 boundary visible on every color.
contour(rho_grid, rho_grid, Z_hist, [1 1], 'w', 'LineWidth', 4);
contour(rho_grid, rho_grid, Z_hist, [1 1], 'r', 'LineWidth', 2.5);

axis square
xticks(0:0.1:0.9);
yticks(0:0.1:0.9);
set(gca, 'TickDir', 'out', 'TickLength', [0.02 0.02]);
xlabel('\rho_1');
ylabel('\rho_2');
box on;
clim([zmin zmax])
colorbar;

file_out = fullfile(output_dir, 'fig-simul-gamma-ho.pdf');
if print_figures
    exportgraphics(gcf1,file_out,'ContentType','vector');
end


% Break experiment: change AR coefficients while leaving innovation
% variances fixed. The error state carries through the change; no new
% stationary draw or correction-estimator reset is made at the break.
%% simulation with breaks in the individual error dynamics

% Each row contains (rho1,rho2) before and after the break.
break_scenario_names = ["Persistence falls"; ...
                        "Persistence rises"; ...
                        "One process changes"];
rho_before = [0.8 0.6; ...
              0.2 0.1; ...
              0.8 0.6];
rho_after  = [0.2 0.1; ...
              0.8 0.6; ...
              0.8 0.1];

% With T = 120, periods 1:60 use rho_before and 61:120 use rho_after.
Nbreak_scenarios = size(rho_before,1);
T_break = floor(T/2);
Nrep_break = Nrep;

% Evaluation windows. The first year after the break is reported
% separately to show the immediate effect of instability.
% At the defaults these windows are 61:120, 61:72 and 73:120.
idx_post = (T_break+1):T;
idx_early_post = (T_break+1):min(T_break+12,T);
idx_late_post = (min(T_break+12,T)+1):T;

% Columns: full sample, post-break sample, first 12 post-break periods,
% and the remaining post-break periods.
relative_msfe_break_fixed = NaN(Nbreak_scenarios,4);
relative_msfe_break_hist = NaN(Nbreak_scenarios,4);

% Use common innovations across scenarios to make their comparison less
% sensitive to Monte Carlo noise.
rng('default');
% Each column is one replication, reused for every scenario and method.
% No random draws occur inside the break experiment's parallel loop.
eps1_break = sigma1 * randn(T,Nrep_break);
eps2_break = sigma2 * randn(T,Nrep_break);

for s = 1:Nbreak_scenarios

    rho1_before = rho_before(s,1);
    rho2_before = rho_before(s,2);
    rho1_after = rho_after(s,1);
    rho2_after = rho_after(s,2);

    relative_msfe_break_fixed_rep = NaN(Nrep_break,4);
    relative_msfe_break_hist_rep = NaN(Nrep_break,4);

    parfor r = 1:Nrep_break

        eps1 = eps1_break(:,r);
        eps2 = eps2_break(:,r);

        fe1 = zeros(T,1);
        fe2 = zeros(T,1);

        % Initialize under the first regime and retain the state when the
        % persistence parameters change at T_break.
        fe1(1) = eps1(1) / sqrt(1 - rho1_before^2);
        fe2(1) = eps2(1) / sqrt(1 - rho2_before^2);

        for t = 2:T
            if t <= T_break
                rho1_t = rho1_before;
                rho2_t = rho2_before;
            else
                rho1_t = rho1_after;
                rho2_t = rho2_after;
            end

            fe1(t) = rho1_t * fe1(t-1) + eps1(t);
            fe2(t) = rho2_t * fe2(t-1) + eps2(t);
        end

        %% equal-weight combination and corrections
        fec = (fe1 + fe2)/2;
        cfec = [fec(1); fec(2:end) - gamma * fec(1:end-1)];

        % Use the same warm-up and past-only least-squares correction as
        % in the stationary experiment. Historical estimation keeps all
        % pre-break observations as the post-break sample accumulates.
        cfec_ho = cfec;
        for t = T_gamma:T
            gamma_opt = (fec(2:t-1)'*fec(1:t-2)) / ...
                        (fec(1:t-2)'*fec(1:t-2));
            cfec_ho(t) = fec(t) - gamma_opt * fec(t-1);
        end

        % Each method is compared with the uncorrected combination over
        % exactly the same window; the denominator is specific to that window.
        %% relative MSFEs by evaluation window
        fixed_full = mean(cfec.^2) / mean(fec.^2);
        fixed_post = mean(cfec(idx_post).^2) / mean(fec(idx_post).^2);
        fixed_early_post = ...
            mean(cfec(idx_early_post).^2) / mean(fec(idx_early_post).^2);
        fixed_late_post = ...
            mean(cfec(idx_late_post).^2) / mean(fec(idx_late_post).^2);

        hist_full = mean(cfec_ho.^2) / mean(fec.^2);
        hist_post = ...
            mean(cfec_ho(idx_post).^2) / mean(fec(idx_post).^2);
        hist_early_post = ...
            mean(cfec_ho(idx_early_post).^2) / mean(fec(idx_early_post).^2);
        hist_late_post = ...
            mean(cfec_ho(idx_late_post).^2) / mean(fec(idx_late_post).^2);

        relative_msfe_break_fixed_rep(r,:) = ...
            [fixed_full fixed_post fixed_early_post fixed_late_post];
        relative_msfe_break_hist_rep(r,:) = ...
            [hist_full hist_post hist_early_post hist_late_post];

    end

    % Average the within-replication ratios separately for each window.
    % The inherited omitnan option ignores undefined ratios if any arise.
    relative_msfe_break_fixed(s,:) = ...
        mean(relative_msfe_break_fixed_rep,1,'omitnan');
    relative_msfe_break_hist(s,:) = ...
        mean(relative_msfe_break_hist_rep,1,'omitnan');

end


% Table columns alternate fixed and historical corrections within each
% window. RhoBefore/RhoAfter record both processes' persistence parameters.
%% table of break-simulation results

rho_before_label = compose('(%.1f, %.1f)',rho_before(:,1),rho_before(:,2));
rho_after_label = compose('(%.1f, %.1f)',rho_after(:,1),rho_after(:,2));

break_results = table( ...
    break_scenario_names, rho_before_label, rho_after_label, ...
    relative_msfe_break_fixed(:,1), relative_msfe_break_hist(:,1), ...
    relative_msfe_break_fixed(:,2), relative_msfe_break_hist(:,2), ...
    relative_msfe_break_fixed(:,3), relative_msfe_break_hist(:,3), ...
    relative_msfe_break_fixed(:,4), relative_msfe_break_hist(:,4), ...
    'VariableNames',{'Scenario','RhoBefore','RhoAfter', ...
    'FixedFull','HistoricalFull','FixedPost','HistoricalPost', ...
    'FixedEarlyPost','HistoricalEarlyPost','FixedLatePost', ...
    'HistoricalLatePost'});

disp(break_results);


% Plot the full and post-break windows; early/late post-break results
% remain available in break_results. A red line marks the baseline ratio 1.
% Use a shared vertical scale for the two panels.
%% figure for break-simulation results

break_figure = figure('PaperPositionMode','auto', ...
    'Position',[scrsz(3)/20 scrsz(4)/2 2*scrsz(3)/3 scrsz(3)/3], ...
    'PaperOrientation','landscape');
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

break_plot_max = max([relative_msfe_break_fixed(:,1:2); ...
                      relative_msfe_break_hist(:,1:2)],[],'all');
break_ylim = [0 1.05*max(1,break_plot_max)];

nexttile;
bar([relative_msfe_break_fixed(:,1),relative_msfe_break_hist(:,1)]);
hold on;
yline(1,'r-','LineWidth',2);
ylim(break_ylim);
xticks(1:Nbreak_scenarios);
xticklabels(break_scenario_names);
xtickangle(20);
set(gca,'TickDir','out','TickLength',[0.02 0.02], ...
    'TickLabelInterpreter','none');
ylabel('Relative MSFE');
title('Full sample');
box on;
legend({'Fixed \gamma=0.5','Recursive historical'}, ...
    'Location','best','Interpreter','tex');

nexttile;
bar([relative_msfe_break_fixed(:,2),relative_msfe_break_hist(:,2)]);
hold on;
yline(1,'r-','LineWidth',2);
ylim(break_ylim);
xticks(1:Nbreak_scenarios);
xticklabels(break_scenario_names);
xtickangle(20);
set(gca,'TickDir','out','TickLength',[0.02 0.02], ...
    'TickLabelInterpreter','none');
ylabel('Relative MSFE');
title('Post-break sample');
box on;

file_out = fullfile(output_dir, 'fig-simul-breaks.pdf');
if print_figures
    % the figure is not very informative
    %exportgraphics(break_figure,file_out,'ContentType','vector');
end

% Release the parallel workers after all simulations and plots finish.
%% close parallel pool

parallel_pool = gcp('nocreate');
if ~isempty(parallel_pool)
    delete(parallel_pool);
end
