# =====================================================================
# TripAdvisor Sentiment Analysis - Step 5: Aspect Text Analysis
# =====================================================================
# PURPOSE OF THIS SCRIPT:
# This script connects the structured TripAdvisor aspect ratings to the review
# text. The aspect ratings are used as weak labels: if a review gives "Value"
# a low score, the review text is treated as evidence associated with a value
# problem. This does not prove that every word in the review is about value,
# but it helps us find the words, phrases, and examples that deserve reading.

# =====================================================================
# STEP 1: Load Packages and Data
# =====================================================================
# These packages are collections of ready-made tools:
# - tidyverse helps us clean tables, calculate summaries, and draw charts.
# - tidytext helps us split review text into words and short phrases.
# - syuzhet gives us the sentiment dictionaries used earlier in the project.
library(tidyverse)
library(tidytext)
library(syuzhet)

# This file stores the folder and file names used throughout the project.
# Using shared paths keeps every script pointed at the same inputs and outputs.
source("scripts/data_config.R")
source("scripts/helpers.R")

# Step 5 depends on the scored review table from Step 3 and the token table
# from Step 2. Before doing any analysis, we check that both files exist so
# beginners get a clear message instead of a confusing R error later.
required_paths <- c(sentiment_scores_path, cleaned_tokens_path)
missing_paths <- required_paths[!file.exists(required_paths)]
if (length(missing_paths) > 0) {
  stop(
    paste(
      "Missing required analysis data:",
      paste(missing_paths, collapse = ", "),
      "Run Steps 2 and 3 before aspect text analysis."
    ),
    call. = FALSE
  )
}

# research_data is one row per review, including ratings and sentiment scores.
# cleaned_tokens is one row per important word from the reviews.
research_data <- read_csv(sentiment_scores_path, show_col_types = FALSE)
cleaned_tokens <- read_csv(cleaned_tokens_path, show_col_types = FALSE)

# Create the output folders if they are missing. If they already exist, R keeps
# going quietly because showWarnings = FALSE.
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)

cat("Aspect text analysis data loaded successfully!\n")

# =====================================================================
# STEP 2: Shared Settings and Helper Functions
# =====================================================================
# A function is a reusable recipe. This one stores the chart styling choices so
# all Step 5 charts have the same fonts, colors, and spacing.
theme_premium <- function() {
  theme_minimal() +
    theme(
      text = element_text(color = "#2C3E50"),
      plot.title = element_text(face = "bold", size = 16, hjust = 0.5, color = "#1A252C"),
      plot.subtitle = element_text(size = 11, hjust = 0.5, color = "#5A6F7C"),
      axis.title = element_text(face = "bold", size = 11),
      legend.position = "bottom",
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold", color = "#2C3E50")
    )
}

# RStudio has an interactive Plots pane, but Rscript runs without one.
# This helper only prints charts when a person is using R interactively.
# The charts are still saved as PNG files by ggsave() in every run.
show_plot_for_interactive_use <- function(plot_object) {
  if (interactive()) {
    print(plot_object)
  }
}

# Some sampled datasets are small enough that a table may be missing an
# expected numeric column, such as count_low when no low-score reviews exist.
# This helper adds the missing column filled with zeroes before later math runs.
add_missing_numeric_column <- function(data, column_name) {
  if (!column_name %in% names(data)) {
    data[[column_name]] <- 0
  }

  data
}

# When a sample has too little data for a chart, we still save a PNG file. That
# keeps the workflow predictable and tells beginners why the chart is empty.
save_placeholder_plot <- function(file_name, title, message, width = 10, height = 6) {
  placeholder_plot <- ggplot() +
    annotate(
      "text",
      x = 0,
      y = 0,
      label = message,
      size = 4,
      color = "#2C3E50",
      lineheight = 0.95
    ) +
    labs(title = title, x = NULL, y = NULL) +
    theme_void() +
    theme(
      plot.title = element_text(face = "bold", size = 15, hjust = 0.5, color = "#1A252C")
    )

  ggsave(file.path(figures_dir, file_name), plot = placeholder_plot, width = width, height = height, dpi = 300)
  show_plot_for_interactive_use(placeholder_plot)
}

# Correlation measures whether two numbers tend to move together.
# This helper returns NA when there are too few complete rows or when all values
# are the same, because correlation is not meaningful in those cases.
safe_correlation <- function(x_values, y_values) {
  complete_rows <- complete.cases(x_values, y_values)
  if (sum(complete_rows) < 3) {
    return(NA_real_)
  }

  x_complete <- x_values[complete_rows]
  y_complete <- y_values[complete_rows]
  if (sd(x_complete) == 0 || sd(y_complete) == 0) {
    return(NA_real_)
  }

  cor(x_complete, y_complete)
}

