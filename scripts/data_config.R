# Shared file paths and source metadata for the hotel review workflow.
# Beginners can think of this file as the project's address book. Instead of
# typing the same folder names in every script, each script loads these shared
# path variables.

prepared_source_name <- "Prepared TripAdvisor review CSV"

# This project is intentionally a single-property analysis. Step 1 uses this
# name to stop early if someone accidentally supplies a mixed-hotel CSV.
target_hotel_name <- "Bvlgari Resort Bali"

# Input data from the prepared TripAdvisor export.
raw_reviews_path <- file.path("data", "raw", "reviews.csv")

# Cleaned and scored datasets created by Steps 2 and 3.
cleaned_reviews_path <- file.path("data", "cleaned", "hotel_cleaned_reviews.csv")
cleaned_tokens_path <- file.path("data", "cleaned", "hotel_cleaned_tokens.csv")
sentiment_scores_path <- file.path("data", "cleaned", "hotel_sentiment_scores.csv")

# Output folders for charts and CSV summary reports.
figures_dir <- file.path("output", "figures")
reports_dir <- file.path("output", "reports")

# Summary outputs created by the trend-monitoring part of Step 4.
sentiment_period_summary_path <- file.path(reports_dir, "sentiment_period_summary.csv")
sentiment_drift_monitor_path <- file.path(figures_dir, "sentiment_drift_monitor.png")
