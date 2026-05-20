# =====================================================================
# TripAdvisor Sentiment Analysis - Step 1: Import Review Data
# =====================================================================
# PURPOSE OF THIS SCRIPT:
# Use the prepared TripAdvisor review CSV provided with this project.

source("scripts/data_config.R")

cat("Dataset source:", prepared_source_name, "\n")
cat("Expected raw CSV:", raw_reviews_path, "\n")

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

validate_prepared_reviews <- function() {
  if (!file.exists(raw_reviews_path) || file.info(raw_reviews_path)$size == 0) {
    stop(
      paste(
        "Missing prepared review CSV at:",
        raw_reviews_path,
        "Place the provided CSV at this path before running the workflow.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  reviews <- utils::read.csv(
    raw_reviews_path,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8"
  )
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

  if (nrow(reviews) == 0) {
    stop("The raw review CSV has no rows.", call. = FALSE)
  }

  full_reviews <- reviews[!is.na(reviews$review_text) & reviews$review_text != "", ]

  cat("Raw review rows available:", nrow(reviews), "\n")
  cat("Rows with review text:", nrow(full_reviews), "\n")

  invisible(raw_reviews_path)
}

validate_prepared_reviews()
