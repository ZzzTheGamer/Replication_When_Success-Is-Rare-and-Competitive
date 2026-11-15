message("06: Build 2018-2025 variables, continuing each driver's prior history")
o <- readRDS("data/processed/original.rds")
linked <- readRDS("data/processed/linked_api.rds")
new <- copy(linked$api[year >= 2018])

# Link Wikipedia classification by race and car number (no shared drives now).
wiki <- read_csv("results/checks/wiki_classification_evidence.csv")
wiki[, car_api := as.character(suppressWarnings(as.integer(sub("[^0-9].*$", "", wiki_car))))]
wiki <- wiki[!is.na(car_api)]
stopifnot(!anyDuplicated(wiki[, .(year, round, car_api)]))
new <- merge(new, wiki[, .(year, round, car_api, wiki_driver, wiki_position, wiki_reason, wiki_grid)],
             by = c("year", "round", "car_api"), all.x = TRUE)
write_csv(new[is.na(wiki_position)], "results/checks/new_missing_wiki_classification.csv")
stopifnot(!anyNA(new$wiki_position))

# DNS/DNQ records create no cumulative racing experience. Zero-lap first-lap
# accidents do count as starts, so do not exclude a row merely because laps=0.
new[, nonstarter := grepl("^DNS|^DNQ|^DNP", wiki_position) |
                      status_category == "nonstarter"]
write_csv(new[nonstarter == TRUE], "results/checks/excluded_new_nonstarters.csv")
new <- new[nonstarter == FALSE]

# Resolve uninformative Retired statuses with explicit, reviewed row-level inputs.
overrides <- read_csv("data/manual/dnf_overrides.csv")
stopifnot(!anyDuplicated(overrides[, .(year, round, driver_api)]),
          all(overrides$reviewed == 1))
new[, category := status_category]
new[overrides, on = .(year, round, driver_api),
    `:=`(category = i.category, override_ambiguous = i.ambiguous)]
new[is.na(override_ambiguous), override_ambiguous := 0L]
unresolved <- new[!category %in% c("none", "car", "driver")]
write_csv(unresolved, "results/checks/unresolved_new_statuses.csv")
if (nrow(unresolved)) stop("Resolve the remaining new-period DNF reasons first")
new[, `:=`(dnfc = as.integer(category == "car"), dnfd = as.integer(category == "driver"),
           win = as.integer(finish_api == 1), finish = finish_api,
           ncs = 1, nds = 1, car = as.numeric(car_api))]

# Never reset returning drivers. New identities get deterministic unused IDs.
unlinked_returners <- unique(new[is.na(driverid) & driver_api %in%
  linked$api[year <= 2017, unique(driver_api)], .(driver_api, driver_api_name)])
write_csv(unlinked_returners, "results/checks/unlinked_returning_drivers.csv")
if (nrow(unlinked_returners)) stop("Review returning-driver identity links before continuing histories")
new_ids <- sort(unique(new[is.na(driverid), driver_api]))
for (i in seq_along(new_ids)) new[driver_api == new_ids[i], driverid := 10000 + i]
identity_check <- unique(new[, .(driver_api, driverid, driver_api_name)])
stopifnot(!anyDuplicated(identity_check$driverid))
write_csv(identity_check, "results/checks/extension_driver_identities.csv")

# Main Grands Prix only: sprint results are never downloaded as race experience.
new_races <- unique(new[, .(year, round, race_date)])
setorder(new_races, year, round)
stopifnot(nrow(new_races) == 173L)
new_races[, racenr := 965L + seq_len(.N)]
new[new_races, on = .(year, round), racenr := i.racenr]
new[, rcstarters := .N, by = racenr]
new[, pitlane_start := grid_api == 0 | (!is.na(wiki_grid) & grepl("^PL", wiki_grid))]
write_csv(new[pitlane_start == TRUE,
              .(year, round, driver_api, grid_api, wiki_grid, race_url)],
          "results/checks/pitlane_start_audit.csv")
# All pit-lane starters receive the same position after the last grid slot.
# This avoids using finishing order to order multiple pit-lane starts.
new[, start := fifelse(pitlane_start, max(c(rcstarters, grid_api)) + 1L, grid_api),
    by = racenr]

# Same 30/360 decimal-year age calculation as the original workbook; .001 years.
decimal_year <- function(x) as.integer(format(x, "%Y")) +
  (as.integer(format(x, "%m")) - 1) / 12 + (as.integer(format(x, "%d")) - 1) / 360
new[, age := as_stata_float(round(decimal_year(race_date) - decimal_year(dob_api), 3))]
nationality_country <- c(British = "UK", German = "Germany", Spanish = "Spain",
  Australian = "Australia", Dutch = "Netherlands", Finnish = "Finland", Mexican = "Mexico",
  French = "France", Canadian = "Canada", Russian = "Russia", Danish = "Denmark",
  Monegasque = "Monaco", Belgian = "Belgium", Polish = "Poland", Thai = "Thailand",
  Japanese = "Japan", Chinese = "China", American = "USA", Argentine = "Argentina",
  Brazilian = "Brazil", "New Zealander" = "New Zealand", Italian = "Italy", Swedish = "Sweden")
