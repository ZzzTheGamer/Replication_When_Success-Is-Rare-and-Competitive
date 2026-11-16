message("07: Re-estimate model (4) on full and modern samples; test the change")
spec <- readRDS("results/models/original_fits.rds")
extended <- readRDS("data/processed/extended.rds")
d <- extended$analysis
model4_rhs <- spec$rhs$M4

# A team dummy with zero wins perfectly predicts failure in the modern sample.
# Its MLE is -infinity. As Stata's perfect-prediction handling would do, exclude
# those observations from that model only; retain them in all cumulative histories.
prepare_m4_sample <- function(data) {
  z <- copy(data)
  separated <- spec$top_teams[vapply(spec$top_teams, function(v)
    any(z[[v]] == 1) && sum(z[get(v) == 1, win]) == 0, logical(1))]
  dropped <- z[Reduce(`|`, lapply(separated, function(v) z[[v]] == 1L))]
  if (length(separated)) {
    z <- z[!Reduce(`|`, lapply(separated, function(v) z[[v]] == 1L))]
  } else dropped <- z[0]
  list(data = z, separated = separated, dropped = dropped)
}

full_sample <- prepare_m4_sample(d)
modern_sample <- prepare_m4_sample(d[year >= 2018])
full_fit <- fit_one(full_sample$data, model4_rhs, "full_1950_2025_M4")
modern_fit <- fit_one(modern_sample$data, model4_rhs, "modern_2018_2025_M4")
write_csv(modern_sample$dropped, "results/checks/modern_perfect_prediction_exclusions.csv")
write_csv(data.table(sample = "2018-2025", excluded_rows = nrow(modern_sample$dropped),
                     indicators = paste(modern_sample$separated, collapse = ", ")),
          "results/checks/perfect_prediction_summary.csv")
write_csv(rbindlist(list(full_fit$coefficients, modern_fit$coefficients)),
          "results/tables/extension_full_coefficients.csv")
write_csv(rbindlist(list(spec$fits$M4$metadata, full_fit$metadata, modern_fit$metadata)),
          "results/tables/model_samples.csv")
previous_re <- read_csv("results/checks/random_intercept_checks.csv")
previous_re <- previous_re[!model %in% c("full_1950_2025_M4", "modern_2018_2025_M4")]
re <- rbindlist(list(previous_re,
                    full_fit$random_check, modern_fit$random_check))
write_csv(unique(re, by = "model"), "results/checks/random_intercept_checks.csv")

# Disjoint race clusters across periods imply zero cross-period covariance under
# the mandated race-clustered inference. This is the fully interacted-period Wald
# comparison of the two separately fitted slopes, not a comparison of p-values.
old_cfc <- spec$fits$M4$coefficients[term == "cfc"]
new_cfc <- modern_fit$coefficients[term == "cfc"]
delta <- new_cfc$estimate - old_cfc$estimate
delta_se <- sqrt(new_cfc$se^2 + old_cfc$se^2)
change <- data.table(comparison = "Modern minus original car-failure coefficient",
                     difference = delta, se = delta_se, z = delta / delta_se,
                     p_two_sided = 2 * pnorm(-abs(delta / delta_se)),
                     p_one_sided_weaker = pnorm(delta / delta_se),
                     conf_low = delta - qnorm(.975) * delta_se,
                     conf_high = delta + qnorm(.975) * delta_se)
write_csv(change, "results/tables/car_failure_coefficient_change.csv")

# Focused sensitivity checks for the explicit choices in the manual codebook.
# Recode histories too: changing a DNF affects its driver's and teammates' futures.
rebuild_sensitivity <- function(kind) {
  x <- copy(extended$all_rows)
  if (kind == "ambiguous_retirements_reversed") {
    ii <- which(x$override_ambiguous == 1L)
    oldcar <- x$dnfc[ii]
    x[ii, `:=`(dnfc = 1L - oldcar, dnfd = oldcar)]
  }
  if (kind == "all_disqualifications_as_driver") {
    nf <- extended$new_flags[status_api %in% c("Disqualified", "Excluded")]
    x[nf, on = .(racenr, driverid), `:=`(dnfc = 0L, dnfd = 1L)]
  }
  if (kind == "miami_2022_dry") {
    x[year >= 2018 & year == 2022 & round == 5, rcwet := 0L]
  }
  if (kind == "spa_permanent") {
    # The primary definition preserves the author's semi-permanent category.
    spa_races <- extended$new_flags[circuit_id == "spa", unique(racenr)]
    x[racenr %in% spa_races, rcperm := 1L]
  }
  add_experience(x)
  x <- x[ncs <= 1 & year >= 2018]
  if (kind == "exclude_pitlane_starts") x <- x[pitlane_start == FALSE]
  z <- prepare_m4_sample(x)$data
  sample_n <- nrow(z)
  res <- fit_one(z, model4_rhs, paste0("sensitivity_", kind), check_random = FALSE)
  res$coefficients[term %in% c("cfc", "cfd"), .(scenario = kind, term, estimate, se, p, conf_low, conf_high,
                                    n = sample_n)]
}
sens <- rbindlist(lapply(c("ambiguous_retirements_reversed", "all_disqualifications_as_driver",
                          "miami_2022_dry", "spa_permanent", "exclude_pitlane_starts"),
                        rebuild_sensitivity))
write_csv(sens, "results/tables/sensitivity_failure_experience.csv")
write_csv(sens[term == "cfc", setdiff(names(sens), "term"), with = FALSE],
          "results/tables/sensitivity_car_failure.csv")
saveRDS(list(full = full_fit, modern = modern_fit, change = change,
             sensitivity = sens, modern_separation = modern_sample$separated),
        "results/models/extension_fits.rds")
print(modern_fit$coefficients[term %in% c("cw", "ctw", "cfc", "cfd")])
print(change)
