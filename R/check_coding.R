# Regression checks for documented race events and cumulative-history timing.
check_coding_cases <- function(new_flags, all_rows) {
  checks <- list()
  record <- function(name, passed) {
    checks[[length(checks) + 1L]] <<- data.table(
      check = name, failures = as.integer(!isTRUE(passed)), passed = isTRUE(passed))
  }
  case <- function(y, r, d) new_flags[year == y & round == r & driver_api == d]
  event_check <- function(y, r, d, car, driver) {
    z <- case(y, r, d)
    record(paste(y, r, d, "event_flags", sep = "_"),
           nrow(z) == 1L && z$dnfc == car && z$dnfd == driver)
  }
  event_check(2022, 12, "zhou", 1L, 0L)
  event_check(2024, 11, "norris", 0L, 1L)
  event_check(2019, 1, "ricciardo", 0L, 1L)
  event_check(2023, 16, "albon", 0L, 1L)
  event_check(2023, 16, "bottas", 0L, 1L)
  event_check(2023, 16, "sargeant", 0L, 1L)
  event_check(2020, 13, "max_verstappen", 1L, 0L)
  for (d in c("doohan", "sainz")) {
    z <- case(2025, 1, d)
    record(paste0("zero_lap_actual_starter_", d),
           nrow(z) == 1L && z$laps_api == 0L && z$dnfd == 1L)
  }
  for (v in list(c(2019, 18, "norris"), c(2020, 14, "kevin_magnussen"),
                 c(2023, 19, "alonso"))) {
    z <- case(as.integer(v[1]), as.integer(v[2]), v[3])
    record(paste(c(v, "started_withdrawal"), collapse = "_"),
           nrow(z) == 1L && z$laps_api > 0L && z$dnfc == 1L)
  }
  for (v in list(c(2025, 1, "hadjar"), c(2022, 2, "mick_schumacher"),
                 c(2023, 15, "stroll"))) {
    record(paste(c(v, "pre_start_exclusion"), collapse = "_"),
           nrow(case(as.integer(v[1]), as.integer(v[2]), v[3])) == 0L)
  }
  next_change <- function(y, r, d, variable) {
    event <- all_rows[year == y & round == r & driver_api == d]
    if (nrow(event) != 1L) return(NA_real_)
    later <- all_rows[driverid == event$driverid & racenr > event$racenr][order(racenr)]
    if (!nrow(later)) return(NA_real_)
    later[[variable]][1] - event[[variable]][1]
  }
  record("classified_car_failure_reaches_own_history",
         next_change(2022, 12, "zhou", "cfc") == 1)
  record("classified_car_failure_reaches_teammate_history",
         next_change(2022, 12, "bottas", "ctfc") == 1)
  record("classified_driver_failure_reaches_own_history",
         next_change(2024, 11, "norris", "cfd") == 1)
  record("classified_driver_failure_reaches_teammate_history",
         next_change(2024, 11, "piastri", "ctfd") == 1)
  record("binary_exclusive_failure_flags",
         all(new_flags$dnfc %in% 0:1) && all(new_flags$dnfd %in% 0:1) &&
           all(new_flags$dnfc + new_flags$dnfd <= 1L))
  record("modern_sample_size_and_races", nrow(new_flags) == 3441L &&
           uniqueN(new_flags$racenr) == 173L)
  dsq <- new_flags[status_api %in% c("Disqualified", "Excluded")]
  record("primary_disqualification_causes",
         nrow(dsq) == 16L && sum(dsq$dnfc) == 15L && sum(dsq$dnfd) == 1L)
  spa <- new_flags[circuit_id == "spa"]
  record("spa_uses_original_track_category",
         nrow(spa) > 0L && all(spa$rcperm == 0L & spa$rcocc == 0L))
  rbindlist(checks)
}
