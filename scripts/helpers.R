# helpers.R
# Reusable helper functions for TripAdvisor Sentiment Analysis.
# These functions streamline text cleaning, source-column parsing, and plotting.

library(tidyverse)
library(stringr)

#' Clean Raw Text for Sentiment Analysis
#'
#' Takes a character vector of raw reviews and cleans it by converting to lowercase,
#' removing HTML elements, preserving word boundaries around Unicode punctuation,
#' removing punctuation, numbers, special symbols, and emojis, and stripping extra
#' white spaces.
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
    # 3. Remove loose angle brackets that are not real HTML tags.
    str_replace_all("[<>]", " ") %>%
    # 4. Remove email addresses, URLs, or handles
    str_replace_all("http\\S+|www\\S+", "") %>%
    # 5. Turn accented letters and Unicode punctuation into ASCII when possible.
    # This changes a fullwidth comma into a normal comma before punctuation is
    # removed, so words on both sides stay separate.
    stringi::stri_trans_general("Any-Latin; Latin-ASCII") %>%
    # 6. Replace anything still outside ASCII with a space. This mostly catches
    # emojis and symbols that the English-language sentiment tools cannot score.
    str_replace_all("[^\x01-\x7F]", " ") %>%
    # 7. Remove punctuation and special symbols
    str_replace_all("[[:punct:]]", " ") %>%
    # 8. Remove numbers
    str_replace_all("[[:digit:]]", "") %>%
    # 9. Strip extra white spaces
    str_squish()

  return(cleaned)
}

redact_embedded_contact_markers <- function(text_vector) {
  if (is.null(text_vector) || length(text_vector) == 0) return(character(0))

  text_vector %>%
    str_replace_all("https?://\\S+|www\\.[^\\s]+", " ") %>%
    str_replace_all("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", " ") %>%
    str_replace_all("(^|\\s)@[A-Za-z0-9_][A-Za-z0-9_.-]*", " ") %>%
    str_squish()
}

normalize_trip_type <- function(trip_type_vector) {
  if (is.null(trip_type_vector) || length(trip_type_vector) == 0) return(character(0))

  trip_type_vector %>%
    # TripAdvisor can append source-disclosure text after the traveler type.
    # Keep the traveler type, but remove the disclosure so grouping stays clean.
    str_replace_all(regex("\\s*review collected in partnership with.*$", ignore_case = TRUE), "") %>%
    str_replace_all(regex("\\s*this business uses tools provided by tripadvisor.*$", ignore_case = TRUE), "") %>%
    str_squish()
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
  # Review sites often use curly apostrophes, such as don't with a smart quote.
  # Change those apostrophes to a plain apostrophe before matching contractions.
  smart_apostrophe_pattern <- paste0(
    "[",
    intToUtf8(c(0x2018, 0x2019, 0x201B, 0x2032, 0x02BC, 0xFF07, 0x00B4)),
    "`]"
  )

  replacements <- c(
    "\\bcan\\s*'?t\\b" = "cannot",
    "\\bwon\\s*'?t\\b" = "will not",
    "\\bdon\\s*'?t\\b" = "do not",
    "\\bdoesn\\s*'?t\\b" = "does not",
    "\\bdidn\\s*'?t\\b" = "did not",
    "\\bisn\\s*'?t\\b" = "is not",
    "\\baren\\s*'?t\\b" = "are not",
    "\\bwasn\\s*'?t\\b" = "was not",
    "\\bweren\\s*'?t\\b" = "were not",
    "\\bwouldn\\s*'?t\\b" = "would not",
    "\\bcouldn\\s*'?t\\b" = "could not",
    "\\bshouldn\\s*'?t\\b" = "should not",
    "\\bw\\s*/\\s*o\\b" = "without",
    "\\bw\\s*/(?=\\s|$)" = "with",
    "\\bsooo+\\b" = "so",
    "\\bgooo+d\\b" = "good",
    "\\blooo+ve\\b" = "love",
    "\\bawesome\\b" = "excellent",
    "\\bbtwn\\b" = "between",
    "\\bpls\\b" = "please",
    "\\bvry\\b" = "very",
    "\\bgrt\\b" = "great",
    "\\bu\\b" = "you"
  )
  
  cleaned <- str_replace_all(text_vector, smart_apostrophe_pattern, "'")
  for (pattern in names(replacements)) {
    cleaned <- str_replace_all(cleaned, regex(pattern, ignore_case = TRUE), replacements[pattern])
  }
  return(cleaned)
}

