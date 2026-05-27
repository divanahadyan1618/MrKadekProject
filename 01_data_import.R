# =====================================================================
# TripAdvisor Sentiment Analysis - Step 1: Import Review Data
# =====================================================================
# PURPOSE OF THIS SCRIPT:
# Use the prepared TripAdvisor review CSV provided with this project.

source("scripts/data_config.R")

required_columns <- c(
  "review_id",
  "hotel_name",
  "title",
  "review_text",
  "rating",
  "review_date",
  "stay_date",
  "trip_type"
)

direct_reviewer_identifier_columns <- c(
  "author",
  "reviewer",
  "reviewer_id",
  "reviewer_name",
  "reviewer_location",
  "name",
  "user_id",
  "user_name",
  "username",
  "author_id",
  "author_name",
  "member_id",
  "profile_id",
  "profile_url",
  "reviewer_profile_url",
  "user_profile_url"
)

forbidden_source_metadata_columns <- c(
  "reviewer_helpful_votes",
  "machine_translated",
  "show_original_available",
  "has_management_response",
  "review_url",
  "page_url",
  "source_observed_at",
  "source_snapshot_id"
)

embedded_contact_pattern <- paste(
  c(
    "https?://\\S+",
    "www\\.[^\\s]+",
    "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
    "(^|\\s)@[A-Za-z0-9_][A-Za-z0-9_.-]*"
  ),
  collapse = "|"
)

source_disclosure_pattern <- paste(
  c(
    "review collected in partnership",
    "official review collection partners",
    "this business uses tools provided by tripadvisor"
  ),
  collapse = "|"
)

normalize_column_name <- function(column_names) {
  # Column names can arrive as snake_case, camelCase, or names with spaces.
  # This turns all of those into the same simple shape before validation.
  normalized <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", column_names, perl = TRUE)
  normalized <- tolower(normalized)
  normalized <- gsub("[^a-z0-9]+", "_", normalized)
  gsub("^_|_$", "", normalized)
}

find_direct_reviewer_identifier_columns <- function(column_names) {
  normalized_names <- normalize_column_name(column_names)
  compact_names <- gsub("_", "", normalized_names)
  normalized_forbidden <- normalize_column_name(direct_reviewer_identifier_columns)
  compact_forbidden <- gsub("_", "", normalized_forbidden)
  direct_identifier_pattern <- paste(
    c(
      "(^|_)reviewer_?id$",
      "^user_?id$",
      "^author_?id$",
      "^member_?id$",
      "^profile_?(id|url)$",
      "^(reviewer|user|author)_profile_?(id|url)$"
    ),
    collapse = "|"
  )

  is_forbidden <- normalized_names %in% normalized_forbidden |
    compact_names %in% compact_forbidden |
    grepl(direct_identifier_pattern, normalized_names, perl = TRUE) |
    grepl("^(reviewer|user|author|member|profile).*(id|name|location|url)$", compact_names, perl = TRUE)

  column_names[is_forbidden]
}

find_forbidden_source_metadata_columns <- function(column_names) {
  normalized_names <- normalize_column_name(column_names)
  compact_names <- gsub("_", "", normalized_names)
  normalized_forbidden <- normalize_column_name(forbidden_source_metadata_columns)
  compact_forbidden <- gsub("_", "", normalized_forbidden)
  forbidden_source_metadata_pattern <- paste(
    c(
      "^management_response($|_)",
      "(^|_)url$"
    ),
    collapse = "|"
  )

  is_forbidden <- normalized_names %in% normalized_forbidden |
    compact_names %in% compact_forbidden |
    grepl(forbidden_source_metadata_pattern, normalized_names, perl = TRUE) |
    grepl("^managementresponse|url$", compact_names, perl = TRUE)

  column_names[is_forbidden]
}

find_embedded_contact_columns <- function(reviews) {
  # URLs, emails, and social handles are not needed for this aggregate analysis.
  # Every uploaded column is scanned before the file can replace tracked raw data.
  scanned_columns <- names(reviews)
  has_contact_markers <- vapply(
    scanned_columns,
    function(column_name) {
      values <- as.character(reviews[[column_name]])
      values[is.na(values)] <- ""
      any(grepl(embedded_contact_pattern, values, perl = TRUE, ignore.case = TRUE))
    },
    logical(1)
  )

  scanned_columns[has_contact_markers]
}

find_source_disclosure_columns <- function(reviews) {
  # TripAdvisor sometimes adds collection-source notices to the trip type text.
  # The analysis needs the guest trip context, not those platform disclosure strings.
  checked_columns <- intersect("trip_type", names(reviews))
  has_source_disclosures <- vapply(
    checked_columns,
    function(column_name) {
      values <- as.character(reviews[[column_name]])
      values[is.na(values)] <- ""
      any(grepl(source_disclosure_pattern, values, perl = TRUE, ignore.case = TRUE))
    },
    logical(1)
  )

  checked_columns[has_source_disclosures]
}