# Long review text can make CSV reports hard to skim. This helper creates a
# short preview while keeping the full review text in a separate column.
make_review_excerpt <- function(text_values, width = 280) {
  text_values %>%
    as.character() %>%
    str_squish() %>%
    str_trunc(width = width)
}

# These are the structured TripAdvisor aspect-rating columns. The left side is
# the column name in the CSV, and the right side is the friendly chart label.
aspect_rating_columns <- c(
  "value_rating" = "Value",
  "rooms_rating" = "Rooms",
  "location_rating" = "Location",
  "cleanliness_rating" = "Cleanliness",
  "service_rating" = "Service",
  "sleep_quality_rating" = "Sleep quality"
)

# Empty result tables still need the same columns as normal result tables.
# That way write_csv(), chart code, and tests can run even on tiny samples.
empty_term_comparison <- function(term_type) {
  tibble(
    aspect_key = character(),
    aspect_label = factor(character(), levels = unname(aspect_rating_columns)),
    term = character(),
    count_high = numeric(),
    count_low = numeric(),
    total_high = numeric(),
    total_low = numeric(),
    low_review_share = numeric(),
    high_review_share = numeric(),
    lift_low_vs_high = numeric(),
    log_lift_low_vs_high = numeric(),
    starts_with_negation = logical(),
    afinn_term_score = numeric(),
    term_sentiment = character(),
    term_type = rep(as.character(term_type), 0)
  )
}

# Some datasets may not include every optional aspect rating. This line keeps
# only the aspect columns that are actually present in the current data.
available_aspect_columns <- names(aspect_rating_columns)[names(aspect_rating_columns) %in% names(research_data)]

if (length(available_aspect_columns) == 0) {
  stop("No structured aspect rating columns were found in the scored dataset.", call. = FALSE)
}

# These words are too general for our diagnostic tables. For example, "hotel"
# and "stay" are common in almost every review, so they do not help explain why
# a specific aspect received a low score.
domain_neutral_words <- c(
  "bali", "bvlgari", "bulgari", "hotel", "resort", "review", "tripadvisor",
  "stay", "stayed", "staying", "room", "rooms", "villa", "villas",
  "service", "property", "place", "guest", "guests", "day", "days",
  "night", "nights", "time", "times", "experience", "experiences"
)

# Give each aspect a stable color so charts are easier to compare.
aspect_colors <- c(
  "Value" = "#E76F51",
  "Rooms" = "#457B9D",
  "Location" = "#2A9D8F",
  "Cleanliness" = "#6D597A",
  "Service" = "#264653",
  "Sleep quality" = "#F4A261"
)

# =====================================================================
# STEP 3: Prepare Review-by-Aspect Data
# =====================================================================
# The source table has one row per review and six possible aspect columns.
# For this analysis, it is easier to reshape the data into one row per
# review-aspect pair. A single review can therefore become up to six rows:
# one for Value, one for Rooms, one for Location, and so on.
# Start with one row per review. The helper adds raw and normalized sentiment
# columns before we reshape the table into one row per review-aspect pair.
aspect_reviews <- research_data %>%
  prepare_length_normalized_sentiment() %>%
  mutate(
    # Force IDs and numeric fields into predictable types. This prevents joins
    # from failing if one file reads review_id as text and another reads it as
    # a number.
    review_id = as.character(review_id),
    overall_rating = readr::parse_number(as.character(rating)),
    # AFINN and Syuzhet are summed scores, so long reviews can look more
    # emotional simply because they contain more words. We keep raw scores for
    # traceability, then use scores scaled to the median review length for aspect
    # comparisons. This keeps a short review and a long review on the same scale.
    score_afinn_number = score_afinn_per_median_review,
    score_syuzhet_number = score_syuzhet_per_median_review,
    across(all_of(available_aspect_columns), ~ readr::parse_number(as.character(.x)))
  ) %>%
  select(
    review_id,
    review_date,
    title,
    review_text,
    cleaned_text,
    rating,
    overall_rating,
    score_afinn_raw,
    score_afinn_per_median_review,
    score_afinn_number,
    score_syuzhet_raw,
    score_syuzhet_per_median_review,
    score_syuzhet_number,
    sentiment_category,
    review_word_count,
    median_review_word_count,
    anger,
    anticipation,
    disgust,
    fear,
    joy,
    sadness,
    surprise,
    trust,
    negative,
    positive,
    all_of(available_aspect_columns)
  ) %>%
  # pivot_longer stacks the six aspect columns into two columns:
  # aspect_key says which aspect it is, and aspect_rating stores the score.
  pivot_longer(
    cols = all_of(available_aspect_columns),
    names_to = "aspect_key",
    values_to = "aspect_rating"
  ) %>%
  mutate(
    # aspect_label turns column names such as value_rating into labels such as
    # Value. The factor levels keep the aspects in the same order everywhere.
    aspect_label = factor(
      aspect_rating_columns[aspect_key],
      levels = unname(aspect_rating_columns)
    ),
    # We split aspect scores into simple bands:
    # - 1 to 3 means the guest signaled a weaker aspect.
    # - 4 to 5 means the guest gave that aspect a stronger score.
    band_key = case_when(
      !is.na(aspect_rating) & aspect_rating <= 3 ~ "low",
      !is.na(aspect_rating) & aspect_rating >= 4 ~ "high",
      TRUE ~ NA_character_
    ),
    aspect_score_band = case_when(
      band_key == "low" ~ "Low aspect score (1-3)",
      band_key == "high" ~ "High aspect score (4-5)",
      TRUE ~ NA_character_
    ),
    aspect_score_band = factor(
      aspect_score_band,
      levels = c("Low aspect score (1-3)", "High aspect score (4-5)")
    )
  )