score_negation_aware_sentiment <- function(text_vector, method = "afinn", negation_window = 3) {
  if (!requireNamespace("syuzhet", quietly = TRUE)) {
    stop("Package 'syuzhet' is required. Please install it first.", call. = FALSE)
  }

  if (is.null(text_vector) || length(text_vector) == 0) return(numeric(0))

  negation_words <- c("no", "not", "never", "without", "cannot")
  contrast_words <- c("but", "however", "though", "although", "yet")

  score_one_review <- function(text_value) {
    if (is.na(text_value)) {
      return(0)
    }

    review_words <- str_split(str_squish(as.character(text_value)), "\\s+")[[1]]
    review_words <- review_words[review_words != ""]

    if (length(review_words) == 0) {
      return(0)
    }

    word_scores <- syuzhet::get_sentiment(review_words, method = method)
    negated_positions <- rep(FALSE, length(review_words))
    negation_positions <- which(review_words %in% negation_words)

    for (position in negation_positions) {
      if (position == length(review_words)) {
        next
      }

      window_positions <- seq(position + 1, min(length(review_words), position + negation_window))
      first_contrast <- which(review_words[window_positions] %in% contrast_words)

      if (length(first_contrast) > 0) {
        window_positions <- window_positions[seq_len(first_contrast[1] - 1)]
      }

      if (length(window_positions) > 0) {
        negated_positions[window_positions] <- TRUE
      }
    }

    scored_negated_words <- negated_positions & !is.na(word_scores) & word_scores != 0
    word_scores[scored_negated_words] <- -word_scores[scored_negated_words]

    sum(word_scores, na.rm = TRUE)
  }

  vapply(text_vector, score_one_review, numeric(1))
}

# Count how many words are in each cleaned review.
# Example: "great service and food" has 4 words.
count_cleaned_words <- function(text_vector) {
  if (is.null(text_vector) || length(text_vector) == 0) return(integer(0))

  # Cleaned reviews use spaces between words. Counting non-empty chunks separated
  # by spaces gives the review length used for sentiment normalization.
  text_values <- as.character(text_vector)
  text_values[is.na(text_values)] <- ""
  text_values <- str_squish(text_values)

  if_else(
    text_values == "",
    0L,
    as.integer(str_count(text_values, "\\S+"))
  )
}

# Rescale raw sentiment scores so reviews can be compared at the same length.
# Example: if a 200-word review has an AFINN score of 20 and the target length
# is 100 words, the normalized score is 10.
normalize_score_to_word_count <- function(score_values, word_counts, target_word_count) {
  # Raw lexicon scores are sums, so longer reviews can have larger totals just
  # because they contain more words. This rescales each score to the same review
  # length while preserving the original raw score in a separate column.
  normalized_scores <- rep(NA_real_, length(score_values))
  valid_rows <- !is.na(score_values) &
    !is.na(word_counts) &
    word_counts > 0 &
    !is.na(target_word_count) &
    target_word_count > 0

  normalized_scores[valid_rows] <- score_values[valid_rows] / word_counts[valid_rows] * target_word_count
  normalized_scores
}

# Calculate an average after removing the most extreme low and high values.
# With trim = 0.1, R removes the lowest 10% and highest 10% before averaging.
calculate_trimmed_mean <- function(values, trim = 0.1) {
  # A trimmed mean drops the lowest and highest tails before averaging. It is
  # useful when one unusual review should not control the period summary.
  complete_values <- values[!is.na(values)]
  if (length(complete_values) == 0) {
    return(NA_real_)
  }

  mean(complete_values, trim = trim)
}

# Measure normal variation with MAD, a robust alternative to standard deviation.
calculate_robust_mad <- function(values, minimum_count = 20) {
  # MAD means median absolute deviation. It estimates normal variation around
  # the median and is less sensitive to outliers than a standard deviation.
  complete_values <- values[!is.na(values)]
  if (length(complete_values) < minimum_count) {
    return(NA_real_)
  }

  mad_value <- stats::mad(
    complete_values,
    center = stats::median(complete_values),
    constant = 1.4826,
    na.rm = TRUE
  )

  if (is.na(mad_value) || mad_value == 0) {
    return(NA_real_)
  }

  mad_value
}

# Compare one current value with earlier historical values.
# A result near 0 means "typical"; below -2 means "unusually low" by this rule.
calculate_robust_z <- function(value, baseline_values, minimum_count = 20) {
  # A robust z-score asks how far the current value is from the historical
  # median, measured in MAD units. Negative values mean the current period is
  # below the historical baseline.
  baseline_values <- baseline_values[!is.na(baseline_values)]
  mad_value <- calculate_robust_mad(baseline_values, minimum_count = minimum_count)

  if (length(value) == 0 || is.na(value[[1]]) || is.na(mad_value)) {
    return(NA_real_)
  }

  (value[[1]] - stats::median(baseline_values)) / mad_value
}

