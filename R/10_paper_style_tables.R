# Re-estimate the replication and extension models and render comparison tables.
message("10: Refit models and export publication-style comparison tables")
source("R/paper_style_helpers.R", encoding = "UTF-8")
paper_dir <- "results/paper_style"
dir.create(paper_dir, recursive = TRUE, showWarnings = FALSE)
needed <- c("data/processed/original.rds", "data/processed/extended.rds",
            "results/models/original_fits.rds", "results/checks/random_intercept_checks.csv")
if (!all(file.exists(needed)))
  stop("Run data preparation and estimation stages 01-07 before generating comparison tables.")
original <- readRDS("data/processed/original.rds")
extended <- readRDS("data/processed/extended.rds")
spec <- readRDS("results/models/original_fits.rds")
re_checks <- read_csv("results/checks/random_intercept_checks.csv")
stopifnot(max(re_checks$race_intercept_variance) < 1e-6)

refit_paper_model <- function(data, rhs, tag, team_indicators = character()) {
  d <- copy(data)
  separated <- team_indicators[vapply(team_indicators, function(v)
    any(d[[v]] == 1) && sum(d[get(v) == 1, win]) == 0, logical(1))]
  excluded <- 0L
  if (length(separated)) {
    omit <- Reduce(`|`, lapply(separated, function(v) d[[v]] == 1))
    excluded <- sum(omit)
    d <- d[!omit]
  }
  constant <- rhs[vapply(d[, ..rhs], function(x) uniqueN(x) == 1L, logical(1))]
  formula <- reformulate(setdiff(rhs, constant), response = "win")
  fit <- glm(formula, data = d, family = binomial(link = "logit"),
             control = glm.control(maxit = 100, epsilon = 1e-10))
  stopifnot(fit$converged, !anyNA(coef(fit)))
  estimates <- tidy_cluster(fit, d$racenr, tag)
  slopes <- setdiff(names(coef(fit)), "(Intercept)")
  b <- coef(fit)[slopes]
  v <- cluster_vcov(fit, d$racenr)[slopes, slopes, drop = FALSE]
  wald <- as.numeric(crossprod(b, solve(v, b)))
  list(coefficients = estimates,
       metadata = data.table(model = tag, n = nrow(d), races = uniqueN(d$racenr),
          wald_chi2 = wald, wald_df = length(slopes), excluded = excluded,
          log_likelihood = as.numeric(logLik(fit)), formula = paste(deparse(formula), collapse = " ")))
}

fresh_fits <- list()
for (m in c("M1", "M2", "M4")) {
  tag <- paste0("original_", m)
  message("Refitting ", tag)
  fresh_fits[[tag]] <- refit_paper_model(original$model, spec$rhs[[m]], tag)
}
fresh_fits[["full_1950_2025_M4"]] <- refit_paper_model(
  extended$analysis, spec$rhs$M4, "full_1950_2025_M4", spec$top_teams)
fresh_fits[["modern_2018_2025_M4"]] <- refit_paper_model(
  extended$analysis[year >= 2018], spec$rhs$M4, "modern_2018_2025_M4", spec$top_teams)
fresh_coeff <- rbindlist(lapply(fresh_fits, `[[`, "coefficients"))
fresh_meta <- rbindlist(lapply(fresh_fits, `[[`, "metadata"))
write_csv(fresh_coeff, file.path(paper_dir, "refitted_coefficients.csv"))
write_csv(fresh_meta, file.path(paper_dir, "refitted_model_metadata.csv"))

# Validate refitted coefficients against the primary estimation outputs.
primary_coeff <- rbindlist(list(read_csv("results/tables/original_full_coefficients.csv"),
                              read_csv("results/tables/extension_full_coefficients.csv")))
check <- merge(fresh_coeff, primary_coeff,
                  by = c("model", "term"), suffixes = c("_refit", "_reference"))
stopifnot(nrow(check) == nrow(fresh_coeff))
check[, `:=`(coefficient_difference = estimate_refit - estimate_reference,
                 se_difference = se_refit - se_reference)]
stopifnot(max(abs(check$coefficient_difference)) < 1e-10,
          max(abs(check$se_difference)) < 1e-10)
write_csv(check, file.path(paper_dir, "refit_validation.csv"))

# Table 1: original four summary columns, followed by our four R columns.
benchmark1 <- read_csv("data/manual/published_table1.csv")
labels1 <- c("Win", "Podium", "Cumulative Races", "Cumulative Wins",
  "Cumulative Teammate Wins", "Cumulative Car DNF", "Cumulative Driver DNF",
  "Cumulative Teammate Car DNF", "Cumulative Teammate Driver DNF", "Grid Position",
  "Age", "Home Edge", "Wet Weather Conditions", "Permanent Track", "Occasional Track",
  "Number of Drivers Starting")
