# Shared helpers for data construction, validation, and output.
write_csv <- function(x, file) data.table::fwrite(x, file, na = "")
read_csv <- function(file) data.table::fread(file, na.strings = c("", "NA"))

report_has_retirement_reason <- function(reason) {
  text <- trimws(gsub("\\[[^]]*\\]", "", reason))
  !is.na(text) & nzchar(text) & !grepl("^[+]?[0-9]", text)
}

write_session_info <- function(file) {
  info <- sessionInfo()
  for (field in c("BLAS", "LAPACK")) {
    if (is.character(info[[field]]) && length(info[[field]]) == 1L)
      info[[field]] <- basename(info[[field]])
  }
  capture.output(print(info), file = file)
}

get_cached <- function(url, file, pause = 0.30) {
  if (file.exists(file) && !refresh_downloads) return(invisible(file))
  if (!download_sources) stop("Offline mode: missing cache ", file)
  h <- curl::new_handle(useragent = "ISOM753 academic replication (R; cached public data)",
                        connecttimeout = 15, timeout = 60)
  for (attempt in seq_len(5L)) {
    response <- try(curl::curl_fetch_memory(url, handle = h), silent = TRUE)
    if (!inherits(response, "try-error") && response$status_code == 200L) {
      writeBin(response$content, file)
      Sys.sleep(pause)
      return(invisible(file))
    }
    if (attempt < 5L) Sys.sleep(min(2^attempt, 30))
  }
  stop("Download failed: ", url)
}

# Each exposure is aggregated over a driver's entire race first. Subtracting the
# current race ensures all rows in a shared-drive race have the same prior history.
prior_exposure <- function(dt, event, output, id = "driverid") {
  z <- dt[, .(increment = sum(get(event))), by = c(id, "racenr")]
  setorderv(z, c(id, "racenr"))
  z[, prior := cumsum(increment) - increment, by = id]
  dt[z, on = c(id, "racenr"), (output) := i.prior]
  invisible(dt)
}

add_experience <- function(dt) {
  # Recompute same-race exposures from flags, including the author's drive shares.
  dt[, `:=`(grid = 1 / ncs, xwin = win / nds, pod = as.numeric(finish <= 3) / nds)]
  dt[, `:=`(tw = sum(xwin) / ncs - xwin,
            tfc = sum(dnfc) / ncs - dnfc,
            tfd = sum(dnfd) / ncs - dnfd), by = .(racenr, team)]
  events <- c(crace = "grid", cw = "xwin", ctw = "tw", cfc = "dnfc",
              cfd = "dnfd", ctfc = "tfc", ctfd = "tfd")
  for (v in names(events)) prior_exposure(dt, events[[v]], v)
  dt[, crace2 := crace^2]
  invisible(dt)
}

normalise_name <- function(x) {
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  gsub("[^a-z0-9]", "", tolower(x))
}

as_stata_float <- function(x) {
  # Reproduce Stata's IEEE-754 single-precision storage when checking its .dta.
  readBin(writeBin(as.numeric(x), raw(), size = 4), numeric(), n = length(x), size = 4)
}

cluster_vcov <- function(model, race) {
  # Matches Stata vce(cluster race): G/(G-1) finite-cluster correction, HC0.
  sandwich::vcovCL(model, cluster = race, type = "HC0", cadjust = TRUE)
}

tidy_cluster <- function(model, race, name) {
  v <- cluster_vcov(model, race)
  b <- coef(model)
  se <- sqrt(diag(v))
  data.table(model = name, term = names(b), estimate = unname(b), se = unname(se),
             z = unname(b / se), p = 2 * pnorm(-abs(b / se)),
             conf_low = unname(b - qnorm(.975) * se),
             conf_high = unname(b + qnorm(.975) * se))
}

html_table <- function(dt, file, caption, digits = 4, note = "") {
  body <- knitr::kable(as.data.frame(dt), format = "html", row.names = FALSE,
                       digits = digits, caption = caption, escape = TRUE)
  css <- "body{font:15px Georgia,serif;margin:32px;color:#17242f}table{border-collapse:collapse;font:13px Arial,sans-serif;max-width:100%}caption{text-align:left;font:bold 17px Georgia;margin-bottom:14px}th,td{padding:7px 10px;border-bottom:1px solid #d7dce0;text-align:right;white-space:pre-line}th:first-child,td:first-child{text-align:left}thead{border-top:2px solid #243e50;border-bottom:1.5px solid #243e50}p{max-width:1000px;line-height:1.5}"
  writeLines(c("<!doctype html><html><head><meta charset='utf-8'>",
               paste0("<style>", css, "</style></head><body>"), body,
               paste0("<p>", note, "</p></body></html>")), file)
}
