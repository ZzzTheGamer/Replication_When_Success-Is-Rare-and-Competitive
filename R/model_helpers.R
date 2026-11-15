# Estimation helper shared by the original and extension scripts.
fit_one <- function(d, rhs_terms, name, check_random = TRUE) {
  d <- copy(d)
  # Terms that are zero in the entire subsample have no estimable coefficient.
  zeros <- rhs_terms[vapply(d[, ..rhs_terms], function(x) length(unique(x)) == 1L, logical(1))]
  rhs_terms <- setdiff(rhs_terms, zeros)
  formula <- reformulate(rhs_terms, response = "win")
  fit <- glm(formula, family = binomial(link = "logit"), data = d,
             control = glm.control(maxit = 100, epsilon = 1e-10))
  if (!fit$converged) stop("Logit did not converge: ", name)
  estimates <- tidy_cluster(fit, d$racenr, name)
  slope_names <- setdiff(names(coef(fit)), "(Intercept)")
  slope_vcov <- cluster_vcov(fit, d$racenr)[slope_names, slope_names, drop = FALSE]
  slope_beta <- coef(fit)[slope_names]
  joint_wald <- as.numeric(crossprod(slope_beta, solve(slope_vcov, slope_beta)))
  re_check <- NULL
  if (check_random) {
    # Reparameterisation improves numeric conditioning; the model is identical.
    re_data <- copy(d)
    re_data[, crace2_10k := crace2 / 10000]
    re_terms <- sub("^crace2$", "crace2_10k", rhs_terms)
    re_formula <- as.formula(paste("win ~", paste(re_terms, collapse = " + "), "+ (1 | racenr)"))
    re_fit <- lme4::glmer(re_formula, data = re_data, family = binomial,
                         nAGQ = 1,
                         control = lme4::glmerControl(optimizer = "bobyqa",
                           optCtrl = list(maxfun = 200000), calc.derivs = FALSE))
    rb <- lme4::fixef(re_fit)
    if ("crace2_10k" %in% names(rb)) {
      rb["crace2_10k"] <- rb["crace2_10k"] / 10000
      names(rb)[names(rb) == "crace2_10k"] <- "crace2"
    }
    re_check <- data.table(model = name,
      race_intercept_variance = as.numeric(lme4::VarCorr(re_fit)$racenr),
      max_abs_coefficient_difference = max(abs(rb[names(coef(fit))] - coef(fit))),
      logLik_glm = as.numeric(logLik(fit)), logLik_glmer = as.numeric(logLik(re_fit)),
      singular = lme4::isSingular(re_fit),
      convergence_message = paste(re_fit@optinfo$conv$lme4$messages, collapse = "; "))
    if (re_check$race_intercept_variance > 1e-6 ||
        re_check$max_abs_coefficient_difference > 1e-4)
      stop("Race effect is not negligible in ", name,
           "; review the GLMM estimator before using the ordinary-logit shortcut.")
    saveRDS(re_fit, file.path("results/models", paste0(name, "_random_intercept.rds")))
  }
  saveRDS(fit, file.path("results/models", paste0(name, ".rds")))
  list(fit = fit, coefficients = estimates, random_check = re_check,
       metadata = data.table(model = name, n = nrow(d), races = uniqueN(d$racenr),
          wins = sum(d$win), log_likelihood = as.numeric(logLik(fit)),
          wald_chi2 = joint_wald, wald_df = length(slope_names),
          omitted_constant_terms = paste(zeros, collapse = ", ")))
}
