message("03: Cache Wikipedia race reports and export a manual-coding worksheet")
# This script extracts evidence, not final wet/track classifications.
# Final hand-reviewed choices are in data/manual/race_coding.csv.
schedules <- rbindlist(lapply(2018:2025, function(y) {
  f <- sprintf("data/raw/jolpica/schedule_%d.json", y)
  get_cached(sprintf("%s/%d.json?limit=100", api_base, y), f)
  rr <- jsonlite::fromJSON(f, simplifyVector = FALSE)$MRData$RaceTable$Races
  rbindlist(lapply(rr, function(r) data.table(
    year = as.integer(r$season), round = as.integer(r$round),
    race_name = r$raceName, race_url = sub("^http:", "https:", r$url),
    circuit_id = r$Circuit$circuitId)))
}))
stopifnot(nrow(schedules) == 173L)

wiki_results <- list()
worksheet <- rbindlist(lapply(seq_len(nrow(schedules)), function(i) {
  s <- schedules[i]
  f <- sprintf("data/raw/wikipedia/%d_%02d.html", s$year, s$round)
  get_cached(s$race_url, f, pause = 0.2)
  doc <- xml2::read_html(f)
  xml2::xml_remove(rvest::html_elements(doc, "style, script"))
  info <- function(label) {
    node <- rvest::html_element(doc, xpath = paste0(
      "//table[contains(@class,'infobox')]//tr[th[normalize-space(.)='", label, "']]/td"))
    rvest::html_text2(node)
  }
  # Save narrative paragraphs for human inspection of ambiguous weather/retirements.
  narrative <- rvest::html_text2(rvest::html_elements(doc, "p"))
  text_file <- sub(".html$", ".txt", f)
  writeLines(narrative, text_file)
  tables <- rvest::html_table(rvest::html_elements(doc, "table.wikitable"), fill = TRUE)
  candidates <- which(vapply(tables, function(t)
    any(grepl("^Driver$", names(t))) &&
      any(grepl("Time/|Retire|Time.*gap", names(t), ignore.case = TRUE)), logical(1)))
  if (length(candidates)) {
    t <- as.data.table(tables[[tail(candidates, 1)]])
    dc <- which(names(t) == "Driver")[1]
    tc <- grep("Time/|Retire|Time.*gap", names(t), ignore.case = TRUE)[1]
    nc <- grep("^No", names(t))[1]
    gc <- grep("^Grid$|^Grid", names(t), ignore.case = TRUE)[1]
    pc <- 1L
    wiki_results[[i]] <<- data.table(year = s$year, round = s$round,
      wiki_driver = as.character(t[[dc]]), wiki_car = as.character(t[[nc]]),
      wiki_position = as.character(t[[pc]]), wiki_reason = as.character(t[[tc]]),
      wiki_grid = if (!is.na(gc)) as.character(t[[gc]]) else NA_character_)
  }
  if (i %% 25L == 0L || i == nrow(schedules))
    message("Processed Wikipedia evidence: ", i, "/", nrow(schedules), " races")
  cbind(s, weather_evidence = info("Weather"), course_evidence = info("Course"),
        narrative_file = text_file)
}), fill = TRUE)
write_csv(worksheet, "results/checks/race_coding_worksheet.csv")
write_csv(rbindlist(wiki_results, fill = TRUE), "results/checks/wiki_classification_evidence.csv")
saveRDS(schedules, "data/processed/new_schedule.rds")
