message("01: Read original race-level flags and rebuild cumulative experience")
book <- file.path(author_dir, "F1DataMainVariables.xlsx")
original_raw <- as.data.table(readxl::read_excel(book, sheet = "1950-2017"))
setnames(original_raw, tolower(names(original_raw)))
original_raw <- original_raw[!is.na(year) & !is.na(driverid)]
original_raw[, source_row := .I + 1L]
original_raw[, team := trimws(team)]
# Ignore every supplied cumulative column. Recalculate from the per-race flags.
original <- copy(original_raw)
original[, age := as_stata_float(round(age, 3))] # .001 years, stored as Stata float.
original[, c("crace", "cw", "ctw", "cfc", "cfd", "ctfc", "ctfd") := NULL]
add_experience(original)
original[, pod := as_stata_float(pod)]

# The .dta file is a validation target, never the source of our rebuilt experience.
stata <- as.data.table(haven::read_dta(file.path(author_dir, "F1StataData.dta")))
# One historical shared-drive record repeats car number 20, so finish is needed
# to distinguish the two source rows (1956 Monaco / Eugenio Castellotti).
keys <- c("racenr", "driverid", "car", "finish")
stopifnot(!anyDuplicated(original[, ..keys]), !anyDuplicated(stata[, ..keys]))
compare_vars <- c("crace", "cw", "ctw", "cfc", "cfd", "ctfc", "ctfd", "crace2")
checks <- rbindlist(lapply(compare_vars, function(v) {
  merged <- merge(original[, c(keys, v), with = FALSE],
                  stata[, c(keys, v), with = FALSE], by = keys,
                  suffixes = c("_rebuilt", "_stata"), all = TRUE)
  delta <- merged[[paste0(v, "_rebuilt")]] - merged[[paste0(v, "_stata")]]
  data.table(variable = v, n = nrow(merged), missing = sum(is.na(delta)),
             mismatches_1e6 = sum(abs(delta) > 1e-6, na.rm = TRUE),
             max_abs_difference = max(abs(delta), na.rm = TRUE))
}))
write_csv(checks, "results/checks/cumulative_validation.csv")
if (any(checks$missing > 0 | checks$mismatches_1e6 > 0))
  stop("Rebuilt variables do not match Stata; inspect cumulative_validation.csv")

# Restore calendar information by explicitly linking racenr to the Races sheet.
races_original <- as.data.table(readxl::read_excel(book, sheet = "Races"))
setnames(races_original, tolower(gsub(" ", "", names(races_original))))
races_original <- races_original[!is.na(year) & indy == 0]
stopifnot(!anyDuplicated(races_original$racenr))
original[, year := NULL]
original[races_original, on = "racenr", `:=`(year = i.year, round = i.race,
                                             race_date = as.Date(i.date),
                                             track_name = i.track)]
drivers_original <- as.data.table(readxl::read_excel(book, sheet = "Drivers"))
setnames(drivers_original, tolower(names(drivers_original)))

# Team dummy mapping is made explicit in a reviewed CSV.
if (file.exists("data/manual/original_team_dummies.csv")) {
  team_map <- read_csv("data/manual/original_team_dummies.csv")
  top_teams <- sort(unique(na.omit(team_map$dummy)))
  for (v in top_teams) {
    tm <- team_map[dummy == v]
    original[, (v) := as.numeric(team %in% tm$team &
                                 year >= min(tm$year_min) & year <= max(tm$year_max))]
  }
  other_vars <- c("win", "pod", "start", "age", "home", "rcwet", "rcperm",
                  "rcocc", "rcstarters", top_teams)
  a <- merge(original[, c(keys, other_vars), with = FALSE],
             stata[, c(keys, other_vars), with = FALSE], by = keys,
             suffixes = c("_rebuilt", "_stata"))
  control_check <- rbindlist(lapply(other_vars, function(v) data.table(
    variable = v,
    max_abs_difference = max(abs(a[[paste0(v, "_rebuilt")]] - a[[paste0(v, "_stata")]])))))
  write_csv(control_check, "results/checks/control_validation.csv")
  stopifnot(all(control_check$max_abs_difference < 1e-6))
} else {
  # Inspection export only. It must be reviewed before running the full models.
  top_teams <- grep("^t5d", names(stata), value = TRUE)
  team_map <- rbindlist(lapply(top_teams, function(v)
    unique(stata[get(v) == 1, .(team, dummy = v)])))
  write_csv(team_map, "results/checks/team_mapping_to_review.csv")
}

# Construct histories BEFORE dropping ncs > 1. Their prior experience remains.
original_model <- original[ncs <= 1]
stopifnot(nrow(original_raw) == 21616L, nrow(original_model) == 21487L,
          uniqueN(original_model$racenr) == 965L,
          uniqueN(original_model$driverid) == 655L)
saveRDS(list(raw = original_raw, all = original, model = original_model,
             races = races_original, drivers = drivers_original, validation = checks),
        "data/processed/original.rds")
write_csv(checks, "results/checks/cumulative_validation.csv")
print(checks)
