# Formula 1: Replication and Extension of Success and Failure Experience

This project uses R to independently reconstruct the cumulative experience variables in Lapré and Cravey (2022), replicate Table 1 and models (1), (2), and (4) of Table 2, and extend model (4) to the 1950–2025 and 2018–2025 samples. Published results and R estimates are shown side by side. Variable definitions, construction decisions, and model formulas are documented in `CODEBOOK.md`.

## Environment and data

The analysis has been verified in R 4.4.3. Dependencies are installed by `setup.R`, and package versions are recorded in `results/sessionInfo.txt`. All data processing, estimation, tables, and figures are produced in R.

Obtain the authors' original data from their replication materials and place the following three files in `data/raw/authors/`:

- `F1DataMainVariables.xlsx`: race-level event flags, race information, and driver information.
- `F1StataData.dta`: used to validate the independently reconstructed variables.
- `F1VariableDictionary.xlsx`: the authors' variable dictionary.

If the original data are stored elsewhere, set the directory through the `F1_AUTHOR_DIR` environment variable. Cached API JSON files and race-report HTML files from public sources are included for offline replication.

## Full replication

Open `f1_replication.Rproj` in RStudio and run:

```r
source("setup.R")
Sys.setenv(F1_OFFLINE = "1")
source("run_submission.R")
```

From the command line:

```sh
Rscript setup.R
F1_OFFLINE=1 Rscript run_submission.R
```

`setup.R` requires an internet connection when dependencies are first installed. The full analysis can run offline using the cache. `run_submission.R` runs data reconstruction, historical validation, extension sample construction, model estimation, and result generation in order. After changing a manual coding table, rerun the same entry script to update subsequent cumulative experience and estimates affected by the change.

## File structure

```text
f1_replication/
├── README.md
├── CODEBOOK.md
├── setup.R
├── run_submission.R
├── f1_replication.Rproj
├── R/
│   ├── 00_config.R
│   ├── 01_rebuild_original.R
│   ├── 02_download_jolpica.R
│   ├── 03_download_wikipedia.R
│   ├── 04_models.R
│   ├── 05_link_and_validate_status.R
│   ├── 06_build_extension.R
│   ├── 07_extension_models.R
│   ├── 08_tables_and_figures.R
│   ├── 10_paper_style_tables.R
│   ├── check_coding.R
│   ├── functions.R
│   ├── model_helpers.R
│   └── paper_style_helpers.R
├── data/
│   ├── manual/
│   ├── raw/
│   │   ├── authors/
│   │   ├── jolpica/
│   │   └── wikipedia/
│   └── processed/
├── report/
│   ├── Empirical.pdf
│   ├── Empirical.tex
│   ├── README.md
│   ├── tables/
│   └── figures/
└── results/
    ├── paper_style/
    ├── tables/
    ├── figures/
    ├── checks/
    ├── models/
    └── sessionInfo.txt
```

`data/raw/authors/` contains files obtained from the original replication materials. `data/processed/` and `results/models/` are generated during execution.

| Script | Function |
|---|---|
| `00_config.R` | Checks dependencies and configures paths and cache options. |
| `01_rebuild_original.R` | Reconstructs cumulative experience from the Excel event flags and checks each variable against the Stata data. |
| `02_download_jolpica.R` | Reads or downloads schedules and race results. |
| `03_download_wikipedia.R` | Reads or downloads race reports and extracts supplementary race information. |
| `04_models.R` | Estimates models (1), (2), and (4) on the historical sample. |
| `05_link_and_validate_status.R` | Links historical driver identities and race results, and measures agreement between status classifications and the authors' coding. |
| `06_build_extension.R` | Checks retirement reasons against completion labels, applies reviewed classifications, constructs the extension sample, and carries forward cumulative experience. |
| `07_extension_models.R` | Estimates the extended model (4), tests differences across periods, and runs sensitivity analyses. |
| `08_tables_and_figures.R` | Exports numerical tables, validation results, figures, software versions, and input hashes. |
| `10_paper_style_tables.R` | Re-estimates the five models and generates comparison tables following the published layout. |
| `check_coding.R` | Checks source-documented race classifications and when events enter subsequent own and teammate cumulative histories. |
| `functions.R` | Functions for data construction, reading, validation, and general output. |
| `model_helpers.R` | Model estimation, clustered standard errors, and random-intercept checks. |
| `paper_style_helpers.R` | Formats and exports comparison tables as PDF, HTML, PNG, and CSV. |

## Manual inputs

| File (`data/manual/`) | Contents |
|---|---|
| `status_mapping.csv` | Rules mapping API statuses to completion, car failure, driver failure, non-starts, and other categories. |
| `dnf_overrides.csv` | Individually reviewed retirement reasons, final classifications, and sources. |
| `disqualification_coding.csv` | Disqualification reasons, primary classifications, and sources. |
| `race_coding.csv` | Weather, track categories, evidence, and sources. |
| `original_team_dummies.csv` | Names and applicable years for the 20 team indicators in the original paper. |
| `modern_team_mapping.csv` | Team identities in the extension period and their correspondence to the original indicators. |
| `published_table1.csv` | Published Table 1 statistics and display precision. |
| `published_table2.csv` | Published coefficient and standard-error benchmarks for models (1), (2), and (4). |

## Results

- `report/Empirical.pdf`: the empirical write-up.
- `report/Empirical.tex`: the LaTeX source, with supporting tables and figures in `report/tables/` and `report/figures/`. Compilation instructions are in `report/README.md`.
- `results/paper_style/paper_style_comparison_tables.pdf`: Table 1, Table 2, and the model (4) extension comparison. The HTML version is `index.html` in the same directory.
- `results/paper_style/refitted_coefficients.csv`: complete coefficients, clustered standard errors, tests, and confidence intervals for the five models.
- `results/paper_style/refitted_model_metadata.csv`: model formulas, sample sizes, race counts, and fit statistics.
- `results/figures/figure1_failure_rates.png`: annual car-failure and driver-failure rates, 1950–2025.
- `results/figures/figure2_car_failure_coefficients.png`: car-failure experience coefficients and 95% confidence intervals for the three estimation samples.
- `results/tables/`: failure rates, coefficient-difference tests, sensitivity estimates, and comparisons with published values.
- `results/tables/sensitivity_failure_experience.csv`: own car- and driver-failure experience estimates under each sensitivity specification; `sensitivity_car_failure.csv` contains the car-failure experience subset.
- `results/checks/`: validation of cumulative variables, controls, classification agreement, sample coverage, and estimation.
- `results/checks/coding_consistency.csv`: classification completeness and coding-rule checks.
- `results/checks/classified_retirement_audit.csv`: checks of API completion labels against retirement reasons in race reports.
- `results/checks/excluded_new_nonstarters.csv`: excluded nonstarter records, including API statuses, race-report classifications, reasons, and source URLs.

`results/checks/input_sha256_manifest.csv` records SHA-256 hashes for the manual inputs, API cache, and key author files to identify the data snapshot used in the analysis.
