message("04: Fit Table 2 models (1), (2), and (4) with race-clustered standard errors")
o <- readRDS("data/processed/original.rds")
original_model <- o$model
top_teams <- sort(unique(read_csv("data/manual/original_team_dummies.csv")$dummy))
controls <- c("start", "age", "home", "rcwet", "rcperm", "rcocc", "rcstarters")
experiences <- c("cw", "ctw", "cfc", "cfd", "ctfc", "ctfd", "crace2")
rhs <- list(M1 = c("crace", "crace2", controls),
            M2 = c(experiences, controls),
            M4 = c(experiences, top_teams, controls))


original_fits <- lapply(names(rhs), function(m) {
  message("Estimating original ", m)
  fit_one(original_model, rhs[[m]], paste0("original_", m))
})
names(original_fits) <- names(rhs)
write_csv(rbindlist(lapply(original_fits, `[[`, "coefficients")),
          "results/tables/original_full_coefficients.csv")
write_csv(rbindlist(lapply(original_fits, `[[`, "random_check")),
          "results/checks/random_intercept_checks.csv")
saveRDS(list(fits = original_fits, rhs = rhs, top_teams = top_teams, controls = controls),
        "results/models/original_fits.rds")