# Prepare raw and length-normalized sentiment columns in one consistent way.
# Step 4 and Step 5 both call this helper so their charts and CSV files use the
# same word-count denominator and cannot accidentally drift apart.
prepare_length_normalized_sentiment <- function(data) {
  required_columns <- c("cleaned_text", "score_syuzhet", "score_afinn")
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0) {
    stop(
      paste("Missing columns needed for length-normalized sentiment:", paste(missing_columns, collapse = ", ")),
      call. = FALSE
    )
  }

  # Convert the raw score columns to numbers and create a word count if Step 3
  # has not already saved one. Later scripts call this helper so every chart and
  # table uses the same normalization rule.
  normalized_data <- data %>%
    mutate(
      score_syuzhet_raw = readr::parse_number(as.character(score_syuzhet)),
      score_afinn_raw = readr::parse_number(as.character(score_afinn)),
      review_word_count = if ("review_word_count" %in% names(data)) {
        readr::parse_number(as.character(review_word_count))
      } else {
        count_cleaned_words(cleaned_text)
      }
    )

  if ("median_review_word_count" %in% names(normalized_data)) {
    # If Step 3 already saved the median review length, reuse it. That keeps
    # later scripts aligned with the scored CSV.
    possible_target <- readr::parse_number(as.character(normalized_data$median_review_word_count))
    target_word_count <- stats::median(possible_target[possible_target > 0], na.rm = TRUE)
  } else {
    # If a small test fixture skipped Step 3, calculate the median length here.
    target_word_count <- stats::median(normalized_data$review_word_count[normalized_data$review_word_count > 0], na.rm = TRUE)
  }

  if (is.na(target_word_count)) {
    stop("No cleaned words were found, so sentiment scores cannot be length-normalized.", call. = FALSE)
  }

  normalized_data %>%
    mutate(
      median_review_word_count = target_word_count,
      # These two columns answer: what would the score look like if every review
      # were the same length as the typical review in this dataset?
      score_syuzhet_per_median_review = normalize_score_to_word_count(
        score_syuzhet_raw,
        review_word_count,
        target_word_count
      ),
      score_afinn_per_median_review = normalize_score_to_word_count(
        score_afinn_raw,
        review_word_count,
        target_word_count
      )
    )
}

#' Standardize Raw Hotel Review Columns
#'
#' Review exports often use source-specific column names such as `text`,
#' `ratings.Overall`, and `date_stayed`. This function maps common variants into
#' the columns used by the rest of the workflow. Extra source fields are kept
#' only when they are useful for analysis and do not expose response metadata,
#' source URLs, or direct reviewer identifiers.
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
  hotel_col <- find_column(c("hotel_name", "offering_name", "property_name", "listing_name"))
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
  normalized_name_lookup <- setNames(normalized_names, names(raw_data))

  # Direct reviewer identifiers are not needed for this aggregate analysis.
  # Dropping them keeps generated, tracked datasets focused on the review
  # content and ratings instead of personal profile details.
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
  forbidden_source_metadata_pattern <- paste(
    c(
      "^management_response($|_)",
      "(^|_)url$"
    ),
    collapse = "|"
  )
  direct_reviewer_identifier_pattern <- paste(
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
  normalized_extra_names <- normalized_name_lookup[extra_columns]
  compact_extra_names <- str_replace_all(normalized_extra_names, "_", "")
  compact_direct_reviewer_identifier_columns <- str_replace_all(
    direct_reviewer_identifier_columns,
    "_",
    ""
  )
  compact_forbidden_source_metadata_columns <- str_replace_all(
    forbidden_source_metadata_columns,
    "_",
    ""
  )
  is_direct_reviewer_identifier <- normalized_extra_names %in% direct_reviewer_identifier_columns |
    compact_extra_names %in% compact_direct_reviewer_identifier_columns |
    str_detect(normalized_extra_names, direct_reviewer_identifier_pattern) |
    str_detect(compact_extra_names, "^(reviewer|user|author|member|profile).*(id|name|location|url)$")
  is_forbidden_source_metadata <- normalized_extra_names %in% forbidden_source_metadata_columns |
    compact_extra_names %in% compact_forbidden_source_metadata_columns |
    str_detect(normalized_extra_names, forbidden_source_metadata_pattern) |
    str_detect(compact_extra_names, "^managementresponse|url$")
  extra_columns <- extra_columns[
    !is_direct_reviewer_identifier & !is_forbidden_source_metadata
  ]

  if (length(extra_columns) > 0) {
    standardized <- bind_cols(standardized, raw_data[extra_columns])
  }

  standardized <- standardized %>%
    mutate(across(where(is.character), redact_embedded_contact_markers)) %>%
    mutate(
      across(c(review_id, hotel_name, title, review_text, review_date), str_squish)
    ) %>%
    filter(!is.na(review_text), review_text != "")

  if ("trip_type" %in% names(standardized)) {
    standardized <- standardized %>%
      mutate(trip_type = normalize_trip_type(as.character(trip_type)))
  }
  
  if (nrow(standardized) == 0) {
    stop("No non-empty review text was found after standardizing the raw dataset.", call. = FALSE)
  }
  
  standardized
}