stopifnot(nrow(benchmark1) == length(labels1))
stats1 <- rbindlist(lapply(seq_len(nrow(benchmark1)), function(i) {
  a <- benchmark1[i]
  x <- original$model[[a$variable]]
  cbind(a, r_mean = mean(x), r_sd = sd(x), r_min = min(x), r_max = max(x))
}))
summary_cell <- function(x, stat, variable, digits) {
  d <- if (stat %in% c("min", "max")) if (variable == "age") 2L else 0L else digits
  formatC(x, format = "f", digits = d)
}
cells1 <- matrix("", nrow = nrow(stats1), ncol = 8L)
for (i in seq_len(nrow(stats1))) {
  for (j in seq_along(c("mean", "sd", "min", "max"))) {
    stat <- c("mean", "sd", "min", "max")[j]
    pub <- stats1[[paste0("published_", stat)]][i]
    rebuilt <- stats1[[paste0("r_", stat)]][i]
    args <- list(stat = stat, variable = stats1$variable[i], digits = stats1$digits[i])
    cells1[i, j] <- do.call(summary_cell, c(list(x = pub), args))
    cells1[i, j + 4L] <- do.call(summary_cell, c(list(x = rebuilt), args))
    stopifnot(identical(cells1[i, j], cells1[i, j + 4L]))
  }
}
write_csv(stats1, file.path(paper_dir, "table1_numeric_validation.csv"))
table1 <- list(key = "table1_paper_style", number = "Table 1", title = "Summary Statistics",
  groups = list(list(label = "Published: Lapré and Cravey (2022)", n = 4L),
                list(label = "Our replication (R)", n = 4L)),
  column_headers = rep(c("Mean", "Standard\ndeviation", "Min", "Max"), 2),
  column_ids = c("Published_mean", "Published_sd", "Published_min", "Published_max",
                 "R_mean", "R_sd", "R_min", "R_max"),
  row_labels = labels1, row_types = rep("summary", nrow(cells1)), cells = cells1,
  label_width = 2.88, header_height = .43,
  notes = c("Note. N = 21,487 in both panels. All statistics use the published display precision. Cumulative experience was rebuilt in R from the race-level flags before applying the original sample exclusion.",
            "Source: Lapré and Cravey (2022), Table 1, and our independent R calculations."))

# Published model (3) is included as a reference column.
# Its three displayed coefficients come from the authors' full Stata output,
# page 5; its Wald statistic is reported in the paper's Table 2. It is not an
# additional replication model. R estimates cover models (1), (2), and (4).
published2 <- read_csv("data/manual/published_table2.csv")
published3 <- data.table(model = "original_M3", term = c("crace", "crace2", "start"),
  published_estimate = c(.0122752, -.0000502, -.4739522),
  published_se = c(.0020166, .00000874, .0251414))
published2 <- rbindlist(list(published2, published3))
write_csv(published2, file.path(paper_dir, "published_table2_reference.csv"))
row_terms <- c("crace", "cw", "ctw", "cfc", "cfd", "ctfc", "ctfd", "crace2",
                  "team_fe", "start", "age", "home", "rcwet", "rcperm", "rcocc",
                  "rcstarters", "constant", "wald")
row_labels <- c(crace = "Cumulative Races", cw = "Cumulative Wins",
  ctw = "Cumulative Teammate Wins", cfc = "Cumulative Car DNF", cfd = "Cumulative Driver DNF",
  ctfc = "Cumulative Teammate Car DNF", ctfd = "Cumulative Teammate Driver DNF",
  crace2 = "(Cumulative Races)^2", team_fe = "Team fixed effects", start = "Grid Position",
  age = "Age", home = "Home edge", rcwet = "Wet weather conditions", rcperm = "Permanent track",
  rcocc = "Occasional track", rcstarters = "Number of drivers starting", constant = "Constant",
  n = "Observations", races = "Number of races", wald = "Wald chi2")
coefficient_terms <- c("crace", "cw", "ctw", "cfc", "cfd", "ctfc", "ctfd", "crace2", "start")
published_wald <- c(original_M1 = 642.30, original_M2 = 863.91,
                        original_M3 = 736.97, original_M4 = 915.82)

model_cell <- function(tag, term_name, published = FALSE) {
  if (term_name %in% coefficient_terms) {
    d <- if (published) published2[model == tag & term == term_name]
         else fresh_coeff[model == tag & term == term_name]
    if (!nrow(d)) return("")
    stopifnot(nrow(d) == 1L)
    if (published) {
      b <- d$published_estimate
      se <- d$published_se
      p <- 2 * pnorm(-abs(b / se))
    } else {
      b <- d$estimate
      se <- d$se
      p <- d$p
    }
    return(paper_coef(b, se, p, term_name))
  }
  if (term_name == "team_fe") return(if (tag %in% c("original_M1", "original_M2")) "No" else "Yes")
  if (term_name == "wald") {
    w <- if (published) published_wald[[tag]] else fresh_meta[model == tag, wald_chi2]
    return(paste0(formatC(w, format = "f", digits = 2), "***"))
  }
  if (term_name == "n") return(if (published) "21,487" else format(fresh_meta[model == tag, n], big.mark = ","))
  if (term_name == "races") return(if (published) "965" else format(fresh_meta[model == tag, races], big.mark = ","))
  "Yes"
}

