#!/usr/bin/env Rscript
# Builds an iCalendar feed (.ics) from the Swiss Rowing event calendar
# https://www.swissrowing.ch/de/eventkalender
# Output: docs/swissrowing.ics (published by GitHub Pages)

suppressPackageStartupMessages(library(rvest))

base_url <- "https://www.swissrowing.ch"
list_url <- paste0(base_url, "/de/eventkalender")
out_file <- "docs/swissrowing.ics"

# --- 1. Collect event links from the overview page ---------------------------
overview <- read_html(list_url)
links <- html_attr(html_elements(overview, "a"), "href")
links <- unique(links[!is.na(links) & grepl("/de/event/", links, fixed = TRUE)])
links <- ifelse(startsWith(links, "http"), links, paste0(base_url, links))
cat("Found", length(links), "event links\n")
if (length(links) == 0) stop("No events found - the page layout may have changed.")

# --- 2. Read each event page --------------------------------------------------
# Event pages show label/value pairs as consecutive lines, e.g.
#   Event Start / 22.05.2027 / Event Ende / 23.05.2027 / Ort / Cham
value_after <- function(lines, label) {
  i <- match(label, lines)
  if (is.na(i) || i == length(lines)) NA_character_ else lines[i + 1]
}

read_event <- function(url) {
  page  <- read_html(url)
  title <- html_attr(html_element(page, 'meta[property="og:title"]'), "content")
  if (is.na(title)) title <- html_text2(html_element(page, "h1"))
  lines <- trimws(strsplit(html_text2(page), "\n", fixed = TRUE)[[1]])
  lines <- lines[lines != ""]
  data.frame(
    url       = url,
    title     = title,
    start     = as.Date(value_after(lines, "Event Start"), "%d.%m.%Y"),
    end       = as.Date(value_after(lines, "Event Ende"),  "%d.%m.%Y"),
    location  = value_after(lines, "Ort"),
    organizer = value_after(lines, "Veranstalter"),
    category  = value_after(lines, "Kategorie Event"),
    stringsAsFactors = FALSE
  )
}

events <- lapply(links, function(u) {
  Sys.sleep(0.5)  # be polite to the server
  tryCatch(read_event(u), error = function(e) {
    message("Skipped ", u, ": ", conditionMessage(e))
    NULL
  })
})
events <- do.call(rbind, events)
if (is.null(events)) stop("No event page could be read.")
events <- events[!is.na(events$start), ]
if (nrow(events) == 0) stop("No event dates found - the page layout may have changed.")
events$end[is.na(events$end)] <- events$start[is.na(events$end)]
events <- events[order(events$start), ]
cat("Parsed", nrow(events), "events\n")

# --- 3. Write the .ics file ---------------------------------------------------
esc <- function(x) {
  x[is.na(x)] <- ""
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub(";",  "\\;",  x, fixed = TRUE)
  x <- gsub(",",  "\\,",  x, fixed = TRUE)
  gsub("\n", "\\n", x, fixed = TRUE)
}

# iCalendar lines must be at most 75 bytes; longer ones continue with a space
fold <- function(line) {
  out <- character()
  cur <- ""
  for (ch in strsplit(line, "")[[1]]) {
    if (nchar(cur, type = "bytes") + nchar(ch, type = "bytes") > 75) {
      out <- c(out, cur)
      cur <- " "
    }
    cur <- paste0(cur, ch)
  }
  c(out, cur)
}

stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")

ics <- c(
  "BEGIN:VCALENDAR",
  "VERSION:2.0",
  "PRODID:-//swissrowing-ics//Swiss Rowing Eventkalender//DE",
  "CALSCALE:GREGORIAN",
  "METHOD:PUBLISH",
  "X-WR-CALNAME:Swiss Rowing Eventkalender",
  "X-WR-TIMEZONE:Europe/Zurich"
)

for (i in seq_len(nrow(events))) {
  ev <- events[i, ]
  details <- c(
    if (!is.na(ev$category))  paste("Kategorie:", ev$category),
    if (!is.na(ev$organizer)) paste("Veranstalter:", ev$organizer),
    ev$url
  )
  ics <- c(ics,
    "BEGIN:VEVENT",
    paste0("UID:", basename(ev$url), "@swissrowing-ics"),
    paste0("DTSTAMP:", stamp),
    paste0("DTSTART;VALUE=DATE:", format(ev$start, "%Y%m%d")),
    paste0("DTEND;VALUE=DATE:", format(ev$end + 1, "%Y%m%d")),  # all-day: end is exclusive
    paste0("SUMMARY:", esc(ev$title)),
    paste0("LOCATION:", esc(ev$location)),
    paste0("DESCRIPTION:", esc(paste(details, collapse = "\n"))),
    paste0("URL:", ev$url),
    "END:VEVENT"
  )
}
ics <- c(ics, "END:VCALENDAR")
ics <- unlist(lapply(enc2utf8(ics), fold))

dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
con <- file(out_file, "wb")
writeBin(charToRaw(paste0(paste(ics, collapse = "\r\n"), "\r\n")), con)
close(con)
cat("Wrote", out_file, "\n")
