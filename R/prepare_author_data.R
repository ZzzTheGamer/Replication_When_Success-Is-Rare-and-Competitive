# Locate the original author files without requiring machine-specific paths.
# The submitted Canvas package already contains the required files.
prepare_author_data <- function() {
  required <- c("F1DataMainVariables.xlsx", "F1StataData.dta",
                "F1VariableDictionary.xlsx")
  destination <- file.path("data", "raw", "authors")
  complete <- function(directory)
    nzchar(directory) && all(file.exists(file.path(directory, required)))
  use_directory <- function(directory) {
    directory <- normalizePath(directory, winslash = "/", mustWork = TRUE)
    Sys.setenv(F1_AUTHOR_DIR = directory)
    invisible(directory)
  }
  supplied <- Sys.getenv("F1_AUTHOR_DIR")
  if (nzchar(supplied)) {
    if (!complete(supplied))
      stop("F1_AUTHOR_DIR must contain all three original author files.")
    return(use_directory(supplied))
  }
  if (complete(destination)) return(use_directory(destination))

  search_dirs <- unique(c(getwd(), dirname(getwd()), path.expand("~/Downloads")))
  folders <- file.path(search_dirs, "replication_package_MS-OPM-20-00741")
  for (folder in folders) {
    if (complete(folder)) {
      dir.create(destination, recursive = TRUE, showWarnings = FALSE)
      if (!all(file.copy(file.path(folder, required), destination, overwrite = TRUE)))
        stop("Could not copy the original files into data/raw/authors/.")
      message("Original author data prepared in data/raw/authors/.")
      return(use_directory(destination))
    }
  }

  archives <- unique(unlist(lapply(search_dirs, function(directory) {
    if (!dir.exists(directory)) return(character())
    list.files(directory,
      pattern = "^(mnsc[.]2022[.]4324|replication_package_MS-OPM-20-00741).*[.]zip$",
      full.names = TRUE, ignore.case = TRUE)
  }), use.names = FALSE))
  for (archive in archives) {
    contents <- tryCatch(utils::unzip(archive, list = TRUE), error = function(e) NULL)
    if (is.null(contents)) next
    members <- contents$Name[basename(contents$Name) %in% required &
      !grepl("(^|/)__MACOSX/", contents$Name)]
    if (length(members) != length(required) ||
        anyDuplicated(basename(members)) ||
        !setequal(basename(members), required)) next
    normalized_members <- chartr(intToUtf8(92), "/", members)
    if (any(grepl("(^|/)[.][.](/|$)|^/|^[A-Za-z]:", normalized_members)))
      stop("Unsafe paths in the original data archive.")
    staging <- tempfile("f1_author_data_")
    dir.create(staging)
    on.exit(unlink(staging, recursive = TRUE), add = TRUE)
    utils::unzip(archive, files = members, exdir = staging, junkpaths = TRUE)
    if (!complete(staging)) stop("The original data archive could not be extracted.")
    dir.create(destination, recursive = TRUE, showWarnings = FALSE)
    if (!all(file.copy(file.path(staging, required), destination, overwrite = TRUE)))
      stop("Could not copy the original files into data/raw/authors/.")
    message("Original author data extracted into data/raw/authors/.")
    return(use_directory(destination))
  }
  stop(paste(
    "Original author data are missing.",
    "Place mnsc.2022.4324.zip beside run_submission.R or in Downloads, then run again.",
    "Obtain the ZIP from the original article's supplemental materials."))
}
