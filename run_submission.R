# Rebuild race-level variables, estimate replication and extension models,
# and generate comparison tables and figures.
script_arg_submission <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg_submission))
  setwd(dirname(normalizePath(sub("^--file=", "", script_arg_submission[1]))))
if (!file.exists("R/00_config.R"))
  stop("Open f1_replication.Rproj or setwd() to the project folder first.")
source("R/00_config.R", encoding = "UTF-8")
submission_steps <- c("01_rebuild_original.R", "02_download_jolpica.R",
  "03_download_wikipedia.R", "04_models.R", "05_link_and_validate_status.R",
  "06_build_extension.R", "07_extension_models.R", "08_tables_and_figures.R",
  "10_paper_style_tables.R")
submission_started <- Sys.time()
for (step in submission_steps) {
  message("\n--- ", step, " ---")
  source(file.path("R", step), encoding = "UTF-8")
}
message("\nReplication and extension completed in ",
  round(as.numeric(difftime(Sys.time(), submission_started, units = "secs")), 1),
  " seconds. Results: results/paper_style/paper_style_comparison_tables.pdf",
  " and results/figures/.")
