# Publication-style table rendering in R: Times, booktabs rules, no shading,
# original row labels, superscript stars, and standard errors below coefficients.

paper_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

paper_stars <- function(p) {
  ifelse(p < .001, "***", ifelse(p < .01, "**", ifelse(p < .05, "*", "")))
}

paper_coef <- function(b, se, p, term) {
  digits <- if (term == "crace2") 5L else 4L
  paste0(formatC(b, format = "f", digits = digits), paper_stars(p),
         "\n(", formatC(se, format = "f", digits = digits), ")")
}

paper_layout <- function(tab) {
  left <- .55
  total <- 9.90
  group_gap <- .24
  label_width <- tab$label_width
  n_values <- length(tab$column_headers)
  n_groups <- length(tab$groups)
  value_width <- (total - label_width - group_gap * (n_groups - 1)) / n_values
  starts <- numeric(n_values)
  x <- left + label_width
  group_ends <- cumsum(vapply(tab$groups, `[[`, integer(1), "n"))
  for (j in seq_len(n_values)) {
    starts[j] <- x
    x <- x + value_width
    if (j %in% head(group_ends, -1)) x <- x + group_gap
  }
  list(left = left, right = left + total, value_width = value_width,
       starts = starts, centres = starts + value_width / 2,
       group_ends = group_ends)
}

paper_wrap <- function(text, width = 9.90, size = 9.1) {
  words <- strsplit(text, " +")[[1]]
  lines <- character()
  line <- ""
  for (word in words) {
    candidate <- if (nzchar(line)) paste(line, word) else word
    grob <- grid::textGrob(candidate, gp = grid::gpar(fontfamily = "Times New Roman", fontsize = size))
    if (nzchar(line) && grid::convertWidth(grid::grobWidth(grob), "in", TRUE) > width) {
      lines <- c(lines, line)
      line <- word
    } else line <- candidate
  }
  paste(c(lines, line), collapse = "\n")
}

paper_number <- function(text, x, y, size = 10.3) {
  if (!nzchar(text)) return(invisible(NULL))
  significance <- regmatches(text, regexpr("\\*+$", text))
  if (length(significance) && nzchar(significance)) {
    number <- sub("\\*+$", "", text)
    value <- bquote(.(number)^{.(significance)})
  } else value <- text
  grid::grid.text(value, x = grid::unit(x, "in"), y = grid::unit(y, "in"),
                  gp = grid::gpar(fontfamily = "Times New Roman", fontsize = size))
}