# This smaller index keeps only the columns needed to connect each review to
# its low/high aspect band. We use distinct() so the same review-aspect pair is
# counted only once.
aspect_review_index <- aspect_reviews %>%
  filter(!is.na(band_key)) %>%
  distinct(aspect_key, aspect_label, review_id, band_key, aspect_score_band)

# Count how many reviews are in the low and high groups for each aspect.
# These totals are needed later when we calculate whether a word is unusually
# common in low-score reviews.
aspect_band_totals <- aspect_review_index %>%
  count(aspect_key, aspect_label, band_key, name = "reviews_in_band") %>%
  pivot_wider(
    names_from = band_key,
    values_from = reviews_in_band,
    values_fill = 0,
    names_prefix = "total_"
  ) %>%
  add_missing_numeric_column("total_low") %>%
  add_missing_numeric_column("total_high")

# =====================================================================
# STEP 4: Aspect-Specific Sentiment Alignment
# =====================================================================
# This summary asks: when an aspect rating is lower, does the full review text
# also look less positive? It combines structured aspect ratings, overall star
# ratings, length-normalized AFINN/Syuzhet sentiment, and NRC emotion counts.
aspect_text_alignment <- aspect_reviews %>%
  filter(!is.na(aspect_rating)) %>%
  group_by(aspect_key, aspect_label) %>%
  summarise(
    reviews_with_aspect_rating = n_distinct(review_id),
    mean_aspect_rating = mean(aspect_rating, na.rm = TRUE),
    median_aspect_rating = median(aspect_rating, na.rm = TRUE),
    low_score_count = sum(aspect_rating <= 3, na.rm = TRUE),
    low_score_share = low_score_count / reviews_with_aspect_rating,
    mean_overall_rating = mean(overall_rating, na.rm = TRUE),
    mean_afinn_sentiment = mean(score_afinn_number, na.rm = TRUE),
    median_afinn_sentiment = median(score_afinn_number, na.rm = TRUE),
    mean_syuzhet_sentiment = mean(score_syuzhet_number, na.rm = TRUE),
    negative_text_count = sum(score_afinn_number < 0, na.rm = TRUE),
    negative_text_share = mean(score_afinn_number < 0, na.rm = TRUE),
    mean_anger = mean(anger, na.rm = TRUE),
    mean_negative_nrc = mean(negative, na.rm = TRUE),
    corr_aspect_to_afinn = safe_correlation(aspect_rating, score_afinn_number),
    corr_aspect_to_overall_rating = safe_correlation(aspect_rating, overall_rating),
    .groups = "drop"
  ) %>%
  arrange(mean_aspect_rating)

write_csv(
  aspect_text_alignment %>%
    mutate(
      across(
        c(
          mean_aspect_rating,
          median_aspect_rating,
          low_score_share,
          mean_overall_rating,
          mean_afinn_sentiment,
          median_afinn_sentiment,
          mean_syuzhet_sentiment,
          negative_text_share,
          mean_anger,
          mean_negative_nrc,
          corr_aspect_to_afinn,
          corr_aspect_to_overall_rating
        ),
        ~ round(.x, 3)
      )
    ),
  file.path(reports_dir, "aspect_text_alignment.csv")
)