new[, dcountry := unname(nationality_country[nationality_api])]
new[, rcountry := country_api]
new[rcountry %in% c("USA", "United States"), rcountry := "USA"]
new[rcountry %in% c("UK", "United Kingdom"), rcountry := "UK"]
stopifnot(!anyNA(new$dcountry))
new[, home := as.integer(rcountry == dcountry)]

race_coding <- read_csv("data/manual/race_coding.csv")
stopifnot(nrow(race_coding) == 173L, all(race_coding$reviewed == 1L),
          all(race_coding$rcperm + race_coding$rcocc <= 1L))
new[race_coding, on = .(year, round), `:=`(rcwet = i.rcwet, rcperm = i.rcperm, rcocc = i.rcocc)]
stopifnot(!anyNA(new$rcwet), !anyNA(new$rcperm), !anyNA(new$rcocc))

team_map <- read_csv("data/manual/modern_team_mapping.csv")
stopifnot(all(unique(new$constructor_api) %in% team_map$constructor_api))
new[team_map, on = "constructor_api", `:=`(team = i.lineage, legacy_dummy = i.legacy_dummy)]
top_teams <- sort(unique(read_csv("data/manual/original_team_dummies.csv")$dummy))
for (v in top_teams) new[, (v) := as.integer(!is.na(legacy_dummy) & legacy_dummy == v)]
new[, driver := driver_api_name]

# Rebuild histories on the union of original unfiltered race rows and new starts.
# The first new record's cumulative history must equal the 2017 closing balance.
keep <- c("year", "round", "racenr", "driverid", "driver", "team", "car", "finish",
          "win", "ncs", "nds", "dnfc", "dnfd", "start", "age", "home",
          "rcwet", "rcperm", "rcocc", "rcstarters", "race_date", top_teams)
old <- copy(o$all)
old[, period := "1950-2017"]
new[, period := "2018-2025"]
all_rows <- rbindlist(list(old[, c(keep, "period"), with = FALSE],
                            new[, c(keep, "period", "driver_api", "pitlane_start", "override_ambiguous"), with = FALSE]),
                     fill = TRUE)
all_rows[is.na(pitlane_start), pitlane_start := FALSE]
all_rows[is.na(override_ambiguous), override_ambiguous := 0L]
add_experience(all_rows)
all_rows[period == "1950-2017", pod := as_stata_float(pod)]

history_vars <- c("crace", "cw", "ctw", "cfc", "cfd", "ctfc", "ctfd")
old_check <- merge(all_rows[period == "1950-2017", c("racenr", "driverid", "car", "finish", history_vars), with = FALSE],
                   o$all[, c("racenr", "driverid", "car", "finish", history_vars), with = FALSE],
                   by = c("racenr", "driverid", "car", "finish"))
stopifnot(all(vapply(history_vars, function(v)
  max(abs(old_check[[paste0(v, ".x")]] - old_check[[paste0(v, ".y")]])) == 0, logical(1))))

first_new <- all_rows[period == "2018-2025"][order(driverid, racenr), .SD[1], by = driverid]
history <- rbindlist(lapply(seq_len(nrow(first_new)), function(i) {
  d <- first_new$driverid[i]
  prev <- all_rows[driverid == d & period == "1950-2017"]
  events <- c(crace = "grid", cw = "xwin", ctw = "tw", cfc = "dnfc", cfd = "dnfd", ctfc = "tfc", ctfd = "tfd")
  rbindlist(lapply(names(events), function(v) data.table(
    driver = first_new$driver[i], driverid = d, variable = v,
    closing_2017 = sum(prev[[events[[v]]]]), first_new_prior = first_new[[v]][i])))
}))
history[, difference := first_new_prior - closing_2017]
stopifnot(all(abs(history$difference) < 1e-10))
write_csv(history, "results/checks/history_continuity.csv")

analysis <- all_rows[ncs <= 1]
stopifnot(!anyDuplicated(analysis[, .(racenr, driverid)]),
          all(analysis[year >= 2018, sum(win), by = racenr]$V1 == 1))
# Two original races lose their shared-drive winners when ncs>1 is excluded.
# Preserve that published sample rather than adding the winners back.
write_csv(analysis[, .(wins = sum(win)), by = .(year, round, racenr)][wins != 1],
          "results/checks/original_races_without_retained_winner.csv")
write_csv(analysis[, .(driver_races = .N, races = uniqueN(racenr),
                       car_failures = sum(dnfc), driver_failures = sum(dnfd),
                       car_failure_rate = mean(dnfc), driver_failure_rate = mean(dnfd)), by = year],
          "results/tables/annual_failure_rates.csv")
write_csv(new, "data/processed/extension_raw_flags.csv")
saveRDS(list(all_rows = all_rows, analysis = analysis, new_flags = new),
        "data/processed/extended.rds")
print(analysis[, .(n = .N, races = uniqueN(racenr), car_rate = mean(dnfc), driver_rate = mean(dnfd)), by = period])
