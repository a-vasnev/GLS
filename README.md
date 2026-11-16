# CORRECTED FORECAST COMBINATIONS

MATLAB replication code accompanying Liu and Vasnev (2026), covering the motivating example, simulation evidence, and US Survey of Professional Forecasters (SPF) applications. Section references below follow the revision draft.

**Package assembled:** 16 November 2026

**Package authors:** Chu-An Liu and Andrey Vasnev

**Corresponding author:** [Andrey Vasnev](mailto:andrey.vasnev@sydney.edu.au), The University of Sydney Business School

## Replication files

| Program | Purpose | Input |
|---|---|---|
| [GLS_BatesGranger1969_v01.m](GLS_BatesGranger1969_v01.m) | Bates–Granger motivating example: forecast weights, error correction, and MSFE comparisons. | Data embedded in the script. |
| [simulation_v05_github.m](simulation_v05_github.m) | Persistence-grid simulation and structural-break experiments comparing fixed and historically estimated corrections. | Simulated data. |
| [USSPF_mean_fcst_v05_github.m](USSPF_mean_fcst_v05_github.m) | Section 3.1: corrected mean forecasts, real-time alternatives, and results for horizons 1–4. | [Mean_forecast.xlsx](Mean_forecast.xlsx) |
| [USSPF_opt_fcst_v05_github.m](USSPF_opt_fcst_v05_github.m) | Section 3.2: optimal combinations, OLS/GLS corrections, and additional benchmarks. | [Individual_forecast.xlsx](Individual_forecast.xlsx) |

The workbooks contain UNEMP (unemployment), RGDP (real GDP), INDPROD (industrial production), and CPI data. The mean-forecast analysis uses RGDP and INDPROD levels.

## Data sources and preparation