# The alignment table above gives one row per aspect. This table gives two rows
# per aspect: one for low aspect scores and one for high aspect scores. That
# makes it easier to compare low-score reviews against high-score reviews.
aspect_text_band_summary <- aspect_reviews %>%
  filter(!is.na(aspect_score_band)) %>%
  group_by(aspect_key, aspect_label, band_key, aspect_score_band) %>%
  summarise(
    review_count = n_distinct(review_id),
    mean_aspect_rating = mean(aspect_rating, na.rm = TRUE),
    mean_overall_rating = mean(overall_rating, na.rm = TRUE),
    mean_afinn_sentiment = mean(score_afinn_number, na.rm = TRUE),
    median_afinn_sentiment = median(score_afinn_number, na.rm = TRUE),
    negative_text_share = mean(score_afinn_number < 0, na.rm = TRUE),
    mean_anger = mean(anger, na.rm = TRUE),
    mean_negative_nrc = mean(negative, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(aspect_label, band_key)

write_csv(
  aspect_text_band_summary %>%
    mutate(
      across(
        c(
          mean_aspect_rating,
          mean_overall_rating,
          mean_afinn_sentiment,
          median_afinn_sentiment,
          negative_text_share,
          mean_anger,
          mean_negative_nrc
        ),
        ~ round(.x, 3)
      )
    ),
  file.path(reports_dir, "aspect_text_band_summary.csv")
)

# =====================================================================
# STEP 5: Aspect-Conditioned Text Mining
# =====================================================================
# Here we prepare single words for comparison. Each review-word combination is
# kept once, so a word repeated 20 times in the same review does not dominate
# the result by itself.
token_review_data <- cleaned_tokens %>%
  transmute(
    review_id = as.character(review_id),
    term = str_to_lower(as.character(word))
  ) %>%
  filter(
    !is.na(term),
    str_detect(term, "^[a-z]+$"),
    nchar(term) >= 3,
    !term %in% domain_neutral_words
  ) %>%
  distinct(review_id, term)

data("stop_words", package = "tidytext")
negation_words <- c("no", "not", "never", "without", "cannot")
phrase_stop_words <- setdiff(stop_words$word, negation_words)

# Phrases can explain problems better than isolated words. This creates
# two-word phrases such as "airport transfer" or "poorly maintained", then
# removes phrases made from stopwords or generic hotel words. Negation words
# are allowed because phrases such as "not worth" and "no apology" are useful
# complaint evidence.
phrase_review_data <- research_data %>%
  transmute(
    review_id = as.character(review_id),
    cleaned_text = as.character(cleaned_text)
  ) %>%
  filter(!is.na(cleaned_text), cleaned_text != "") %>%
  unnest_tokens(term, cleaned_text, token = "ngrams", n = 2) %>%
  separate(term, into = c("word_one", "word_two"), sep = " ", remove = FALSE, fill = "right") %>%
  filter(
    !is.na(word_one),
    !is.na(word_two),
    str_detect(word_one, "^[a-z]+$"),
    str_detect(word_two, "^[a-z]+$"),
    # Keep short negation words such as "no" because phrases like "no apology"
    # are meaningful complaints even though the first word has only two letters.
    nchar(word_one) >= 3 | word_one %in% negation_words,
    nchar(word_two) >= 3,
    !word_one %in% phrase_stop_words,
    !word_two %in% phrase_stop_words,
    !word_one %in% domain_neutral_words,
    !word_two %in% domain_neutral_words
  ) %>%
  distinct(review_id, term)

# This reusable function compares text in low-score reviews against text in
# high-score reviews for each aspect.
#
# The key idea is "lift":
# - If a word appears often in low Value reviews but rarely in high Value
#   reviews, that word has high low-score lift for Value.
# - If a word appears equally often in low and high reviews, it is less useful
#   for diagnosis.
build_term_comparison <- function(term_review_data, term_type) {
  joined_terms <- aspect_review_index %>%
    # Many-to-many is expected here because one review can have many aspect
    # rows and many words or phrases.
    inner_join(term_review_data, by = "review_id", relationship = "many-to-many")

  # A very small sample may have no matching words, no phrases, or only one
  # rating band. Returning an empty table is more useful than stopping the
  # entire project with a missing-column error.
  if (nrow(joined_terms) == 0) {
    return(empty_term_comparison(term_type))
  }

  joined_terms %>%
    distinct(aspect_key, aspect_label, band_key, review_id, term) %>%
    count(aspect_key, aspect_label, band_key, term, name = "review_count") %>%
    pivot_wider(
      names_from = band_key,
      values_from = review_count,
      values_fill = 0,
      names_prefix = "count_"
    ) %>%
    add_missing_numeric_column("count_low") %>%
    add_missing_numeric_column("count_high") %>%
    left_join(aspect_band_totals, by = c("aspect_key", "aspect_label")) %>%
    add_missing_numeric_column("total_low") %>%
    add_missing_numeric_column("total_high") %>%
    mutate(
      count_low = coalesce(count_low, 0L),
      count_high = coalesce(count_high, 0L),
      total_low = coalesce(total_low, 0L),
      total_high = coalesce(total_high, 0L),
      # Add 0.5 to the counts and 1 to the totals. This is a standard smoothing
      # trick that avoids division by zero when a word appears in one group but
      # never appears in the comparison group.
      low_review_share = (count_low + 0.5) / (total_low + 1),
      high_review_share = (count_high + 0.5) / (total_high + 1),
      lift_low_vs_high = low_review_share / high_review_share,
      # The log version makes very large ratios easier to chart and compare.
      log_lift_low_vs_high = log(lift_low_vs_high),
      # Use AFINN to color words as positive, negative, or neutral. For phrases
      # that start with a negation word, mark the phrase as negative so "not
      # worth" is not colored as positive just because "worth" is positive.
      starts_with_negation = term_type == "phrase" &
        str_detect(term, paste0("^(", paste(negation_words, collapse = "|"), ")\\s+")),
      afinn_term_score = syuzhet::get_sentiment(term, method = "afinn"),
      afinn_term_score = if_else(
        starts_with_negation & afinn_term_score > 0,
        -afinn_term_score,
        afinn_term_score
      ),
      term_sentiment = case_when(
        starts_with_negation ~ "negative",
        afinn_term_score > 0 ~ "positive",
        afinn_term_score < 0 ~ "negative",
        TRUE ~ "neutral"
      ),
      term_type = term_type
    ) %>%
    filter(count_low >= 2) %>%
    arrange(aspect_label, desc(log_lift_low_vs_high), desc(count_low), term)
}

# Run the same comparison once for single words and once for two-word phrases.
aspect_text_key_terms <- build_term_comparison(token_review_data, "word")
aspect_text_key_phrases <- build_term_comparison(phrase_review_data, "phrase")

write_csv(
  aspect_text_key_terms %>%
    mutate(
      low_review_share = round(low_review_share, 3),
      high_review_share = round(high_review_share, 3),
      lift_low_vs_high = round(lift_low_vs_high, 3),
      log_lift_low_vs_high = round(log_lift_low_vs_high, 3)
    ),
  file.path(reports_dir, "aspect_text_key_terms.csv")
)

write_csv(
  aspect_text_key_phrases %>%
    mutate(
      low_review_share = round(low_review_share, 3),
      high_review_share = round(high_review_share, 3),
      lift_low_vs_high = round(lift_low_vs_high, 3),
      log_lift_low_vs_high = round(log_lift_low_vs_high, 3)
    ),
  file.path(reports_dir, "aspect_text_key_phrases.csv")
)

# =====================================================================
# STEP 6: Aspect-Text Mismatch Review Tables
# =====================================================================
# A mismatch is a review where the signals do not fully agree. These are useful
# for qualitative reading because they often contain nuance that averages hide.
aspect_text_mismatches <- aspect_reviews %>%
  filter(!is.na(aspect_rating)) %>%
  mutate(
    # Example: a guest gives 5 stars overall but gives Value a 2.
    high_overall_low_aspect = !is.na(overall_rating) & overall_rating >= 4 & aspect_rating <= 3,
    # Example: a guest gives a low aspect score, but the whole review still has
    # positive sentiment. This can happen when the problem is specific.
    low_aspect_positive_text = aspect_rating <= 3 & !is.na(score_afinn_number) & score_afinn_number > 0,
    # Example: the structured aspect score is high, but the text has negative
    # sentiment. This may point to a topic not captured by the aspect field.
    high_aspect_negative_text = aspect_rating >= 4 & !is.na(score_afinn_number) & score_afinn_number < 0,
    # Example: the overall stay rating is low, but one aspect still performed
    # well. This helps avoid treating every part of the experience as broken.
    low_overall_high_aspect = !is.na(overall_rating) & overall_rating <= 3 & aspect_rating >= 4
  ) %>%
  filter(high_overall_low_aspect | low_aspect_positive_text | high_aspect_negative_text | low_overall_high_aspect) %>%
  mutate(
    # pmap_chr() builds the label one review at a time, and it also works when
    # the table has zero rows. That keeps tiny samples from crashing here.
    mismatch_types = pmap_chr(
      list(
        high_overall_low_aspect,
        low_aspect_positive_text,
        high_aspect_negative_text,
        low_overall_high_aspect
      ),
      function(high_overall_low_aspect, low_aspect_positive_text, high_aspect_negative_text, low_overall_high_aspect) {
        paste(
          c(
            if (isTRUE(high_overall_low_aspect)) "high overall rating with low aspect rating",
            if (isTRUE(low_aspect_positive_text)) "low aspect rating with positive text sentiment",
            if (isTRUE(high_aspect_negative_text)) "high aspect rating with negative text sentiment",
            if (isTRUE(low_overall_high_aspect)) "low overall rating with high aspect rating"
          ),
          collapse = "; "
        )
      }
    )
  ) %>%
  ungroup() %>%
  transmute(
    review_id,
    review_date,
    aspect = as.character(aspect_label),
    aspect_rating,
    overall_rating,
    score_afinn_per_median_review = score_afinn_number,
    score_afinn_raw,
    score_syuzhet_per_median_review = score_syuzhet_number,
    score_syuzhet_raw,
    sentiment_category,
    mismatch_types,
    title,
    review_excerpt = make_review_excerpt(review_text),
    review_text
  ) %>%
  arrange(aspect, aspect_rating, score_afinn_per_median_review, review_id)

write_csv(
  aspect_text_mismatches,
  file.path(reports_dir, "aspect_text_mismatches.csv")
)

# Save a smaller table of the lowest aspect-score examples. These are the rows
# a researcher or manager should read first when interpreting the numbers.
aspect_qualitative_examples <- aspect_reviews %>%
  filter(!is.na(aspect_rating), aspect_rating <= 3) %>%
  mutate(
    review_excerpt = make_review_excerpt(review_text)
  ) %>%
  group_by(aspect_label) %>%
  arrange(aspect_rating, score_afinn_number, .by_group = TRUE) %>%
  slice_head(n = 8) %>%
  ungroup() %>%
  transmute(
    aspect = as.character(aspect_label),
    review_id,
    review_date,
    aspect_rating,
    overall_rating,
    score_afinn_per_median_review = score_afinn_number,
    score_afinn_raw,
    score_syuzhet_per_median_review = score_syuzhet_number,
    score_syuzhet_raw,
    sentiment_category,
    title,
    review_excerpt,
    review_text
  )

write_csv(
  aspect_qualitative_examples,
  file.path(reports_dir, "aspect_qualitative_examples.csv")
)

# =====================================================================
# STEP 7: Visualize Aspect Text Results
# =====================================================================
# This chart checks whether length-normalized text sentiment generally improves
# as the structured aspect rating increases. Each panel is one aspect.
aspect_sentiment_plot_data <- aspect_reviews %>%
  filter(!is.na(aspect_rating), !is.na(score_afinn_number)) %>%
  mutate(aspect_rating_group = factor(aspect_rating, levels = 1:5))

if (nrow(aspect_sentiment_plot_data) > 0) {
  p_aspect_sentiment <- ggplot(
    aspect_sentiment_plot_data,
    aes(x = aspect_rating_group, y = score_afinn_number, fill = aspect_rating_group)
  ) +
    geom_hline(yintercept = 0, color = "#7F8C8D", linewidth = 0.4, linetype = "dashed") +
    geom_boxplot(alpha = 0.82, outlier.alpha = 0.25, width = 0.62) +
    facet_wrap(~ aspect_label, ncol = 3) +
    scale_fill_brewer(palette = "RdYlGn") +
    labs(
      title = "Text Sentiment by Structured Aspect Rating",
      subtitle = "Boxes compare whole-review AFINN scaled to a median-length review for low and high aspect scores",
      x = "Aspect rating",
      y = "AFINN per median-length review"
    ) +
    theme_premium() +
    theme(legend.position = "none")

  show_plot_for_interactive_use(p_aspect_sentiment)
  ggsave(
    file.path(figures_dir, "aspect_sentiment_by_rating_boxplot.png"),
    plot = p_aspect_sentiment,
    width = 11,
    height = 7,
    dpi = 300
  )
} else {
  save_placeholder_plot(
    "aspect_sentiment_by_rating_boxplot.png",
    "Text Sentiment by Structured Aspect Rating",
    "There are no complete aspect rating and text sentiment pairs in this sample.",
    width = 11,
    height = 7
  )
}

# Pick the strongest low-score-associated words for each aspect so the chart is
# readable. The full ranked table is still saved in the CSV report.
plot_key_terms <- aspect_text_key_terms %>%
  group_by(aspect_label) %>%
  slice_max(order_by = log_lift_low_vs_high, n = 6, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(
    term_for_plot = tidytext::reorder_within(term, log_lift_low_vs_high, aspect_label),
    label_text = paste0("low n=", count_low)
  )

# This chart shows the words that most separate low-score reviews from
# high-score reviews for each aspect.
if (nrow(plot_key_terms) > 0) {
  p_low_terms <- ggplot(
    plot_key_terms,
    aes(x = term_for_plot, y = log_lift_low_vs_high, fill = term_sentiment)
  ) +
    geom_col(width = 0.72, alpha = 0.88) +
    geom_text(aes(label = label_text), hjust = -0.08, size = 2.5, color = "#2C3E50") +
    coord_flip() +
    facet_wrap(~ aspect_label, scales = "free_y", ncol = 2) +
    tidytext::scale_x_reordered() +
    scale_fill_manual(
      values = c("negative" = "#E76F51", "neutral" = "#457B9D", "positive" = "#2A9D8F"),
      name = "AFINN word tone"
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.28))) +
    labs(
      title = "Words Most Associated with Low Aspect Scores",
      subtitle = "Bars show smoothed log lift in low-score reviews compared with high-score reviews",
      x = "Word",
      y = "Low-score association"
    ) +
    theme_premium()

  show_plot_for_interactive_use(p_low_terms)
  ggsave(
    file.path(figures_dir, "aspect_low_score_key_terms.png"),
    plot = p_low_terms,
    width = 11,
    height = 8,
    dpi = 300
  )
} else {
  save_placeholder_plot(
    "aspect_low_score_key_terms.png",
    "Words Most Associated with Low Aspect Scores",
    "This sample does not have enough low-score review text to rank words.",
    width = 11,
    height = 8
  )
}

# Repeat the same idea for two-word phrases. Phrases are often easier for
# non-technical readers to interpret than individual words.
plot_key_phrases <- aspect_text_key_phrases %>%
  group_by(aspect_label) %>%
  slice_max(order_by = log_lift_low_vs_high, n = 5, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(
    term_for_plot = tidytext::reorder_within(term, log_lift_low_vs_high, aspect_label),
    label_text = paste0("low n=", count_low)
  )

if (nrow(plot_key_phrases) > 0) {
  p_low_phrases <- ggplot(
    plot_key_phrases,
    aes(x = term_for_plot, y = log_lift_low_vs_high, fill = term_sentiment)
  ) +
    geom_col(width = 0.72, alpha = 0.88) +
    geom_text(aes(label = label_text), hjust = -0.08, size = 2.4, color = "#2C3E50") +
    coord_flip() +
    facet_wrap(~ aspect_label, scales = "free_y", ncol = 2) +
    tidytext::scale_x_reordered() +
    scale_fill_manual(
      values = c("negative" = "#E76F51", "neutral" = "#457B9D", "positive" = "#2A9D8F"),
      name = "AFINN phrase tone"
    ) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.34))) +
    labs(
      title = "Phrases Most Associated with Low Aspect Scores",
      subtitle = "Bars show smoothed log lift in low-score reviews compared with high-score reviews",
      x = "Phrase",
      y = "Low-score association"
    ) +
    theme_premium()

  show_plot_for_interactive_use(p_low_phrases)
  ggsave(
    file.path(figures_dir, "aspect_low_score_key_phrases.png"),
    plot = p_low_phrases,
    width = 11,
    height = 8,
    dpi = 300
  )
} else {
  save_placeholder_plot(
    "aspect_low_score_key_phrases.png",
    "Phrases Most Associated with Low Aspect Scores",
    "This sample does not have enough low-score review text to rank phrases.",
    width = 11,
    height = 8
  )
}

