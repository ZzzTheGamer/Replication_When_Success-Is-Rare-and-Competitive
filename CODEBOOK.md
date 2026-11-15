# Codebook: Data, Variable Construction, and Model Specifications

## 1. Data Sources and Unit of Observation

| Period / purpose | Data source | Content used |
|---|---|---|
| Variable construction, 1950–2017 | `F1DataMainVariables.xlsx` | Race-level event flags in the `1950-2017` sheet; race and driver information in the `Races` and `Drivers` sheets. |
| Historical validation | `F1StataData.dta` | Validation of independently rebuilt cumulative variables, controls, and team indicators. |
| Variable definitions | `F1VariableDictionary.xlsx` and the paper's variable descriptions | Historical variable definitions and counting rules for shared drives. |
| Race results, 2018–2025 | Jolpica's Ergast-compatible API | Schedules, driver identities, teams, grid positions, results, and status. |
| Supplementary coding for the extension period | Race reports and `data/manual/` | Retirement reasons, pit-lane starts, weather, and track types; sources are retained in the coding files. |
| Published benchmarks | `published_table1.csv`, `published_table2.csv` | Table 1 statistics and coefficients and standard errors for the specified Table 2 models. |

The original historical unit of observation is driver–car–race. Shared drives produce multiple records for some drivers in the same race. Original rows are uniquely identified by `racenr + driverid + car + finish`. Cumulative experience is constructed using all 21,616 rows before excluding the 129 rows with `ncs > 1`, leaving 21,487 estimation observations, 965 races, and 655 drivers. This order preserves the contribution of excluded observations to subsequent experience histories.

The extension includes main races only. The 2018–2025 period contains 173 races. Excluding 17 nonstarter records from 3,458 API results leaves 3,441 starts. New races are ordered by year and round, with `racenr` continuing from 966 to 1,138. Driver identities are linked using standardized names and birth dates. Historical drivers retain their original `driverid`; new drivers receive new IDs. The process stops if a returning historical driver cannot be linked.

## 2. Race-Level Variables and Experience Increments

`win`, `dnfc`, and `dnfd` record outcomes in the current race; cumulative experience variables record experience available before the race starts. The 1950–2017 event flags come directly from the authors' Excel workbook, while the cumulative columns are recalculated from those flags.

| Variable | Type / unit | Definition and construction |
|---|---|---|
| `win` | Binary | 1 if the driver wins the current race, 0 otherwise; the dependent variable. |
| `finish` | Position | Final position in the results list; API `position` is used for the extension period. |
| `ncs` | Number of cars | Number of cars driven by the current driver in the race. |
| `nds` | Number of drivers | Number of drivers sharing the current car in the race. |
| `grid` | Race participation increment | `1/ncs`, preventing multiple cars driven by the same driver in the same race from being counted as multiple races. |
| `xwin` | Win increment | `win/nds`, allocating historical win experience by the number of drivers sharing the car. |
| `pod` | Podium share | `I(finish <= 3)/nds`; used in Table 1. |
| `dnfc` | Binary | 1 if the driver does not finish the current race for car-related reasons. |
| `dnfd` | Binary | 1 if the driver does not finish the current race for reasons related to driving, accidents, physical condition, or sporting rules. |
| `tw` | Teammate win increment | `sum(xwin)/ncs - xwin`, summed over all original rows for the same team in the same race. |
| `tfc` | Teammate car-failure increment | `sum(dnfc)/ncs - dnfc`, with the same summation group. |
| `tfd` | Teammate driver-failure increment | `sum(dnfd)/ncs - dnfd`, with the same summation group. |

`grid` is an internal participation weight; grid position is recorded separately as `start`. Teammate increments subtract the driver's own outcome and follow the authors' shared-drive adjustments. Teammates are identified by the actual team in each race, measuring teammate experience encountered while racing together.

## 3. Cumulative Experience Variables

For each driver, increments in the original rows are first aggregated within each race, ordered by `racenr`, and cumulatively summed, with the current race's increment then subtracted. The variables below therefore use only outcomes from earlier races. All rows for the same driver in a shared-drive race have the same pre-race history.

