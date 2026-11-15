# All paths below are relative to the project folder.
# Before running interactively, use setwd() to select this folder in R/RStudio.
required <- c("data.table", "readxl", "haven", "jsonlite", "curl", "xml2",
              "rvest", "lme4", "sandwich", "ggplot2", "knitr", "png", "digest")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Run setup.R first. Missing: ", paste(missing, collapse = ", "))
library(data.table)
options(stringsAsFactors = FALSE, scipen = 7)
set.seed(753)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
for (d in c("data/raw/jolpica", "data/raw/wikipedia", "data/manual", "results/tables",
            "results/figures", "results/checks", "results/models"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

# F1_AUTHOR_DIR can specify the directory containing the author data files.
author_candidates <- c(Sys.getenv("F1_AUTHOR_DIR"), "data/raw/authors",
                       path.expand("~/Downloads/replication_package_MS-OPM-20-00741"))
author_candidates <- author_candidates[nzchar(author_candidates)]
author_dir <- author_candidates[file.exists(file.path(author_candidates,
                                                     "F1DataMainVariables.xlsx"))][1]
if (is.na(author_dir)) stop("Set F1_AUTHOR_DIR to the extracted author replication package.")
api_base <- "https://api.jolpi.ca/ergast/f1"
# Cached downloads are reused. Set TRUE only when deliberately refreshing sources.
refresh_downloads <- identical(Sys.getenv("F1_REFRESH"), "1")
download_sources <- !identical(Sys.getenv("F1_OFFLINE"), "1")

# Manual input files are reviewed decisions, never inferred from the outcome model.
manual_dir <- "data/manual"
source("R/functions.R")
source("R/model_helpers.R")