# This chart keeps only negative AFINN words. It helps identify where low
# aspect scores are connected to explicitly negative language.
negative_heatmap_terms <- aspect_text_key_terms %>%
  filter(term_sentiment == "negative", log_lift_low_vs_high > 0) %>%
  group_by(aspect_label) %>%
  slice_max(order_by = log_lift_low_vs_high, n = 5, with_ties = FALSE) %>%
  ungroup()

if (nrow(negative_heatmap_terms) > 0) {
  p_negative_heatmap <- negative_heatmap_terms %>%
    mutate(
      term = fct_reorder(term, log_lift_low_vs_high, .fun = max),
      heatmap_label = paste0("n=", count_low)
    ) %>%
    ggplot(aes(x = aspect_label, y = term, fill = log_lift_low_vs_high)) +
    geom_tile(color = "white", linewidth = 0.45) +
    geom_text(aes(label = heatmap_label), size = 2.7, color = "#2C3E50") +
    scale_fill_gradient(
      low = "#F7F9F9",
      high = "#C0392B",
      name = "Low-score\nlog lift"
    ) +
    labs(
      title = "Negative Words Associated with Low Aspect Scores",
      subtitle = "Each tile shows a negative AFINN word that appears unusually often in low-score reviews",
      x = "Aspect",
      y = "Negative word"
    ) +
    theme_premium() +
    theme(
      legend.position = "right",
      axis.text.x = element_text(angle = 35, hjust = 1)
    )

  show_plot_for_interactive_use(p_negative_heatmap)
  ggsave(
    file.path(figures_dir, "aspect_negative_term_heatmap.png"),
    plot = p_negative_heatmap,
    width = 10,
    height = 7,
    dpi = 300
  )
} else {
  save_placeholder_plot(
    "aspect_negative_term_heatmap.png",
    "Negative Words Associated with Low Aspect Scores",
    "No negative terms had positive low-score lift in this sample.",
    width = 10,
    height = 7
  )
}

