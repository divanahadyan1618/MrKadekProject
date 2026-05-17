# helpers.R
# Reusable helper functions for TripAdvisor Sentiment Analysis.
# These functions streamline text cleaning, scraping parsing, and plotting.

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
