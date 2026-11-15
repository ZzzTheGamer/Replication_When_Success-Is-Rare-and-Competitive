message("02: Download/reuse paginated Jolpica main Grand Prix race results")
# The API limits the actual page size. Read the returned limit; never assume it.
offset <- 0L
api_pages <- character()
repeat {
  f <- sprintf("data/raw/jolpica/results_%05d.json", offset)
  u <- sprintf("%s/results.json?limit=1000&offset=%d", api_base, offset)
  get_cached(u, f)
  page <- jsonlite::fromJSON(f, simplifyVector = FALSE)$MRData
  api_pages <- c(api_pages, f)
  total <- as.integer(page$total)
  page_size <- as.integer(page$limit)
  races_page <- page$RaceTable$Races
  if (!length(races_page)) stop("Unexpected empty API page")
  newest <- max(vapply(races_page, function(r) as.integer(r$season), integer(1)))
  if (offset %% 2000L == 0L) message("Reading Jolpica results at offset ", offset)
  if (offset + page_size >= total || newest > 2025L) break
  offset <- offset + page_size
}

# Pages can split a race. Flatten result rows, then identify each race by year/round.
api <- rbindlist(lapply(api_pages, function(f) {
  rr <- jsonlite::fromJSON(f, simplifyVector = FALSE)$MRData$RaceTable$Races
  rbindlist(lapply(rr, function(r) {
    rbindlist(lapply(r$Results, function(x) data.table(
      year = as.integer(r$season), round = as.integer(r$round),
      race_name = r$raceName, race_date = as.Date(r$date), race_url = r$url,
      circuit_id = r$Circuit$circuitId, circuit_name = r$Circuit$circuitName,
      country_api = r$Circuit$Location$country,
      driver_api = x$Driver$driverId,
      driver_api_name = paste(x$Driver$givenName, x$Driver$familyName),
      dob_api = as.Date(x$Driver$dateOfBirth), nationality_api = x$Driver$nationality,
      constructor_api = x$Constructor$constructorId,
      constructor_name = x$Constructor$name,
      car_api = as.character(x$number), grid_api = as.integer(x$grid),
      finish_api = as.integer(x$position), position_text = x$positionText,
      laps_api = as.integer(x$laps), status_api = x$status
    )), fill = TRUE)
  }), fill = TRUE)
}), fill = TRUE)
api <- unique(api[year <= 2025])
# Historical shared drives can give one driver several result rows in a race.
# Modern driver-races must be unique; retain historical rows for the coding audit.
stopifnot(!anyDuplicated(api[year >= 2018, .(year, round, driver_api)]))
saveRDS(api, "data/processed/jolpica.rds")
message("Read ", length(api_pages), " source pages; retained ", nrow(api),
        " result rows from seasons 1950-2025.")
write_csv(api[, .(entries = .N, races = uniqueN(round)), by = year],
          "results/checks/api_season_coverage.csv")
