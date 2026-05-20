# Shared file paths and source metadata for the hotel review workflow.

prepared_source_name <- "Prepared TripAdvisor review CSV"

raw_reviews_path <- file.path("data", "raw", "reviews.csv")
cleaned_reviews_path <- file.path("data", "cleaned", "hotel_cleaned_reviews.csv")
cleaned_tokens_path <- file.path("data", "cleaned", "hotel_cleaned_tokens.csv")
sentiment_scores_path <- file.path("data", "cleaned", "hotel_sentiment_scores.csv")

figures_dir <- file.path("output", "figures")