published_models <- paste0("original_M", 1:4)
replication_models <- paste0("original_M", c(1, 2, 4))
cells2 <- matrix("", nrow = length(row_terms), ncol = 7L)
for (i in seq_along(row_terms)) {
  cells2[i, 1:4] <- vapply(published_models, model_cell, character(1),
                             term_name = row_terms[i], published = TRUE)
  cells2[i, 5:7] <- vapply(replication_models, model_cell, character(1),
                             term_name = row_terms[i], published = FALSE)
}
# Replicated models must reproduce the published coefficient cells.
assigned_rows <- which(row_terms %in% coefficient_terms)
stopifnot(identical(unname(cells2[assigned_rows, c(1, 2, 4)]),
                    unname(cells2[assigned_rows, 5:7])))
table2 <- list(key = "table2_paper_style", number = "Table 2",
  title = "Logistic Regression Models for Win: Base Models",
  groups = list(list(label = "Published: Lapré and Cravey (2022)", n = 4L),
                list(label = "Our replication (R)", n = 3L)),
  column_headers = c("(1)", "(2)", "(3)", "(4)", "(1)", "(2)", "(4)"),
  column_ids = c("Published_1", "Published_2", "Published_3", "Published_4", "R_1", "R_2", "R_4"),
  row_labels = unname(row_labels[row_terms]),
  row_types = ifelse(row_terms %in% coefficient_terms, "coef", "info"),
  cells = cells2, label_width = 2.70, header_height = .34,
  notes = c("Notes. N = 21,487. Standard errors adjusted for clustering on observations by race are in parentheses. Published model (3) is included for reference; R estimates cover models (1), (2), and (4).",
            "* Significant at 0.05; ** at 0.01; and *** at 0.001.",
            "Source: Lapré and Cravey (2022), Table 2, and R estimates of models (1), (2), and (4)."))

# Same publication layout for model (4), adding the full and modern samples.
extension_terms <- c(setdiff(row_terms, c("crace", "wald")), "n", "races", "wald")
extension_models <- c("original_M4", "full_1950_2025_M4", "modern_2018_2025_M4")
cellsE <- matrix("", nrow = length(extension_terms), ncol = 4L)
for (i in seq_along(extension_terms)) {
  cellsE[i, 1] <- model_cell("original_M4", extension_terms[i], TRUE)
  cellsE[i, 2:4] <- vapply(extension_models, model_cell, character(1),
                             term_name = extension_terms[i], published = FALSE)
}
tableE <- list(key = "table2_extension_paper_style", number = "Table 2E",
  title = "Logistic Regression Models for Win: Model (4), Replication and Extension",
  groups = list(list(label = "Published", n = 1L), list(label = "Our estimates (R)", n = 3L)),
  column_headers = c("(4)\n1950-2017", "(4)\n1950-2017", "(4)\n1950-2025", "(4)\n2018-2025"),
  column_ids = c("Published_M4", "R_original_M4", "R_full_M4", "R_modern_M4"),
  row_labels = unname(row_labels[extension_terms]),
  row_types = ifelse(extension_terms %in% coefficient_terms, "coef", "info"),
  cells = cellsE, label_width = 2.85, header_height = .48,
  notes = c("Notes. Standard errors adjusted for clustering by race are in parentheses. All R columns re-estimate model (4) with the original control definitions and legacy team indicators; absent indicators are omitted in a subsample.",
    sprintf("The modern sample contains %s starts. Its regression excludes %s Williams observations because the team indicator perfectly predicts non-winning; those observations remain in cumulative experience histories. The modern estimation sample is N = %s.",
      format(extended$analysis[year >= 2018, .N], big.mark = ",", trim = TRUE),
      format(fresh_meta[model == "modern_2018_2025_M4", excluded], big.mark = ",", trim = TRUE),
      format(fresh_meta[model == "modern_2018_2025_M4", n], big.mark = ",", trim = TRUE)),
    "* Significant at 0.05; ** at 0.01; and *** at 0.001. Published column: Lapré and Cravey (2022), Table 2, model (4)."))

paper_tables <- list(table1, table2, tableE)
export_paper_tables(paper_tables, paper_dir)
write_session_info(file.path(paper_dir, "sessionInfo.txt"))
message("Comparison tables and coefficient validation completed.")
print(fresh_meta[, .(model, n, races, wald_chi2, excluded)])
