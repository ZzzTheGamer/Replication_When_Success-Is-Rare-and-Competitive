# Run once from the project folder: source("setup.R")
# Packages are standard CRAN packages. No Stata or Python is required.
packages <- c("data.table", "readxl", "haven", "jsonlite", "curl", "xml2",
              "rvest", "lme4", "sandwich", "ggplot2", "knitr", "png", "digest")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message("Dependencies available. Run source('run_submission.R') next.")