The Federal Reserve Bank of Philadelphia publishes the [Survey of Professional Forecasters data files](https://www.philadelphiafed.org/surveys-and-data/data-files). The archived source workbooks used here were downloaded in October 2025 and cover survey quarters **1968Q4–2025Q3**. Use the two workbooks included in this repository for replication. The Philadelphia Fed can update the workbooks available from its download pages.

| Included replication input | Philadelphia Fed source and preparation |
|---|---|
| [`Mean_forecast.xlsx`](Mean_forecast.xlsx) | The `UNEMP`, `RGDP`, `INDPROD`, and `CPI` worksheets match the archived `meanLevel.xlsx` observations through 2025Q3. The bundled `RGDP` sheet also contains one 2025Q4 survey row. The included `RGDP_growth` sheet matches the `RGDP` sheet of the archived `meanGrowth.xlsx`; the replication scripts use the levels sheet. For that additional row, the bundled workbook is the available source snapshot. [Philadelphia Fed mean forecast workbooks](https://www.philadelphiafed.org/surveys-and-data/real-time-data-research/mean-forecasts) |
| [`Individual_forecast.xlsx`](Individual_forecast.xlsx) | The four worksheets are extracts from the archived `SPFmicrodata.xlsx`. A comparison by survey year, quarter, and forecaster ID confirmed that their stored observations match the archived source. They retain the original ID and industry fields. [Philadelphia Fed individual forecast workbook](https://www.philadelphiafed.org/surveys-and-data/real-time-data-research/individual-forecasts) |

The quarterly SPF columns use suffix 1 for the preceding quarter's historical value as stored in the survey file, suffix 2 for the survey-quarter nowcast, and suffixes 3–6 for the next four quarters' forecasts. The mean-forecast script aligns these columns by target quarter. The optimal-combination script reshapes the individual reports, takes the median of the available copies of the historical value within each survey quarter, and performs forecast alignment and regression imputation as described below. The two bundled workbooks contain stored values and are the prepared inputs. Alignment, error construction, and imputation are performed in MATLAB.

The two SPF inputs are publicly available and included in the package. The authors report no additional sharing restrictions on the data or replication code needed to run this package.

### Intermediate data and final outputs

| Program | Data created during replication | Final outputs |
|---|---|---|
| `GLS_BatesGranger1969_v01.m` | Forecast-error arrays `E`, `E_c`, and `E_c_rho`, from observations embedded in the script. | Table 1 values in the MATLAB workspace and the Figure 1 PDF from the export command below. |
| `simulation_v05_github.m` | Simulated error series generated within the program. The grid arrays `relative_msfe_cfec` and `relative_msfe_ho_cfec` and the break-study table `break_results` remain in the workspace. | Table 2 and both Figure 2 PDFs using the settings below. |
| `USSPF_mean_fcst_v05_github.m` | Target-aligned data, forecast errors, recursive coefficients, and full-precision results saved in [`output_USSPF_mean/USSPF_mean_section_3_1.mat`](output_USSPF_mean/USSPF_mean_section_3_1.mat). The program also saves `sample-counts.csv`. Both files are included. | Tables 4, 6, 7, and 9–11 as CSV and LaTeX fragments, plus the Figure 4 PDF when enabled. |
| `USSPF_opt_fcst_v05_github.m` | Aligned forecasts in `my_pdata_fcst_aligned_TT`, errors in `my_pdata_fcst_errors_TT`, and full-precision MSFEs in `MSE`, all generated in the workspace. | The Figure 3 PDFs in plot-only mode. The README commands below export Table 8 and Figures 5–6 from the default run. |

The two descriptive tables, Tables 3 and 5, are documented in the manuscript table guide below.

## Requirements and setup

The replication checks were run with MATLAB R2026a Update 4 on an Apple M5 MacBook Pro (10 CPU cores, 24 GB RAM) running macOS 26.7.3 on Apple silicon. The package requires licences for MATLAB and the MathWorks toolboxes listed below. The computations use CPU workers.

| Program | Toolboxes beyond MATLAB |
|---|---|
| Bates–Granger example | None. |
| Simulation | Parallel Computing Toolbox. |
| Corrected mean forecasts | Optimization Toolbox. |
| Optimal combinations | Optimization Toolbox and Econometrics Toolbox. |

Keep the two `.xlsx` workbooks beside the `.m` files, as in this repository. The empirical programs locate their inputs relative to their own location, so personal absolute paths are not required. They read the workbooks using `UseExcel=false`; Microsoft Excel is not required.

Open the repository folder in MATLAB, select a program, and click **Run**, or enter its filename without `.m` in the Command Window. Run programs individually: they clear the workspace and close existing figures. Save or inspect a program's workspace results before starting another.

### Reference runtimes

The timings below are approximate wall-clock times on the test machine. The motivating example and the two empirical scripts were timed at default settings with optional PDF export disabled.

| Run | Approximate runtime |
|---|---:|
| Bates–Granger example | Under 1 second |
| Mean forecasts, all variables, methods, and horizons | 11 seconds |
| Optimal combinations, default UNEMP analysis | 5 seconds |
| Structural-break simulation, 5,000 replications per scenario | 2.4 seconds with 10 local workers |
| Full 91 × 91 grid for Figure 2, 5,000 replications per point | About 9 minutes of computation with 10 local workers, estimated |

The estimate scales the measured 6.4-second 10 × 10 benchmark to 8,281 grid points at the same number of replications per point. Pool startup took about 67 seconds on the timing run. Actual runtime depends on the machine and worker count. Plotting and PDF exports add time.

## Manuscript tables and figures

Run the commands from the repository root in MATLAB. Each table or figure number below follows the revised manuscript. The scripts are listed in [Replication files](#replication-files).

### Tables

| Paper table | Script and settings | Output or source |
|---|---|---|
| **1. Bates–Granger forecast errors** | `GLS_BatesGranger1969_v01`, defaults. The twelve monthly observations are embedded in `data`. | The monthly columns, in order, are `[E, E_c, E_c_rho]`. The last row is `[MSFE.', MSFE_c, MSFE_c_rho]`, rounded to whole numbers in the paper. |
| **2. Relative MSFE under structural breaks** | `simulation_v05_github`, defaults. Use 120 observations and 5,000 replications. | `break_results`. Panel A uses the `FixedFull`, `HistoricalFull`, `FixedPost`, and `HistoricalPost` columns. Panel B uses the `FixedEarlyPost`, `HistoricalEarlyPost`, `FixedLatePost`, and `HistoricalLatePost` columns. Compare at four decimals. |
| **3. Evaluation period definitions** | `USSPF_mean_fcst_v05_github`, defaults. | The manuscript lists the nominal periods. See `time_periods` and `period_labels` in the script, and the `Period` column in the exported tables. |
| **4. Corrected mean forecasts, horizon 1** | `USSPF_mean_fcst_v05_github`, `previous_error`, `h=1`. | `output_USSPF_mean/table-previous_error-h1.csv` and the corresponding `.tex` fragment. |
| **5. RGDP forecast horizons at three survey dates** | The manuscript adapts Table 3 on page 22 of the [Philadelphia Fed SPF documentation](https://www.philadelphiafed.org/-/media/frbp/assets/surveys-and-data/survey-of-professional-forecasters/spf-documentation.pdf). | Calendar illustration for the 2024Q3, 2024Q4, and 2025Q1 surveys. The quarterly suffixes 1–6 represent the previous, current, and next four quarters. Annual columns A and B represent the survey year and the following year. |
| **6. Nowcast-based proxy, horizon 1** | `USSPF_mean_fcst_v05_github`, `nowcast_proxy`, `h=1`. | `output_USSPF_mean/table-nowcast_proxy-h1.csv` and the corresponding `.tex` fragment. |
| **7. Extra lagged forecast error, horizon 1** | `USSPF_mean_fcst_v05_github`, `lagged_error`, `h=1`. | `output_USSPF_mean/table-lagged_error-h1.csv` and the corresponding `.tex` fragment. |
| **8. Individual forecasts and optimal combinations** | `USSPF_opt_fcst_v05_github`, default UNEMP analysis. | `MSE` contains the default results. Run the [Table 8 commands](#table-8-optimal-combinations) to assemble and export `table-8.csv` with both extra fixed-factor rows. |
| **9. Corrected mean forecasts, horizon 2 (appendix)** | `USSPF_mean_fcst_v05_github`, `previous_error`, `h=2`. | `output_USSPF_mean/table-previous_error-h2.csv` and the corresponding `.tex` fragment. |
| **10. Corrected mean forecasts, horizon 3 (appendix)** | `USSPF_mean_fcst_v05_github`, `previous_error`, `h=3`. | `output_USSPF_mean/table-previous_error-h3.csv` and the corresponding `.tex` fragment. |
| **11. Corrected mean forecasts, horizon 4 (appendix)** | `USSPF_mean_fcst_v05_github`, `previous_error`, `h=4`. | `output_USSPF_mean/table-previous_error-h4.csv` and the corresponding `.tex` fragment. |

One default run of the mean-forecast script produces all six mean-forecast tables. Use their `.tex` fragments to verify bolding, which is determined from the full-precision results.

### Figures

| Paper figure | Script and settings | PDF output |
|---|---|---|
| **1. Bates–Granger combination and correction** | `GLS_BatesGranger1969_v01`, defaults. Export the three-dimensional plot using the command under [Motivating example](#motivating-example). | `fig-BG-v01.pdf` |
| **2. Simulation heat maps** | `simulation_v05_github`, full grid and `print_figures = true`. Panel (a) uses the fixed factor 0.5. Panel (b) uses the recursively estimated factor. | (a) `fig-simul-gamma-05.pdf`, (b) `fig-simul-gamma-ho.pdf` |
| **3. SPF actuals and individual forecasts** | `USSPF_opt_fcst_v05_github`, `my_period = 3`. Run the [plot-only procedure](#figure-3-full-period-spf-plots) once for each indicator. | (a) `fig-UNEMP.pdf`, (b) `fig-RGDP.pdf`, (c) `fig-INDPROD.pdf`, (d) `fig-CPI.pdf` |
| **4. Recursive UNEMP correction factors** | `USSPF_mean_fcst_v05_github`, `make_figure = true`, `export_figure = true`. The plot uses `results.UNEMP.previous_error.TTable.rho_opt` for horizons 1–4. | `output_USSPF_mean/fig-HistOpt-corr-factor-UNEMP-all-horizons.pdf` |
| **5. Autocorrelations of forecast errors** | `USSPF_opt_fcst_v05_github`, default UNEMP analysis. Use the [panel mapping and export commands](#figures-5-and-6-autocorrelation-exports). | Five vector PDFs, one per panel. |
| **6. Autocorrelations of the additional benchmarks (appendix)** | Same default UNEMP run as Figure 5. Export `gcf_new_methods` using the [export commands](#figures-5-and-6-autocorrelation-exports). The three panels run left to right in the order Coulson–Robins method (4), method (5), and Clements correct-then-combine. | `fig-autocorr-new-methods.pdf` |

### Figure 3 full-period SPF plots

In `USSPF_opt_fcst_v05_github.m`, set `my_period = 3`. Set `my_variable` to `"UNEMP"` and run the script. Repeat with `"RGDP"`, `"INDPROD"`, and `"CPI"` in that order. Each run reads that indicator from `Individual_forecast.xlsx`, saves its vector PDF beside the script, and returns before optimal-combination estimation. The four PDFs have distinct names, so each remains available after subsequent runs. Restore `my_period = 2` and `my_variable = "UNEMP"` for Table 8 and Figures 5–6.

## Motivating example

```matlab
GLS_BatesGranger1969_v01
```

The script uses the embedded 1953 observations to compare individual forecasts, equal weighting, and correction of the equal-weight forecast. It produces two figures and leaves `MSFE`, `MSFE_c`, `MSFE_c_rho`, `MSFE_set`, and `MSFE_rho_set` in the workspace.

After running the script, export the three-dimensional plot from MATLAB's Command Window. The script stores its handle in `gcf`. The command saves the PDF in the current folder.

```matlab
exportgraphics(gcf, fullfile(pwd, 'fig-BG-v01.pdf'), 'ContentType', 'vector');
```

## Simulation evidence

```matlab
simulation_v05_github
```

The default persistence grid is `0:0.01:0.9` for each of two independent AR(1) error processes. Each grid point uses 5,000 replications of 120 observations: 41,405,000 pairs of simulated series in total. The script compares a fixed correction of 0.5 with an expanding-history correction beginning at observation 20.

A second experiment changes persistence halfway through the sample. It reports full-sample, post-break, first-year-after-break, and later-post-break results for three scenarios: persistence falls, persistence rises, and one process changes.

Main workspace outputs are:

- `relative_msfe_cfec` and `relative_msfe_ho_cfec`: persistence-grid relative MSFE matrices.
- `relative_msfe_break_fixed` and `relative_msfe_break_hist`: scenario-by-evaluation-window results.
- `break_results`: the labelled structural-break results table.

Ratios below one indicate improvement over the uncorrected combination. The script displays two heat maps and a break-comparison figure. Set `print_figures = true` to save `fig-simul-gamma-05.pdf` and `fig-simul-gamma-ho.pdf` beside the script. The additional break-comparison figure is diagnostic. To save the Table 2 results after the simulation, run `writetable(break_results, fullfile(output_dir, 'table-2.csv'))`.

The full grid is computationally substantial. Smaller `Nrep` or a coarser `rho_grid` can be used for a trial run; restore the defaults for the full experiment. The script starts a parallel pool if necessary and deletes the pool on completion, including an existing pool it reused.

`rng('default')` resets the client random stream but does not fix how worker draws are assigned to persistence-grid iterations. Independent parallel runs can therefore differ through Monte Carlo variation. The break experiment generates innovations on the client and reuses them across scenarios.

## Section 3.1: corrected mean forecasts

```matlab
USSPF_mean_fcst_v05_github
```

One run computes all four indicators, forecast horizons `h=1,2,3,4`, nine evaluation periods, fixed correction factors from 0 to 1 in steps of 0.1, and a recursively estimated correction factor.

For target quarter `t`, let `e(t,h)` denote the horizon-`h` forecast error. The methods are:

| Method name | Correction signal | Origin in the development code |
|---|---|---|
| `previous_error` | `e(t-h,h)`: the preceding same-horizon error, used as the benchmark even though its realization is not yet available at the survey date. | v03 |
| `lagged_error` | `e(t-h-1,h)`: the latest available realized same-horizon error. | v04a |
| `nowcast_proxy` | The survey's current-quarter mean nowcast minus the earlier forecast for that quarter. | v04b |

The corrected error equals the current error minus the correction factor times the selected signal. Historical coefficient estimation uses the information cutoff appropriate to each method. The main corrected-mean table and its horizon extensions use `previous_error`; the two real-time tables use `nowcast_proxy` and `lagged_error` at `h=1`.

By default, `write_outputs = true`, `make_figure = true`, and `export_figure = false`. Results are saved in `output_USSPF_mean/` beside the script:

| Output | Contents |
|---|---|
| `USSPF_mean_section_3_1.mat` | Full-precision results, labelled tables, and evaluation counts. |
| `table-<method>-h<h>.csv` | Twelve rounded tables, one for each method/horizon combination. |
| `table-<method>-h<h>.tex` | Twelve LaTeX tabular fragments; improving fixed-factor minima are selected before rounding and bolded. |
| `sample-counts.csv` | Fixed and recursive evaluation counts for every indicator, method, horizon, and period. |

The UNEMP historical correction-factor figure is displayed. Set `export_figure = true` to save `fig-HistOpt-corr-factor-UNEMP-all-horizons.pdf` in the same output folder. Rerunning the script overwrites outputs with the same filenames.

For example, inspect the one-step UNEMP benchmark panel with:

```matlab
results.UNEMP.previous_error.rel_RMSFE_by_horizon{1}
```

Each panel has nine period rows and eleven columns: fixed factors 0.1–1 followed by the recursive correction. `paper_tables.lagged_error.h1` is the labelled one-step lagged-error table for all indicators. These empirical mean-forecast tables report **relative RMSFE**; the simulation and optimal-combination tables report **relative MSFE**.

## Section 3.2: optimal forecast combinations

```matlab
USSPF_opt_fcst_v05_github
```

The default illustration uses UNEMP, surveys in 2000–2019 (`my_period = 2`), six forecasters with at least 70 survey rows, and previous-forecast imputation (`imp_type = 2`). Recursive combination fitting begins at retained observation 25. The MSFE evaluation uses the original timetable from row 26 onward, omitting missing errors separately for each series.

The script computes the mean and its corrections, restricted in-sample and recursive OLS combinations, corrected recursive OLS, joint GLS combination/correction, Coulson–Robins methods (4) and (5), and the Clements-based correct-then-combine benchmark. Combination weights sum to one and may be negative. The legacy `in_out_sample` setting does not select a method: all methods are computed.

`MSE` contains full-precision results, and `MSE_print` displays four-decimal results. The baseline for relative MSFE is `ERR_MEAN` in the default illustration. Forecasts, errors, weights, and coefficient histories remain in the workspace. `my_period = 1` selects 2000–2008. The optimal-combination calculations were validated for the default UNEMP case.

### Table 8 optimal combinations

Run `USSPF_opt_fcst_v05_github` with `my_variable = "UNEMP"`, `my_period = 2`, and the original fixed correction coefficients of 0.65 for the mean and 0.5 for recursive OLS. In the Command Window, use the commands below to compute the extra **mean 0.5** and **recursive OLS 0.7** rows from the same forecast errors. They retain the script's initial uncorrected observations, evaluation window, and mean-forecast denominator. The resulting `table-8.csv` contains all the paper rows in manuscript order. Round the two result columns to four decimals for comparison.

```matlab
first = T_out_start + 1;
mean_error = my_pdata_fcst_errors_TT.ERR_MEAN;
ols_error = my_pdata_fcst_errors_TT.ERR_REGR_OUT;

mean_corr_050 = [NaN; mean_error(2:end) - 0.5 * mean_error(1:end-1)];
mean_corr_050(2) = mean_error(2);
ols_corr_070 = [NaN; ols_error(2:end) - 0.7 * ols_error(1:end-1)];
ols_corr_070(first) = ols_error(first);

extra_msfe = [mean(mean_corr_050(first:end).^2, 'omitnan');
              mean(ols_corr_070(first:end).^2, 'omitnan')];
baseline = MSE.MSFE(MSE.ErrorSeries == "ERR_MEAN");
extra = table(["ERR_MEAN_CORR_F_050"; "ERR_REGR_OUT_CORR_F_070"], ...
    extra_msfe, extra_msfe / baseline, 'VariableNames', MSE.Properties.VariableNames);
all_rows = [MSE; extra];

paper_series = ["ERR_" + string(fcst_cols(:)); "ERR_MEAN"; ...
    "ERR_MEAN_CORR_F_050"; "ERR_MEAN_CORR_F"; "ERR_MEAN_CORR_HO"; ...
    "ERR_REGR_OUT"; "ERR_REGR_OUT_CORR_F"; "ERR_REGR_OUT_CORR_F_070"; ...
    "ERR_REGR_OUT_CORR_HO"; "ERR_REGR_GLS"; "ERR_REGR_CR4"; ...
    "ERR_REGR_CR5"; "ERR_CLEM_CTC_MEAN"];
[found, row] = ismember(paper_series, all_rows.ErrorSeries);
assert(all(found), 'Run the default UNEMP analysis before assembling Table 8.');
table8 = all_rows(row,:);
writetable(table8, fullfile(output_dir, 'table-8.csv'));
```

The two extra rows should round to **0.0802 / 0.5132** (mean 0.5) and **0.0860 / 0.5502** (recursive OLS 0.7), in MSFE / relative MSFE order.

### Figures 5 and 6 autocorrelation exports

After the default UNEMP run, Figure 5 uses these axes from the two autocorrelation figures. Each autocorrelation plot uses 12 lags.

| Panel | Error series in `my_pdata_fcst_errors_TT` | MATLAB axes | PDF |
|---|---|---|---|
| **5(a)** Mean | `ERR_MEAN` | `mean_acf_axes(1)`, left | `fig-autocorr-mean.pdf` |
| **5(b)** Mean corrected with 0.65 | `ERR_MEAN_CORR_F` | `mean_acf_axes(2)`, right | `fig-autocorr-mean-corr.pdf` |
| **5(c)** Recursive OLS | `ERR_REGR_OUT` | `regression_acf_axes(2)`, upper right | `fig-autocorr-regr.pdf` |
| **5(d)** Recursive OLS with historical correction | `ERR_REGR_OUT_CORR_HO` | `regression_acf_axes(3)`, lower left | `fig-autocorr-regr_corr.pdf` |
| **5(e)** GLS | `ERR_REGR_GLS` | `regression_acf_axes(4)`, lower right | `fig-autocorr-GLS.pdf` |

Run the following before starting another script. The Figure 5 PDF panels use the paper's vertical scale and omit titles, axis labels, and legends. Figure 6 uses the full three-panel figure.

```matlab
figure5_axes = [mean_acf_axes, regression_acf_axes(2:4)];
figure5_files = ["fig-autocorr-mean.pdf", "fig-autocorr-mean-corr.pdf", ...
    "fig-autocorr-regr.pdf", "fig-autocorr-regr_corr.pdf", "fig-autocorr-GLS.pdf"];
for panel = 1:numel(figure5_axes)
    ax = figure5_axes(panel);
    title(ax, '');
    xlabel(ax, '');
    ylabel(ax, '');
    legend(ax, 'off');
    ylim(ax, [-0.4 1]);
    yticks(ax, -0.4:0.2:1);
    exportgraphics(ax, fullfile(output_dir, figure5_files(panel)), 'ContentType', 'vector');
end
exportgraphics(gcf_new_methods, fullfile(output_dir, 'fig-autocorr-new-methods.pdf'), ...
    'ContentType', 'vector');
```

## Validation and draft conventions

Preparation checks in MATLAB R2026a gave the following results:

- **Simulation:** a controlled serial comparison against v04 using a 3×3 grid and 200 replications matched all 17 compared outputs. A separate run of the structural-break experiment with 5,000 replications per scenario matched all 24 manuscript values to four decimals. Figure 2's full grid remains to be verified.
- **Mean forecasts:** all 204 field comparisons against the three source programs matched exactly across four indicators and four horizons.
- **Optimal combinations:** all 33 compared outputs matched v04 exactly for the complete default UNEMP run. Standalone workbook discovery was also verified.

The programs preserve the source calculations where draft descriptions differ:

- The mean-forecast program excludes **2020Q1–2021Q4** from evaluation in the starred rows. Recursive estimation drops training pairs if either the forecast error or the lagged correction signal falls in those quarters.
- The mean-forecast program fits the recursive correction coefficient with `fminunc` and clips it strictly inside (−1, 1) before applying it.
- The supplied RGDP mean sheet includes a 2025Q4 survey, allowing evaluation through 2025Q3, although the nominal paper labels end at 2025Q2. Other mean sheets end with the 2025Q3 survey. The mean program checks these snapshot dates because its evaluation rules use row indices.
- Evaluation samples can begin later than nominal period labels because both current and lagged signals must be available. Sample sizes can differ across methods and horizons.

All **2,376 numeric entries** in the six mean-forecast draft tables agree with the source-program results.

All fixed-factor bold selections in the six draft tables agree with the generated LaTeX tables, which select minima before rounding.