# Count each mismatch type by aspect so reviewers can see where manual reading
# is most needed.
mismatch_counts <- aspect_text_mismatches %>%
  separate_rows(mismatch_types, sep = "; ") %>%
  count(aspect, mismatch_types, name = "review_count")

if (nrow(mismatch_counts) > 0) {
  # Sort aspects by their total number of mismatch cases so the chart has a
  # stable and meaningful order.
  mismatch_aspect_order <- mismatch_counts %>%
    group_by(aspect) %>%
    summarise(total_cases = sum(review_count), .groups = "drop") %>%
    arrange(total_cases) %>%
    pull(aspect)

  mismatch_counts <- mismatch_counts %>%
    mutate(
      aspect = factor(aspect, levels = mismatch_aspect_order),
      mismatch_type_label = str_wrap(mismatch_types, width = 34)
    )

  p_mismatches <- ggplot(
    mismatch_counts,
    aes(x = aspect, y = review_count, fill = mismatch_type_label)
  ) +
    geom_col(width = 0.72, alpha = 0.88) +
    coord_flip() +
    scale_fill_brewer(
      palette = "Set2",
      name = "Mismatch type",
      guide = guide_legend(nrow = 2, byrow = TRUE)
    ) +
    labs(
      title = "Aspect-Text Mismatch Cases for Qualitative Review",
      subtitle = "Counts identify reviews where ratings and text signals do not fully agree",
      x = "Aspect",
      y = "Review-aspect cases"
    ) +
    theme_premium() +
    theme(
      legend.text = element_text(size = 8),
      plot.margin = margin(10, 18, 10, 18)
    )

  show_plot_for_interactive_use(p_mismatches)
  ggsave(
    file.path(figures_dir, "aspect_text_mismatch_counts.png"),
    plot = p_mismatches,
    width = 11,
    height = 7,
    dpi = 300
  )
} else {
  save_placeholder_plot(
    "aspect_text_mismatch_counts.png",
    "Aspect-Text Mismatch Cases for Qualitative Review",
    "This sample did not produce any aspect-text mismatch cases.",
    width = 11,
    height = 7
  )
}

cat("Aspect text analysis complete!\n")
cat("- ", file.path(reports_dir, "aspect_text_alignment.csv"), "\n", sep = "")
cat("- ", file.path(reports_dir, "aspect_text_band_summary.csv"), "\n", sep = "")
cat("- ", file.path(reports_dir, "aspect_text_key_terms.csv"), "\n", sep = "")
cat("- ", file.path(reports_dir, "aspect_text_key_phrases.csv"), "\n", sep = "")
cat("- ", file.path(reports_dir, "aspect_text_mismatches.csv"), "\n", sep = "")
cat("- ", file.path(reports_dir, "aspect_qualitative_examples.csv"), "\n", sep = "")
cat("- ", file.path(figures_dir, "aspect_sentiment_by_rating_boxplot.png"), "\n", sep = "")
cat("- ", file.path(figures_dir, "aspect_low_score_key_terms.png"), "\n", sep = "")
cat("- ", file.path(figures_dir, "aspect_low_score_key_phrases.png"), "\n", sep = "")
cat("- ", file.path(figures_dir, "aspect_negative_term_heatmap.png"), "\n", sep = "")
cat("- ", file.path(figures_dir, "aspect_text_mismatch_counts.png"), "\n", sep = "")