| Variable | Definition | Construction rationale | Models |
|---|---|---|---|
| `crace` | Cumulative prior races | Sum of `grid` over earlier races, measuring total racing experience. | (1) |
| `cw` | Cumulative prior own wins | Sum of `xwin` over earlier races, separating successful experience from general racing experience. | (2), (4) |
| `ctw` | Cumulative prior teammate wins | Sum of `tw` over earlier races, including only teammate wins in races in which the driver also participated. | (2), (4) |
| `cfc` | Cumulative prior own car failures | Sum of `dnfc` over earlier races; the experience variable examined in the extension test. | (2), (4) |
| `cfd` | Cumulative prior own driver failures | Sum of `dnfd` over earlier races, estimated separately from car-failure experience. | (2), (4) |
| `ctfc` | Cumulative prior teammate car failures | Sum of `tfc` over earlier races. | (2), (4) |
| `ctfd` | Cumulative prior teammate driver failures | Sum of `tfd` over earlier races. | (2), (4) |
| `crace2` | Squared cumulative races | `crace^2`, allowing a nonlinear relationship with total racing experience. | (1), (2), (4) |

Drivers retain their accumulated own and teammate experience after changing teams. A new teammate relationship generates increments only when the drivers begin racing together. Teammate outcomes from races in which they did not participate together are not included in the driver's history.

The extension records are combined with the original historical records before recalculating cumulative experience. An existing driver's first observation in the extension period starts with the closing cumulative balance through 2017; first-time drivers start at zero. No experience accrues during absences. The code verifies each historical driver's cumulative balance on entering the extension period. Nonstarter records generate neither own nor teammate experience increments.

Implementation: `prior_exposure()` and `add_experience()` in `R/functions.R`. Historical row-level validation is saved in `results/checks/cumulative_validation.csv`.

## 4. Control Variables

| Variable | Type / unit | Definition and treatment |
|---|---|---|
| `start` | Grid position | Lower values indicate positions closer to the front. Historical values follow the authors' records. The extension uses API `grid`; pit-lane starts identified by API grid 0 or `PL` in the race report are assigned `max(API grid in the race, actual starters)+1`. Pit-lane starters in the same race receive the same value so that the coding uses only pre-race information. |
| `age` | Years | Age on race day. Dates are converted to `Y+(M-1)/12+(D-1)/360` and subtracted, rounded to three decimal places, and represented using Stata single-precision storage to match the historical calculation. |
| `home` | Binary | 1 if the race country matches the driver's country. In the extension, nationality is mapped to country and country names are standardized. |
| `rcwet` | Binary | 1 if the main race starts in wet conditions or has actual rainfall. Rain during practice or qualifying alone is excluded. Extension coding follows `race_coding.csv`. |
| `rcperm` | Binary | 1 for a permanent track, 0 otherwise. |
| `rcocc` | Binary | 1 for a temporary / street track, 0 otherwise. `rcperm=0` and `rcocc=0` identify the semi-permanent reference category. |
| `rcstarters` | Number of drivers | Actual starters in the race. In the extension, this is counted after excluding nonstarters, preserving the actual field size. |

Historical control and team-indicator validation is saved in `results/checks/control_validation.csv`. Race-level weather and track classifications for the extension, with supporting evidence and sources, are recorded in `data/manual/race_coding.csv`.

## 5. Retirement Classification and Historical Agreement

`data/manual/status_mapping.csv` classifies all API status values. The rules are as follows:

| Category | Classification rule | Event variables |
|---|---|---|
| `none` | Normal finishes and finishes laps behind the winner. | `dnfc=0, dnfd=0` |
| `car` | Status explicitly attributes the outcome to mechanical, component, or resource-related causes. | `dnfc=1, dnfd=0` |
| `driver` | Status attributes the outcome to accidents, collisions, spinning off, physical conditions, or sporting rules; the main classification assigns disqualifications to this category. | `dnfc=0, dnfd=1` |
| `unknown` | Status gives no reason that permits car / driver classification. | Assigned after individual verification in the extension period. |
| `withdrawal` | Withdrawn entries; whether the driver actually started distinguishes nonstarts from withdrawals during the race. | Treated according to start status and the verified reason. |
| `nonstarter` | Did not actually start. | Excluded; no experience increment. |

Zero completed laps alone do not determine whether a driver started; result status and race reports are used to identify actual starts. Early retirements are coded by cause even if the results list still assigns an official classified position.

For the extension period, `dnf_overrides.csv` supplies the reason, final category, and source for 161 records with unspecified causes. Individual reviews of disqualifications and alternative classifications are stored in `dsq_sensitivity.csv`, supporting sensitivity estimates that reclassify technical disqualifications as car failures.

