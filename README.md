# CORRECTED FORECAST COMBINATIONS

MATLAB replication code accompanying Liu and Vasnev (2026), covering the motivating example, simulation evidence, and US Survey of Professional Forecasters (SPF) applications. Section references below follow the revision draft.

## Replication files

| Program | Purpose | Input |
|---|---|---|
| [GLS_BatesGranger1969_v01.m](GLS_BatesGranger1969_v01.m) | Bates–Granger motivating example: forecast weights, error correction, and MSFE comparisons. | Data embedded in the script. |
| [simulation_v05_github.m](simulation_v05_github.m) | Persistence-grid simulation and structural-break experiments comparing fixed and historically estimated corrections. | Simulated data. |
| [USSPF_mean_fcst_v05_github.m](USSPF_mean_fcst_v05_github.m) | Section 3.1: corrected mean forecasts, real-time alternatives, and results for horizons 1–4. | [Mean_forecast.xlsx](Mean_forecast.xlsx) |
| [USSPF_opt_fcst_v05_github.m](USSPF_opt_fcst_v05_github.m) | Section 3.2: optimal combinations, OLS/GLS corrections, and additional benchmarks. | [Individual_forecast.xlsx](Individual_forecast.xlsx) |

The workbooks contain UNEMP (unemployment), RGDP (real GDP), INDPROD (industrial production), and CPI data. The replication programs use the supplied workbook values; the mean-forecast program uses RGDP and INDPROD levels. The individual workbook contains forecaster IDs and individual reports.

[USSPF_mean_fcst_v01.m](USSPF_mean_fcst_v01.m) and [USSPF_opt_fcst_v03.m](USSPF_opt_fcst_v03.m) are earlier versions retained for reference. Use the v05 programs for the revised empirical applications; they include their own helper functions and do not call the earlier scripts.

## Requirements and setup

The replication checks were run with MATLAB R2026a Update 4. Required toolboxes depend on the program:

| Program | Toolboxes beyond MATLAB |
|---|---|
| Bates–Granger example | None. |
| Simulation | Parallel Computing Toolbox. |
| Corrected mean forecasts | Optimization Toolbox. |
| Optimal combinations | Optimization Toolbox and Econometrics Toolbox. |

Keep the two `.xlsx` workbooks beside the `.m` files, as in this repository. The empirical programs locate their inputs relative to their own location, so personal absolute paths are not required. They read the workbooks using `UseExcel=false`; Microsoft Excel is not required.

Open the repository folder in MATLAB, select a program, and click **Run**, or enter its filename without `.m` in the Command Window. Run programs individually: they clear the workspace and close existing figures. Save or inspect a program's workspace results before starting another.

## Motivating example

```matlab
GLS_BatesGranger1969_v01
```

The script uses the embedded 1953 observations to compare individual forecasts, equal weighting, and correction of the equal-weight forecast. It produces two figures and leaves `MSFE`, `MSFE_c`, `MSFE_c_rho`, `MSFE_set`, and `MSFE_rho_set` in the workspace.

PDF export is commented out. This older script still has a personal path in its final `file_out` assignment; to export, replace that value with a local filename such as `'fig-BG-v01.pdf'` before enabling the export line.

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

Ratios below one indicate improvement over the uncorrected combination. The script displays two heat maps and a break-comparison figure. Set `print_figures = true` to save `fig-simul-gamma-05.pdf` and `fig-simul-gamma-ho.pdf` beside the script. The break-figure export remains separately commented out.

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

`MSE` contains full-precision results; `MSE_print` displays four-decimal results. Relative MSFE uses the first table row, `ERR_MEAN` in the default illustration, as its denominator. Forecasts, errors, weights, and coefficient histories remain in the workspace. This program does not automatically save a results file. Its PDF export lines are commented out; enable the matching `file_out` and `exportgraphics` lines to save figures beside the script. Several plots contain multiple panels, so exporting a whole figure does not separately export the paper's subfigures.

The paper includes more than one fixed correction coefficient. To obtain those additional rows, edit the indicated section and rerun:

| Section in the script | Default | Additional paper setting |
|---|---|---|
| `correct the mean forecast` | `corr_factor_fixed = 0.65` | Set it to `0.5`. |
| `correct the optimal (regression) forecast REGR_IN or REGR_OUT` | `corr_factor_fixed = 0.5` | Set it to `0.7`. |

Record the corresponding `MSE` rows before rerunning, since each run clears the workspace. Full-sample `corr_factor_opt` estimates are diagnostic; they do not replace these fixed settings.

`my_period = 1` selects 2000–2008. `my_period = 3` creates the full-period data plot and deliberately stops with the inherited message that the remaining analysis is not implemented for that period. The optimal-combination replication has been checked for the default UNEMP case; other indicators require separate validation.

## Validation and draft conventions

Preparation checks in MATLAB R2026a gave the following results:

- **Simulation:** the calculation statements were unchanged from v04. A controlled serial comparison using a 3×3 grid, 200 replications, and all three break scenarios matched all 17 compared outputs exactly. The full parallel grid was not rerun for this check.
- **Mean forecasts:** all 204 field comparisons against the three source programs matched exactly across four indicators and four horizons. The `lagged_error` name replaces the development label `available_error` without changing the calculation.
- **Optimal combinations:** all 33 compared outputs matched v04 exactly for the complete default UNEMP run. Standalone workbook discovery was also verified.

The programs preserve the source calculations where draft descriptions differ:

- The mean-forecast program excludes COVID rows 206–213, corresponding to **2020Q1–2021Q4**, although some draft captions say 2020Q1–2022Q4.
- Recursive mean-forecast coefficients are unconstrained in the code, although the draft mentions a restriction to (−1,1). The optimal-combination program separately uses inclusive bounds [−1,1] for its recursive OLS correction and GLS AR parameter.
- The supplied RGDP mean sheet includes a 2025Q4 survey, allowing evaluation through 2025Q3, although the nominal paper labels end at 2025Q2. Other mean sheets end with the 2025Q3 survey. The mean program checks these snapshot dates because its evaluation rules use row indices.
- Evaluation samples can begin later than nominal period labels because both current and lagged signals must be available. Sample sizes can differ across methods and horizons.

Of 2,376 numeric entries in the six mean-forecast draft tables, 2,373 matched. The three differences are in the CPI `previous_error`, `h=1`, recursive column:

| Period | Draft | Source programs and v05 |
|---|---:|---:|
| 1981Q3–2025Q2 | 0.97 | 0.98 |
| 2000Q1–2025Q2 | 0.97 | 0.98 |
| 2022Q1–2025Q2 | 0.84 | 0.88 |

There is also one bolding difference: the UNEMP one-step benchmark's full-period excluding-COVID row selects a fixed factor of **0.5** at full precision, while the draft bolds **0.4**. Both displayed relative RMSFEs round to 0.86. Generated tables retain the source calculations and select minima before rounding.