read_review_csv <- function(csv_path) {
  utils::read.csv(
    csv_path,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8"
  )
}

validate_prepared_reviews <- function(csv_path = raw_reviews_path, announce = TRUE) {
  if (!file.exists(csv_path) || file.info(csv_path)$size == 0) {
    stop(
      paste(
        "Missing prepared review CSV at:",
        csv_path,
        "Place the provided CSV at this path before running the workflow.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  reviews <- read_review_csv(csv_path)
  missing_columns <- setdiff(required_columns, names(reviews))

  if (length(missing_columns) > 0) {
    stop(
      paste(
        "The raw review CSV is missing required columns:",
        paste(missing_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  direct_identifier_columns <- find_direct_reviewer_identifier_columns(names(reviews))
  if (length(direct_identifier_columns) > 0) {
    stop(
      paste(
        "The raw review CSV includes direct reviewer identifier columns.",
        "Remove these columns before accepting or tracking the raw file:",
        paste(direct_identifier_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  forbidden_metadata_columns <- find_forbidden_source_metadata_columns(names(reviews))
  if (length(forbidden_metadata_columns) > 0) {
    stop(
      paste(
        "The raw review CSV includes forbidden source metadata columns.",
        "Remove these columns before accepting or tracking the raw file:",
        paste(forbidden_metadata_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  source_disclosure_columns <- find_source_disclosure_columns(reviews)
  if (length(source_disclosure_columns) > 0) {
    stop(
      paste(
        "The raw review CSV includes source-disclosure text in trip_type values.",
        "Remove TripAdvisor collection disclosures before accepting or tracking the raw file.",
        "Affected columns:",
        paste(source_disclosure_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  contact_columns <- find_embedded_contact_columns(reviews)
  if (length(contact_columns) > 0) {
    stop(
      paste(
        "The raw review CSV includes embedded contact markers in raw columns.",
        "Remove URLs, email addresses, and social handles before accepting or tracking the raw file.",
        "Affected columns:",
        paste(contact_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (nrow(reviews) == 0) {
    stop("The raw review CSV has no rows.", call. = FALSE)
  }

  full_reviews <- reviews[!is.na(reviews$review_text) & trimws(reviews$review_text) != "", ]

  if (nrow(full_reviews) == 0) {
    stop(
      "The raw review CSV has rows, but no usable review text.",
      call. = FALSE
    )
  }

  hotel_names <- trimws(as.character(full_reviews$hotel_name))
  blank_hotel_rows <- is.na(hotel_names) | hotel_names == ""

  if (any(blank_hotel_rows)) {
    stop(
      paste(
        "The raw review CSV has full review rows with blank hotel_name values.",
        "Every analyzed row must identify the hotel as:",
        target_hotel_name
      ),
      call. = FALSE
    )
  }

  hotel_names <- unique(hotel_names)

  if (length(hotel_names) == 0) {
    stop(
      paste(
        "The raw review CSV must identify the hotel as:",
        target_hotel_name
      ),
      call. = FALSE
    )
  }

  unexpected_hotel_names <- setdiff(hotel_names, target_hotel_name)
  if (length(unexpected_hotel_names) > 0) {
    stop(
      paste(
        "This workflow is prepared for Bvlgari Resort Bali only.",
        "Unexpected hotel_name values:",
        paste(unexpected_hotel_names, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (isTRUE(announce)) {
    cat("Raw review rows available:", nrow(reviews), "\n")
    cat("Rows with review text:", nrow(full_reviews), "\n")
    cat("Hotel validated:", target_hotel_name, "\n")
  }

  invisible(csv_path)
}

copy_root_uploaded_reviews <- function() {
  # In Google Colab, beginners often upload reviews.csv into the notebook root.
  # Validate that file before copying so a stray upload cannot replace the
  # prepared Bvlgari CSV with a wrong hotel, private contacts, or source
  # metadata that should not be tracked.
  if (!file.exists("reviews.csv")) {
    return(invisible(FALSE))
  }

  validate_prepared_reviews("reviews.csv", announce = FALSE)
  dir.create(dirname(raw_reviews_path), recursive = TRUE, showWarnings = FALSE)

  if (!file.copy("reviews.csv", raw_reviews_path, overwrite = TRUE)) {
    stop("Could not copy reviews.csv into data/raw/reviews.csv.", call. = FALSE)
  }

  invisible(TRUE)
}

copy_root_uploaded_reviews()

cat("Dataset source:", prepared_source_name, "\n")
cat("Expected raw CSV:", raw_reviews_path, "\n")

validate_prepared_reviews()