Historical agreement is evaluated against the authors' `dnfc` and `dnfd` labels without replacing their event flags. Records are first linked by driver identity, year, round, and car number. If car numbers differ but the driver–race result is unique, that unique result is used to complete the link. Outputs report linkage coverage, agreement across all linked observations, and agreement within the authors' retirement subsample. The same agreement rates are also reported for informative status values. The conservative measure counts unknown categories and conflicting start statuses as disagreements. Metrics and the contingency table are saved in `status_agreement_metrics.csv` and `status_confusion_matrix.csv`, respectively.

## 6. Team Indicators

Model (4) includes the authors' 20 specified team indicators. `original_team_dummies.csv` lists the team names and applicable years for each indicator; all other teams form the reference group. Matching uses both name and year to preserve the authors' distinctions between historical teams.

`modern_team_mapping.csv` specifies the correspondence between extension-period teams and historical indicators. Ferrari, McLaren, modern Mercedes, Red Bull, and Williams retain their original indicators; other extension-period teams are assigned to the corresponding reference categories in that file. Teammate experience is still grouped by the actual team in each race. Team names or organizational continuity do not alter a driver's accumulated experience.

## 7. Model Formulas and Estimation

The dependent variable is `win`, estimated using binary logit. The Table 2 replication specifications are:

```r
controls <- c("start", "age", "home", "rcwet", "rcperm", "rcocc", "rcstarters")
experiences <- c("cw", "ctw", "cfc", "cfd", "ctfc", "ctfd", "crace2")

# Table 2 model (1)
model_1 <- win ~ crace + crace2 +
  start + age + home + rcwet + rcperm + rcocc + rcstarters

# Table 2 model (2)
model_2 <- win ~ cw + ctw + cfc + cfd + ctfc + ctfd + crace2 +
  start + age + home + rcwet + rcperm + rcocc + rcstarters

# Table 2 model (4)
model_4 <- update(model_2, . ~ . +
  t5dalf + t5dben + t5dbra + t5dbrm + t5dbrw +
  t5dcoo + t5dfer + t5dlig + t5dlot + t5dmas +
  t5dmcl + t5dme2 + t5dmer + t5dre2 + t5dred +
  t5dren + t5dtyr + t5dvan + t5dwal + t5dwil)
```

Model (1) estimates total racing experience and its square. Model (2) separates own and teammate experience into success and two types of failure while retaining squared racing experience. Model (4) adds the team indicators above. All three models include an intercept. The extension applies the same model (4) specification to 1950–2025 and 2018–2025 separately.

Race random-intercept checks use `lme4::glmer`, adding `(1 | racenr)` to the fixed-effects formula and using Laplace integration. In all five models, the race random-intercept variance is at the numerical zero boundary, and fixed coefficients differ from ordinary logit by less than `2e-6`. Reported coefficients therefore use `glm(..., family=binomial(link="logit"))`. For numerical stability, `crace2` is divided by 10,000 in the random-intercept checks and converted back to its original units for output.

Standard errors are clustered by race using:

```r
sandwich::vcovCL(model, cluster = race_id, type = "HC0", cadjust = TRUE)
```

Here, `race_id` is `racenr` in the estimation sample. `cadjust=TRUE` applies the `G/(G-1)` correction, where `G` is the number of races. Tests use z statistics with the normal approximation; 95% confidence intervals equal the coefficient plus or minus `1.96 × SE`. Coefficients are in log-odds units.

In the modern sample, the Williams team indicator perfectly predicts non-winning. Its 343 observations are therefore excluded only from the modern regression, and constant indicators are removed, leaving 3,098 estimation observations. These observations remain in cumulative histories and failure-rate calculations; `rcstarters` retains the actual number of starters. The full 1950–2025 model uses 24,928 observations. Exclusion counts and random-intercept checks are recorded in `perfect_prediction_summary.csv` and `random_intercept_checks.csv`, respectively.

## 8. Comparing Car-Failure Experience across Periods

The comparison uses the `cfc` coefficients from historical model (4) and modern model (4), defined as:

```text
delta = beta_cfc_2018_2025 - beta_cfc_1950_2017
SE(delta) = sqrt(SE_2018_2025^2 + SE_1950_2017^2)
z = delta / SE(delta)
```

Race clusters do not overlap between the two periods, so cross-period covariance is set to zero under race-clustered inference. The two-sided null is `delta=0`; the one-sided alternative for weaker learning is `delta<0`. All coefficients are estimated separately across periods. Output is saved in `results/tables/car_failure_coefficient_change.csv`.

Car-failure rates in each period use actual-start observations: `sum(dnfc)/number of start records`. Perfect-prediction exclusions in the modern regression do not change this denominator. Annual and period summaries are saved in `annual_failure_rates.csv` and `failure_rates_by_period.csv`, respectively.
