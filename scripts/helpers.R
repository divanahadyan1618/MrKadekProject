# helpers.R
# Reusable helper functions for TripAdvisor Sentiment Analysis.
# These functions streamline text cleaning, source-column parsing, and plotting.

library(tidyverse)
library(stringr)

#' Clean Raw Text for Sentiment Analysis
#'
#' Takes a character vector of raw reviews and cleans it by converting to lowercase,
#' removing HTML elements, removing punctuation, numbers, special symbols, and emojis,
#' and stripping extra white spaces.
#'
#' @param text_vector A character vector of text.
#' @return A cleaned character vector.
#' @export
clean_text <- function(text_vector) {
  if (is.null(text_vector) || length(text_vector) == 0) return(character(0))

  cleaned <- text_vector %>%
    # 1. Convert to lowercase
    str_to_lower() %>%
    # 2. Remove HTML tags (e.g., <br/>)
    str_replace_all("<[^>]*>", " ") %>%
    # 3. Remove email addresses, URLs, or handles
    str_replace_all("http\\S+|www\\S+", "") %>%
    # 4. Remove emojis and non-ASCII characters
    str_replace_all("[^\x01-\x7F]", "") %>%
    # 5. Remove punctuation and special symbols
    str_replace_all("[[:punct:]]", " ") %>%
    # 6. Remove numbers
    str_replace_all("[[:digit:]]", "") %>%
    # 7. Strip extra white spaces
    str_squish()

  return(cleaned)
}

#' Remove Stopwords from Cleaned Text
#'
#' Removes common English words (stop words) that don't carry sentiment.
#' Uses tidytext package internally.
#'
#' @param text_df A tibble/dataframe containing the tokenized words.
#' @param word_column The name of the column containing words (as a symbol or character).
#' @return A tibble with stopwords removed.
#' @export
remove_stopwords <- function(text_df, word_column = "word") {
  if (!requireNamespace("tidytext", quietly = TRUE)) {
    stop("Package 'tidytext' is required. Please install it first.")
  }

  data("stop_words", package = "tidytext")

  # Remove standard English stopwords
  text_df %>%
    anti_join(stop_words, by = setNames("word", word_column))
}

#' Normalize Slang and Expand Contractions (Common TripAdvisor Terms)
#'
#' A custom dictionary lookup to clean common abbreviations or slang found in TripAdvisor reviews.
#'
#' @param text_vector A character vector of text.
#' @return A normalized character vector.
#' @export
normalize_slang <- function(text_vector) {
  replacements <- c(
    "\\bsooo+\\b" = "so",
    "\\bgooo+d\\b" = "good",
    "\\blooo+ve\\b" = "love",
    "\\bawesome\\b" = "excellent",
    "\\bbtwn\\b" = "between",
    "\\bpls\\b" = "please",
    "\\bw/\\b" = "with",
    "\\bw/o\\b" = "without",
    "\\bvry\\b" = "very",
    "\\bgrt\\b" = "great",
    "\\bu\\b" = "you"
  )
  
  cleaned <- text_vector
  for (pattern in names(replacements)) {
    cleaned <- str_replace_all(cleaned, pattern, replacements[pattern])
  }
  return(cleaned)
}

#' Standardize Raw Hotel Review Columns
#'
#' Review exports often use source-specific column names such as `text`,
#' `ratings.Overall`, and `date_stayed`. This function maps common variants into
#' the columns used by the rest of the workflow and preserves extra source fields
#' such as management replies, reviewer metadata, and TripAdvisor URLs.
#'
#' @param raw_data A dataframe read from the raw reviews CSV.
#' @return A tibble with standardized columns plus any extra source metadata.
#' @export
standardize_hotel_reviews <- function(raw_data) {
  if (is.null(raw_data) || nrow(raw_data) == 0) {
    stop("The raw review dataset is empty.", call. = FALSE)
  }
  
  normalized_names <- names(raw_data) %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")
  
  find_column <- function(candidates, required = FALSE) {
    normalized_candidates <- candidates %>%
      str_to_lower() %>%
      str_replace_all("[^a-z0-9]+", "_") %>%
      str_replace_all("^_|_$", "")
    
    match_index <- match(normalized_candidates, normalized_names, nomatch = 0)
    match_index <- match_index[match_index > 0]
    
    if (length(match_index) > 0) {
      return(names(raw_data)[match_index[1]])
    }
    
    if (required) {
      stop(
        paste(
          "Could not find a required review-text column. Available columns:",
          paste(names(raw_data), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    
    NA_character_
  }
  
  id_col <- find_column(c("review_id", "id", "reviews_id"))
  hotel_col <- find_column(c("hotel_name", "offering_name", "name", "property_name"))
  title_col <- find_column(c("title", "review_title", "reviews_title", "heading", "headline"))
  review_col <- find_column(
    c("review_text", "review", "reviews_text", "text", "content", "body", "comment", "comments"),
    required = TRUE
  )
  rating_col <- find_column(
    c("rating", "ratings_overall", "ratings.overall", "overall_rating", "review_rating", "reviewer_score", "score", "stars")
  )
  date_col <- find_column(
    c("review_date", "date", "date_stayed", "date_of_stay", "reviews_date", "reviewed_at", "created_at", "published_date")
  )
  
  optional_character_column <- function(column_name) {
    if (is.na(column_name)) {
      rep(NA_character_, nrow(raw_data))
    } else {
      as.character(raw_data[[column_name]])
    }
  }
  
  optional_rating_column <- function(column_name) {
    if (is.na(column_name)) {
      rep(NA_real_, nrow(raw_data))
    } else {
      readr::parse_number(as.character(raw_data[[column_name]]))
    }
  }
  
  standardized <- tibble(
    review_id = if (is.na(id_col)) seq_len(nrow(raw_data)) else as.character(raw_data[[id_col]]),
    hotel_name = optional_character_column(hotel_col),
    title = optional_character_column(title_col),
    review_text = as.character(raw_data[[review_col]]),
    rating = optional_rating_column(rating_col),
    review_date = optional_character_column(date_col)
  )

  mapped_columns <- na.omit(c(id_col, hotel_col, title_col, review_col, rating_col, date_col))
  extra_columns <- setdiff(names(raw_data), mapped_columns)
  if (length(extra_columns) > 0) {
    standardized <- bind_cols(standardized, raw_data[extra_columns])
  }

  standardized <- standardized %>%
    mutate(
      across(c(review_id, hotel_name, title, review_text, review_date), str_squish)
    ) %>%
    filter(!is.na(review_text), review_text != "")
  
  if (nrow(standardized) == 0) {
    stop("No non-empty review text was found after standardizing the raw dataset.", call. = FALSE)
  }
  
  standardized
}