draw_paper_table <- function(tab) {
  grid::grid.newpage()
  layout <- paper_layout(tab)
  left <- layout$left
  right <- layout$right
  top <- 7.95
  caption_label <- paste0(tab$number, ".")
  gp <- grid::gpar(fontfamily = "Times New Roman", fontsize = 12)
  label_grob <- grid::textGrob(caption_label,
    gp = grid::gpar(fontfamily = "Times New Roman", fontsize = 12, fontface = "bold"))
  caption_x <- left + grid::convertWidth(grid::grobWidth(label_grob), "in", TRUE) + .10
  grid::grid.text(caption_label, x = grid::unit(left, "in"), y = grid::unit(top, "in"),
    just = c("left", "top"), gp = grid::gpar(fontfamily = "Times New Roman", fontsize = 12,
                                              fontface = "bold", col = "#17458b"))
  grid::grid.text(tab$title, x = grid::unit(caption_x, "in"), y = grid::unit(top, "in"),
                  just = c("left", "top"), gp = gp)
  y <- top - .37
  rule <- function(y, x1 = left, x2 = right, weight = .6) {
    grid::grid.lines(x = grid::unit(c(x1, x2), "in"), y = grid::unit(c(y, y), "in"),
                     gp = grid::gpar(lwd = weight, col = "black"))
  }
  rule(y, weight = 1.15)
  y_group <- y - .20
  first <- 1L
  for (g in tab$groups) {
    last <- first + g$n - 1L
    x1 <- layout$starts[first]
    x2 <- layout$starts[last] + layout$value_width
    grid::grid.text(g$label, x = grid::unit((x1 + x2) / 2, "in"),
      y = grid::unit(y_group, "in"),
      gp = grid::gpar(fontfamily = "Times New Roman", fontsize = 10.5))
    rule(y - .36, x1 + .045, x2 - .045, .45)
    first <- last + 1L
  }
  header_height <- tab$header_height
  header_y <- y - .36 - header_height / 2
  grid::grid.text("Variable", x = grid::unit(left, "in"), y = grid::unit(header_y, "in"),
                  just = "left", gp = grid::gpar(fontfamily = "Times New Roman", fontsize = 10.4))
  for (j in seq_along(tab$column_headers)) {
    grid::grid.text(tab$column_headers[j], x = grid::unit(layout$centres[j], "in"),
      y = grid::unit(header_y, "in"),
      gp = grid::gpar(fontfamily = "Times New Roman", fontsize = 10.1, lineheight = 1.05))
  }
  y <- y - .36 - header_height
  rule(y, weight = .65)
  for (i in seq_along(tab$row_labels)) {
    row_type <- tab$row_types[i]
    h <- switch(row_type, coef = .345, summary = .280, info = .225)
    middle <- y - h / 2
    label <- tab$row_labels[i]
    if (label == "(Cumulative Races)^2") {
      label <- expression((italic("Cumulative Races"))^2)
    } else if (label == "Wald chi2") label <- expression(Wald~chi^2)
    face <- if (row_type %in% c("coef", "summary")) "italic" else "plain"
    grid::grid.text(label, x = grid::unit(left, "in"), y = grid::unit(middle, "in"),
      just = "left", gp = grid::gpar(fontfamily = "Times New Roman", fontsize = 10.4, fontface = face))
    for (j in seq_along(tab$column_headers)) {
      contents <- strsplit(tab$cells[i, j], "\n", fixed = TRUE)[[1]]
      if (!length(contents)) next
      if (length(contents) == 2L) {
        paper_number(contents[1], layout$centres[j], middle + .075, 10.2)
        grid::grid.text(contents[2], x = grid::unit(layout$centres[j], "in"),
          y = grid::unit(middle - .087, "in"),
          gp = grid::gpar(fontfamily = "Times New Roman", fontsize = 9.8))
      } else paper_number(contents[1], layout$centres[j], middle, 10.3)
    }
    y <- y - h
  }
  rule(y, weight = 1.05)
  y <- y - .15
  for (note in tab$notes) {
    wrapped <- paper_wrap(note)
    g <- grid::textGrob(wrapped, x = grid::unit(left, "in"), y = grid::unit(y, "in"),
      just = c("left", "top"), gp = grid::gpar(fontfamily = "Times New Roman", fontsize = 9.1,
                                                lineheight = 1.1))
    grid::grid.draw(g)
    y <- y - grid::convertHeight(grid::grobHeight(g), "in", TRUE) - .075
  }
  if (y < .35) stop("Table exceeds its page: ", tab$key)
  invisible(y)
}

paper_html_label <- function(label, row_type) {
  if (label == "(Cumulative Races)^2") return("<i>(Cumulative Races)</i><sup>2</sup>")
  if (label == "Wald chi2") return("Wald &chi;<sup>2</sup>")
  label <- paper_escape(label)
  if (row_type %in% c("coef", "summary")) paste0("<i>", label, "</i>") else label
}

paper_html_cell <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  if (!length(lines)) return("")
  first <- sub("(\\*+)$", "<sup>\\1</sup>", paper_escape(lines[1]))
  if (length(lines) == 2L) paste0(first, "<br><span class='se'>", paper_escape(lines[2]), "</span>")
  else first
}

