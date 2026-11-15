message("05: Link driver identities and validate the status rule on 1950-2017")
api <- readRDS("data/processed/jolpica.rds")
o <- readRDS("data/processed/original.rds")
dr <- copy(o$drivers)
dr[, dob := as.Date(sprintf("%04d-%02d-%02d", byear, bmonth, bday))]
dr[, name_key := normalise_name(driver)]
api_drivers <- unique(api[, .(driver_api, driver_api_name, dob_api, nationality_api)])
stopifnot(!anyDuplicated(api_drivers$driver_api))
crosswalk <- copy(api_drivers)
crosswalk[, `:=`(driverid = NA_real_, match_method = NA_character_)]
for (i in seq_len(nrow(crosswalk))) {
  exact <- dr[name_key == normalise_name(crosswalk$driver_api_name[i])]
  by_dob <- dr[dob == crosswalk$dob_api[i]]
  if (nrow(exact) == 1L) {
    crosswalk[i, `:=`(driverid = exact$id, match_method = "normalised full name")]
  } else if (nrow(by_dob) == 1L) {
    crosswalk[i, `:=`(driverid = by_dob$id, match_method = "unique date of birth")]
  }
}
if (file.exists("data/manual/driver_identity_overrides.csv")) {
  ov <- read_csv("data/manual/driver_identity_overrides.csv")
  crosswalk[ov, on = "driver_api", `:=`(driverid = i.driverid, match_method = "reviewed identity override")]
}
write_csv(crosswalk, "results/checks/driver_crosswalk.csv")
api[crosswalk, on = "driver_api", driverid := i.driverid]

# Crosswalk coverage is reported, including historical names that never started.
unmapped <- api[year <= 2017 & is.na(driverid),
               .(entries = .N), by = .(driver_api, driver_api_name, dob_api)]
write_csv(unmapped, "results/checks/unmapped_historical_api_drivers.csv")

status_map <- read_csv("data/manual/status_mapping.csv")
stopifnot(setequal(unique(api$status_api), status_map$status_api))
api[status_map, on = "status_api", status_category := i.category]
api[status_category == "withdrawal", status_category := fifelse(laps_api == 0, "nonstarter", "driver")]

# Validate on the original estimation sample, matching identities and race/car.
old <- copy(o$model)
old[, car_key := as.character(car)]
api_old <- api[year <= 2017 & !is.na(driverid)]
api_old[, car_key := car_api]
audit <- merge(old[, .(year, round, driverid, car_key, driver, dnfc, dnfd)],
               api_old[, .(year, round, driverid, car_key, status_api,
                            position_text, status_category, laps_api)],
               by = c("year", "round", "driverid", "car_key"), all.x = TRUE)
stopifnot(nrow(audit) == nrow(old))
audit[, audit_row := .I]
# Historical sources sometimes disagree on the displayed car number. If the
# driver has exactly one public result in that race, identity/race is sufficient.
fallback <- merge(audit[is.na(status_api), .(audit_row, year, round, driverid)],
                  api_old[, .(year, round, driverid, status_api, position_text,
                               status_category, laps_api)],
                  by = c("year", "round", "driverid"), allow.cartesian = TRUE)
fallback <- fallback[, if (.N == 1L) .SD, by = audit_row]
if (nrow(fallback)) audit[fallback, on = "audit_row",
  `:=`(status_api = i.status_api, position_text = i.position_text,
       status_category = i.status_category, laps_api = i.laps_api)]
audit[, author_category := fifelse(dnfc == 1, "car", fifelse(dnfd == 1, "driver", "none"))]
audit[, linked := !is.na(status_api)]
audit[, informative := linked & status_category %in% c("none", "car", "driver")]
audit[, agreement := informative & author_category == status_category]
audit[, author_dnf := author_category %in% c("car", "driver")]
metrics <- data.table(
  metric = c("original_model_rows", "linked_rows", "linked_percent", "informative_rows",
             "agreement_all_linked_percent", "agreement_informative_percent",
             "author_dnf_linked", "author_dnf_informative",
             "agreement_author_dnf_all_linked_percent", "agreement_author_dnf_informative_percent"),
  value = c(nrow(audit), sum(audit$linked), 100 * mean(audit$linked), sum(audit$informative),
            100 * sum(audit$agreement) / sum(audit$linked),
            100 * mean(audit[informative == TRUE, agreement]),
            sum(audit$linked & audit$author_dnf), sum(audit$informative & audit$author_dnf),
            100 * sum(audit$agreement & audit$author_dnf) / sum(audit$linked & audit$author_dnf),
            100 * mean(audit[informative == TRUE & author_dnf == TRUE, agreement])))
write_csv(metrics, "results/checks/status_agreement_metrics.csv")
write_csv(audit[, .N, by = .(author_category, status_category)],
          "results/checks/status_confusion_matrix.csv")
write_csv(audit[agreement == FALSE], "results/checks/status_disagreements.csv")
write_csv(audit[is.na(status_api)], "results/checks/unlinked_original_observations.csv")
saveRDS(list(api = api, drivers = crosswalk, audit = audit, metrics = metrics),
        "data/processed/linked_api.rds")
print(metrics)