paper_table_html <- function(tab) {
  groups <- paste(vapply(tab$groups, function(g) paste0("<th colspan='", g$n,
    "' class='group'>", paper_escape(g$label), "</th>"), character(1)), collapse = "")
  headers <- paste0("<tr><th class='var'>Variable</th>", paste(vapply(tab$column_headers,
    function(x) paste0("<th>", gsub("\n", "<br>", paper_escape(x), fixed = TRUE), "</th>"),
    character(1)), collapse = ""), "</tr>")
  body <- vapply(seq_along(tab$row_labels), function(i) {
    cells <- paste(vapply(tab$cells[i, ], function(x) paste0("<td>", paper_html_cell(x), "</td>"),
                          character(1)), collapse = "")
    paste0("<tr class='", tab$row_types[i], "'><td class='var'>",
      paper_html_label(tab$row_labels[i], tab$row_types[i]), "</td>", cells, "</tr>")
  }, character(1))
  paste0("<section id='", tab$key, "'><h2><b>", tab$number, ".</b> ",
    paper_escape(tab$title), "</h2><table><thead><tr><th></th>", groups, "</tr>", headers,
    "</thead><tbody>", paste(body, collapse = ""), "</tbody></table>",
    paste0("<p class='note'>", paper_escape(tab$notes), "</p>", collapse = ""), "</section>")
}

write_paper_html <- function(tables, file) {
  css <- "body{margin:34px auto;max-width:1440px;padding:0 28px;color:#000;background:#fff;font-family:'Times New Roman',Times,serif}section{margin:0 0 48px}h2{font-size:19px;font-weight:normal;margin-bottom:10px}h2 b{color:#17458b}table{width:100%;border-collapse:collapse;table-layout:fixed;border-top:1.6px solid #000;border-bottom:1.4px solid #000;font-size:15px}th,td{text-align:center;font-weight:normal;padding:4px 5px;vertical-align:middle}th:first-child,td:first-child{width:27%;text-align:left}th.group{border-bottom:1px solid #555;padding:9px 0 7px}thead tr:last-child th{border-bottom:1px solid #000;padding:8px 4px}tr.coef td{padding-top:5px;padding-bottom:5px}.se{font-size:95%}sup{font-size:70%;line-height:0}.note{font-size:13px;line-height:1.3;margin:7px 0 0}.info td{padding-top:2px;padding-bottom:2px}nav{font:14px Arial,sans-serif;margin-bottom:30px}nav a{margin-right:22px;color:#17458b}@media print{@page{size:letter landscape;margin:12mm}body{margin:0;padding:0}nav{display:none}section{break-after:page;margin-bottom:0}section:last-child{break-after:auto}table{font-size:11px}h2{font-size:14px}.note{font-size:10px}}"
  html <- vapply(tables, paper_table_html, character(1))
  links <- paste(vapply(tables, function(t) paste0("<a href='#", t$key, "'>", t$number, "</a>"),
                       character(1)), collapse = "")
  writeLines(c("<!doctype html><html lang='en'><head><meta charset='utf-8'>",
    "<title>F1 tables: published estimates and R results</title>",
    paste0("<style>", css, "</style></head><body><nav>", links, "</nav>"),
    html, "</body></html>"), file, useBytes = TRUE)
}

export_paper_tables <- function(tables, output_dir) {
  # A combined PDF and separate vector PDFs are generated from the same R layout.
  grDevices::cairo_pdf(file.path(output_dir, "paper_style_comparison_tables.pdf"),
    width = 11, height = 8.5, family = "Times New Roman", onefile = TRUE)
  for (tab in tables) draw_paper_table(tab)
  grDevices::dev.off()
  for (tab in tables) {
    grDevices::cairo_pdf(file.path(output_dir, paste0(tab$key, ".pdf")), width = 11, height = 8.5,
      family = "Times New Roman", onefile = TRUE)
    draw_paper_table(tab)
    grDevices::dev.off()
    grDevices::png(file.path(output_dir, paste0(tab$key, ".png")),
      width = 11, height = 8.5, units = "in", res = 220, type = "cairo")
    draw_paper_table(tab)
    grDevices::dev.off()
    display <- data.table::data.table(Variable = tab$row_labels)
    for (j in seq_along(tab$column_headers))
      display[, (tab$column_ids[j]) := tab$cells[, j]]
    data.table::fwrite(display, file.path(output_dir, paste0(tab$key, ".csv")), na = "")
  }
  write_paper_html(tables, file.path(output_dir, "index.html"))
}
