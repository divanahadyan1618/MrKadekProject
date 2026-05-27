# =====================================================================
# TripAdvisor Sentiment Analysis - Step 4: Data Visualization & Insights
# =====================================================================
# Welcome! If you have never programmed before, do not worry.
# We will explain exactly what the computer is doing at every single step.
#
# PURPOSE OF THIS SCRIPT:
# Math numbers and huge spreadsheets are boring and hard to read.
# "Data Visualization" means turning those numbers into beautiful, colorful 
# pictures (like bar charts and line graphs) so we can easily understand the story!

# =====================================================================
# STEP 1: Load Packages and Data
# =====================================================================
# We load our toolsets again. 
library(tidyverse)    # Contains 'ggplot2' - the most powerful charting tool in R.
library(tidytext)     # For handling our text data.
library(wordcloud)    # A fun tool specifically for drawing Word Clouds.
library(RColorBrewer) # A tool that provides beautiful, professional color palettes.
source("scripts/data_config.R")
source("scripts/helpers.R")

# We load the final, scored dataset from Step 3.
if (!file.exists(sentiment_scores_path) || !file.exists(cleaned_tokens_path)) {
  stop(
    paste(
      "Missing cleaned analysis data.",
      "Run Step 2 and Step 3 before visualization."
    ),
    call. = FALSE
  )
}

research_data <- read_csv(sentiment_scores_path, show_col_types = FALSE)
# We also load the chopped up individual words from Step 2 (for the word cloud).
cleaned_tokens <- read_csv(cleaned_tokens_path, show_col_types = FALSE)

dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)

cat("Data and drawing tools loaded successfully!\n")

# =====================================================================
# STEP 2: Create a Custom "Theme" (Paintbrush)
# =====================================================================
# Instead of telling the computer "make the title bold and size 16" every 
# single time we draw a chart, we create a 'theme_premium' recipe once.
# Now, we just slap 'theme_premium()' on any chart, and it instantly looks professional!

theme_premium <- function() {
  theme_minimal() + # Start with a clean, white background
  theme(
    text = element_text(color = "#2C3E50"), # Dark blue/grey text
    plot.title = element_text(face = "bold", size = 16, hjust = 0.5, color = "#1A252C"), # Centered bold title
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "#5A6F7C"), # Centered subtitle
    axis.title = element_text(face = "bold", size = 11), # Bold axis labels (X and Y)
    legend.position = "none", # Hide the messy legend box
    panel.grid.minor = element_blank() # Remove distracting background grid lines
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

# When a dataset is too small for a specific chart, we still save a PNG file.
# This keeps the output folder honest: readers see why a chart is empty instead
# of accidentally reading an older chart from a previous run.
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

parse_review_dates <- function(date_values) {
  # Dates can be written in different formats.
  # This helper only accepts dates that include a year. A label such as "May 18"
  # is ambiguous because 18 could be a day, but lubridate::my() can treat it as
  # the year 2018. We return NA for that case so the workflow can stop with a
  # clear message instead of drawing the review in the wrong year.
  date_text <- str_squish(as.character(date_values))
  date_text[date_text %in% c("", "NA", "N/A", "NULL")] <- NA_character_
  parsed <- as.Date(rep(NA_character_, length(date_text)))

  parse_matching_dates <- function(pattern, parser) {
    matching_dates <- is.na(parsed) &
      !is.na(date_text) &
      str_detect(date_text, regex(pattern, ignore_case = TRUE))

    if (any(matching_dates)) {
      parsed[matching_dates] <<- as.Date(suppressWarnings(parser(date_text[matching_dates])))
    }
  }

  parse_matching_dates("^\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}$", lubridate::ymd)
  parse_matching_dates("^\\d{4}[-/]\\d{1,2}$", lubridate::ym)
  parse_matching_dates("^[A-Za-z]{3,9}\\s+\\d{1,2},\\s*\\d{4}$", lubridate::mdy)
  parse_matching_dates("^\\d{1,2}\\s+[A-Za-z]{3,9}\\s+\\d{4}$", lubridate::dmy)
  parse_matching_dates("^[A-Za-z]{3,9}\\s+\\d{4}$", lubridate::my)

  parsed
}

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

remove_existing_files <- function(paths) {
  existing_paths <- paths[file.exists(paths)]
  if (length(existing_paths) > 0) {
    invisible(file.remove(existing_paths))
  }
}

aspect_report_paths <- file.path(
  reports_dir,
  c(
    "aspect_rating_summary.csv",
    "high_overall_low_aspect_reviews.csv",
    "aspect_text_alignment.csv",
    "aspect_text_band_summary.csv",
    "aspect_text_key_terms.csv",
    "aspect_text_key_phrases.csv",
    "aspect_text_mismatches.csv",
    "aspect_qualitative_examples.csv"
  )
)

aspect_figure_paths <- file.path(
  figures_dir,
  c(
    "aspect_mean_ratings.png",
    "aspect_low_score_share.png",
    "aspect_yearly_rating_heatmap.png",
    "aspect_sentiment_by_rating_boxplot.png",
    "aspect_low_score_key_terms.png",
    "aspect_low_score_key_phrases.png",
    "aspect_negative_term_heatmap.png",
    "aspect_text_mismatch_counts.png"
  )
)

clear_aspect_outputs <- function() {
  remove_existing_files(c(aspect_report_paths, aspect_figure_paths))
}

# =====================================================================
# STEP 3: Draw the Sentiment Distribution Chart (Positive vs Negative)
# =====================================================================
# We count how many reviews fall into each sentiment category.
sentiment_counts <- research_data %>%
  count(sentiment_category, name = "review_count")

# We use 'ggplot' to draw the chart.
# Think of 'aes' (aesthetics) as telling the computer where to put the data.
# x = sentiment_category means "Put Positive, Neutral, and Negative on the bottom X axis".
# y = review_count means "Make each bar as tall as the number of reviews in that category".
# fill = sentiment_category means "Color them based on their category".

p1 <- ggplot(sentiment_counts, aes(x = sentiment_category, y = review_count, fill = sentiment_category)) +
  geom_col(width = 0.6, alpha = 0.85) + # Draw solid bars (alpha makes them slightly transparent)
  geom_text(aes(label = review_count), vjust = -0.4, fontface = "bold", color = "#2C3E50") +
  # scale_fill_manual lets us pick the exact paint colors. Green = Good, Red = Bad, Grey = Neutral.
  scale_fill_manual(values = c("Positive" = "#16A085", "Negative" = "#E74C3C", "Neutral" = "#95A5A6")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  # 'labs' stands for labels. We give our chart a title.
  labs(
    title = "Sentiment Distribution of TripAdvisor Reviews",
    subtitle = "Bvlgari Resort Bali guest opinions from the prepared TripAdvisor review dataset",
    x = "Sentiment Category",
    y = "Number of Reviews"
  ) +
  theme_premium() # Apply our custom paintbrush from Step 2!

# Show the chart in RStudio, but do not open a PDF device during Rscript runs.
show_plot_for_interactive_use(p1)

# 'ggsave' saves the picture to our computer folder as a PNG image file.
ggsave(file.path(figures_dir, "sentiment_distribution.png"), plot = p1, width = 7, height = 5, dpi = 300)

# ---------------------------------------------------------------------
# Extra Chart: Compare Star Ratings with Text Sentiment
# ---------------------------------------------------------------------
# A guest gives the hotel a star rating (1 to 5), but they also write a review.
# These two things are related, but they are not exactly the same.
# For example, a guest might give 5 stars overall but still complain about one
# small detail in the written review.
#
# This chart groups the reviews by their TripAdvisor star rating and then
# shows the spread of the AFINN text sentiment scores inside each rating group.
# If the boxes move upward from 1 star to 5 stars, it means the text sentiment
# generally agrees with the star ratings.
rating_sentiment <- research_data %>%
  mutate(
    # The rating column should already be numeric, but parse_number() makes this
    # safer if the data ever contains text like "5 of 5" instead of just "5".
    rating_number = readr::parse_number(as.character(rating)),
    rating_group = factor(
      rating_number,
      levels = 1:5,
      labels = paste(1:5, "star")
    )
  ) %>%
  filter(!is.na(rating_group), !is.na(score_afinn))

# Count how many reviews are inside each rating group.
# We print these counts below the boxes because a box based on 596 reviews is
# much stronger evidence than a box based on only 22 reviews.
rating_counts <- rating_sentiment %>%
  count(rating_number, rating_group, name = "review_count")

# Calculate the average TripAdvisor star rating across all reviews.
# We draw this as a dashed vertical line, so students can see where the overall
# hotel rating sits on the 1-to-5 rating scale.
average_rating <- mean(rating_sentiment$rating_number)

# These numbers create a little empty space below the boxes.
# That space is where we place the "n=" labels without covering the chart.
rating_score_min <- min(rating_sentiment$score_afinn)
rating_score_max <- max(rating_sentiment$score_afinn)
rating_score_range <- max(rating_score_max - rating_score_min, 1)
rating_label_y <- rating_score_min - rating_score_range * 0.08
rating_axis_floor <- rating_label_y - rating_score_range * 0.05
rating_axis_ceiling <- rating_score_max + rating_score_range * 0.12
rating_average_line <- tibble(
  x = average_rating,
  y = rating_axis_floor,
  yend = rating_axis_ceiling
)

p1b <- ggplot(rating_sentiment, aes(x = rating_number, y = score_afinn, group = rating_number, fill = rating_group)) +
  # The boxplot shows the sentiment distribution for each rating.
  # The thick line inside each box is the median sentiment score.
  # Dots outside the whiskers are unusual reviews compared with the rest of
  # that same rating group.
  geom_boxplot(alpha = 0.82, outlier.alpha = 0.35, width = 0.62) +
  # This dashed line marks the average star rating for the full dataset.
  geom_segment(
    data = rating_average_line,
    aes(x = x, xend = x, y = y, yend = yend),
    inherit.aes = FALSE,
    linetype = "dashed",
    color = "#2C3E50",
    linewidth = 0.8
  ) +
  annotate(
    "label",
    x = average_rating,
    y = rating_axis_ceiling,
    label = paste0("Average rating: ", round(average_rating, 2), "/5"),
    vjust = 1.1,
    size = 3,
    color = "#2C3E50",
    fill = "white"
  ) +
  # A diamond marker is added for the average sentiment score in each group.
  # This is different from the median line inside the box.
  stat_summary(
    fun = mean,
    geom = "point",
    shape = 23,
    size = 3,
    fill = "#2C3E50",
    color = "white"
  ) +
  geom_text(
    data = rating_counts,
    aes(x = rating_number, y = rating_label_y, label = paste0("n=", review_count)),
    inherit.aes = FALSE,
    fontface = "bold",
    color = "#2C3E50",
    size = 3.2
  ) +
  scale_fill_brewer(palette = "RdYlGn") +
  scale_x_continuous(breaks = 1:5, labels = paste(1:5, "star"), expand = expansion(mult = c(0.08, 0.08))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.02))) +
  coord_cartesian(ylim = c(rating_axis_floor, rating_axis_ceiling)) +
  labs(
    title = "Sentiment Score Distribution by TripAdvisor Rating",
    subtitle = "Boxes show text sentiment by star rating; diamonds show group sentiment averages\nDashed line shows the overall average TripAdvisor rating",
    x = "TripAdvisor Rating",
    y = "AFINN Sentiment Score"
  ) +
  theme_premium()

show_plot_for_interactive_use(p1b)

ggsave(file.path(figures_dir, "sentiment_by_rating_boxplot.png"), plot = p1b, width = 9.5, height = 5.8, dpi = 300)

# =====================================================================
# STEP 4: Analyze Structured Aspect Ratings
# =====================================================================
# Many TripAdvisor reviews include separate ratings for value, rooms, location,
# cleanliness, service, and sleep quality. These fields are very useful because
# they tell us which part of the guest experience is weaker, even when the
# overall star rating is high.

aspect_rating_columns <- c(
  "value_rating" = "Value",
  "rooms_rating" = "Rooms",
  "location_rating" = "Location",
  "cleanliness_rating" = "Cleanliness",
  "service_rating" = "Service",
  "sleep_quality_rating" = "Sleep quality"
)
# The raw data may not always include every optional TripAdvisor aspect field.
# This line checks which of the expected aspect columns are actually available
# before the script tries to use them.
available_aspect_columns <- names(aspect_rating_columns)[names(aspect_rating_columns) %in% names(research_data)]
has_usable_aspect_ratings <- FALSE

if (length(available_aspect_columns) > 0) {
  # Make sure the rating columns are numbers. parse_number() is forgiving: it
  # can read values such as "5", "5.0", or even "5 of 5" as the number 5.
  aspect_data <- research_data %>%
    prepare_length_normalized_sentiment() %>%
    mutate(
      overall_rating = readr::parse_number(as.character(rating)),
      # Raw AFINN is a summed score. Longer reviews can therefore produce larger
      # scores even when the emotional density is similar. The aspect summaries
      # use scores scaled to the median review length in this dataset so low/high
      # aspect comparisons are fairer without choosing an arbitrary denominator.
      score_afinn_number = score_afinn_per_median_review,
      date_parsed = parse_review_dates(review_date),
      year_label = as.character(lubridate::year(date_parsed)),
      across(all_of(available_aspect_columns), ~ readr::parse_number(as.character(.x)))
    )

  usable_aspect_columns <- available_aspect_columns[
    vapply(aspect_data[available_aspect_columns], function(column) any(!is.na(column)), logical(1))
  ]

  if (length(usable_aspect_columns) == 0) {
    clear_aspect_outputs()
    message("No usable structured aspect ratings were found, so Step 4 is skipping aspect reports and charts.")
  } else {
    has_usable_aspect_ratings <- TRUE
    available_aspect_columns <- usable_aspect_columns

    # pivot_longer changes the table shape from "wide" to "long":
    # - Wide format has one row per review and many aspect-rating columns.
    # - Long format has one row per review-aspect pair.
    # Long format makes summaries and charts much easier to build.
    aspect_long <- aspect_data %>%
      select(
        review_id,
        review_date,
        year_label,
        title,
        review_text,
        overall_rating,
        score_afinn_raw,
        review_word_count,
        median_review_word_count,
        score_afinn_per_median_review,
        score_afinn_number,
        all_of(available_aspect_columns)
      ) %>%
      pivot_longer(
        cols = all_of(available_aspect_columns),
        names_to = "aspect_key",
        values_to = "aspect_rating"
      ) %>%
      mutate(
        aspect_label = factor(
          aspect_rating_columns[aspect_key],
          levels = unname(aspect_rating_columns)
        )
      )

  # This table gives one summary row for each aspect. It includes:
  # - coverage: how many reviews supplied that optional rating
  # - mean and median: typical score
  # - low-score share: how often guests gave that aspect a 1, 2, or 3
  # - correlations: whether the aspect tends to move with overall rating or text sentiment
  aspect_summary <- aspect_long %>%
    group_by(aspect_key, aspect_label) %>%
    summarise(
      reviews_with_rating = sum(!is.na(aspect_rating)),
      coverage_pct = mean(!is.na(aspect_rating)),
      mean_rating = mean(aspect_rating, na.rm = TRUE),
      median_rating = median(aspect_rating, na.rm = TRUE),
      low_score_count = sum(aspect_rating <= 3, na.rm = TRUE),
      low_score_share = if_else(reviews_with_rating > 0, low_score_count / reviews_with_rating, NA_real_),
      very_low_score_count = sum(aspect_rating <= 2, na.rm = TRUE),
      very_low_score_share = if_else(reviews_with_rating > 0, very_low_score_count / reviews_with_rating, NA_real_),
      corr_overall_rating = safe_correlation(aspect_rating, overall_rating),
      corr_afinn = safe_correlation(aspect_rating, score_afinn_number),
      .groups = "drop"
    ) %>%
    arrange(mean_rating)

  # Save a CSV report so the exact numbers behind the charts are easy to inspect
  # or reuse in the methodology paper.
  write_csv(
    aspect_summary %>%
      transmute(
        aspect_key,
        aspect_label,
        reviews_with_rating,
        coverage_pct = round(coverage_pct * 100, 1),
        mean_rating = round(mean_rating, 2),
        median_rating = round(median_rating, 2),
        low_score_count,
        low_score_pct = round(low_score_share * 100, 1),
        very_low_score_count,
        very_low_score_pct = round(very_low_score_share * 100, 1),
        corr_overall_rating = round(corr_overall_rating, 2),
        corr_afinn = round(corr_afinn, 2)
      ),
    file.path(reports_dir, "aspect_rating_summary.csv")
  )

  # These rows are important because they show satisfied guests who still
  # reported a specific problem. Example: a 5-star review with Value = 2.
  high_overall_low_aspect_reviews <- aspect_long %>%
    filter(
      !is.na(overall_rating),
      overall_rating >= 4,
      !is.na(aspect_rating),
      aspect_rating <= 3
    ) %>%
    arrange(review_id, aspect_label) %>%
    group_by(review_id) %>%
    summarise(
      review_date = first(review_date),
      rating = first(overall_rating),
      low_aspects = paste(paste0(aspect_label, "=", aspect_rating), collapse = "; "),
      score_afinn_per_median_review = first(score_afinn_number),
      score_afinn_raw = first(score_afinn_raw),
      title = first(title),
      review_text = first(review_text),
      .groups = "drop"
    )

  # Save those special cases for manual reading.
  write_csv(
    high_overall_low_aspect_reviews,
    file.path(reports_dir, "high_overall_low_aspect_reviews.csv")
  )

  # Use consistent colors for the same aspects across every aspect chart.
  aspect_colors <- c(
    "Value" = "#E76F51",
    "Rooms" = "#457B9D",
    "Location" = "#2A9D8F",
    "Cleanliness" = "#6D597A",
    "Service" = "#264653",
    "Sleep quality" = "#F4A261"
  )

  # Chart 1: show which aspect has the highest or lowest average rating.
  p_aspect_mean <- ggplot(
    aspect_summary,
    aes(x = reorder(aspect_label, mean_rating), y = mean_rating, fill = aspect_label)
  ) +
    geom_col(width = 0.68, alpha = 0.88) +
    geom_text(
      aes(label = paste0(round(mean_rating, 2), " / 5\nn=", reviews_with_rating)),
      hjust = -0.08,
      fontface = "bold",
      color = "#2C3E50",
      size = 3
    ) +
    coord_flip() +
    scale_fill_manual(values = aspect_colors) +
    scale_y_continuous(limits = c(0, 5), expand = expansion(mult = c(0, 0.18))) +
    labs(
      title = "Average Guest Experience Aspect Ratings",
      subtitle = "Structured TripAdvisor aspect scores show which experience dimensions are strongest or weakest",
      x = "Aspect",
      y = "Average rating"
    ) +
    theme_premium()

  show_plot_for_interactive_use(p_aspect_mean)

  ggsave(file.path(figures_dir, "aspect_mean_ratings.png"), plot = p_aspect_mean, width = 8.5, height = 5.4, dpi = 300)

  # Chart 2: show where low scores are concentrated. This can reveal a problem
  # even if the average rating is still high.
  p_aspect_low <- ggplot(
    aspect_summary,
    aes(x = reorder(aspect_label, low_score_share), y = low_score_share, fill = aspect_label)
  ) +
    geom_col(width = 0.68, alpha = 0.88) +
    geom_text(
      aes(label = paste0(scales::percent(low_score_share, accuracy = 0.1), "\nn=", low_score_count)),
      hjust = -0.08,
      fontface = "bold",
      color = "#2C3E50",
      size = 3
    ) +
    coord_flip() +
    scale_fill_manual(values = aspect_colors) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.18))) +
    labs(
      title = "Low-Score Share by Guest Experience Aspect",
      subtitle = "Low-score share counts aspect ratings from 1 to 3 stars",
      x = "Aspect",
      y = "Share of aspect ratings at 1-3 stars"
    ) +
    theme_premium()

  show_plot_for_interactive_use(p_aspect_low)

  ggsave(file.path(figures_dir, "aspect_low_score_share.png"), plot = p_aspect_low, width = 8.5, height = 5.4, dpi = 300)

  # Chart 3: summarize aspect ratings by year. Years with very few ratings are
  # colored grey because tiny sample sizes should not be over-interpreted.
  aspect_yearly <- aspect_long %>%
    filter(!is.na(year_label), !is.na(aspect_rating)) %>%
    group_by(year_label, aspect_label) %>%
    summarise(
      mean_rating = mean(aspect_rating),
      review_count = n(),
      .groups = "drop"
    ) %>%
    mutate(
      year_label = factor(year_label, levels = sort(unique(year_label))),
      rating_for_fill = if_else(review_count >= 5, mean_rating, NA_real_),
      heatmap_label = if_else(
        review_count >= 5,
        paste0(round(mean_rating, 1), "\nn=", review_count),
        paste0("n=", review_count)
      )
    )

  p_aspect_heatmap <- ggplot(aspect_yearly, aes(x = aspect_label, y = year_label, fill = rating_for_fill)) +
    geom_tile(color = "white", linewidth = 0.4) +
    geom_text(aes(label = heatmap_label), size = 2.3, color = "#2C3E50", lineheight = 0.85) +
    scale_fill_gradient2(
      low = "#E76F51",
      mid = "#F7F9F9",
      high = "#2A9D8F",
      midpoint = 4,
      limits = c(1, 5),
      na.value = "#ECEFF1",
      name = "Average\nrating"
    ) +
    labs(
      title = "Yearly Aspect Rating Heatmap",
      subtitle = "Grey tiles have fewer than 5 aspect ratings; labels show average rating and n when enough data exists",
      x = "Aspect",
      y = "Year"
    ) +
    theme_premium() +
    theme(
      legend.position = "right",
      axis.text.x = element_text(angle = 35, hjust = 1)
    )

  show_plot_for_interactive_use(p_aspect_heatmap)

  ggsave(file.path(figures_dir, "aspect_yearly_rating_heatmap.png"), plot = p_aspect_heatmap, width = 10, height = 7, dpi = 300)

    cat("Aspect rating analysis complete!\n")
    cat("- ", file.path(reports_dir, "aspect_rating_summary.csv"), "\n", sep = "")
    cat("- ", file.path(reports_dir, "high_overall_low_aspect_reviews.csv"), "\n", sep = "")
  }
} else {
  clear_aspect_outputs()
  warning("No structured aspect rating columns were found in the scored dataset.")
}

# =====================================================================
# STEP 5: Draw the Deep Emotion Chart (Joy, Trust, Anger, etc.)
# =====================================================================
# We calculate the total sum of all the 8 emotions.
emotions_summary <- research_data %>%
  select(anger, anticipation, disgust, fear, joy, sadness, surprise, trust) %>%
  summarise(across(everything(), sum)) %>% # Add them all up
  pivot_longer(cols = everything(), names_to = "emotion", values_to = "score") %>% # Reshape the table so we can graph it
  arrange(desc(score)) # Sort them from highest to lowest

# Draw the chart!
# 'reorder' automatically sorts the bars so the tallest one is at the top.
p2 <- ggplot(emotions_summary, aes(x = reorder(emotion, score), y = score, fill = emotion)) +
  geom_col(alpha = 0.85, width = 0.7) + # Draw the columns
  geom_text(aes(label = format(score, big.mark = ",")), hjust = -0.15, fontface = "bold", color = "#2C3E50") +
  coord_flip() + # Flip the chart sideways! Horizontal charts are easier to read.
  scale_fill_brewer(palette = "Dark2") + # Use a built-in professional color palette
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Detailed Emotional Profile of Guest Experience",
    subtitle = "NRC Lexicon emotional analysis metrics for hotel reviews",
    x = "Emotion Dimension",
    y = "Total Emotion Score"
  ) +
  theme_premium()

# Show the chart in RStudio, but do not open a PDF device during Rscript runs.
show_plot_for_interactive_use(p2)

ggsave(file.path(figures_dir, "emotions_breakdown.png"), plot = p2, width = 8, height = 5, dpi = 300)

# =====================================================================
# STEP 6: Draw the Word Cloud
# =====================================================================
# This word cloud is sentiment-only.
# That means we do NOT use every frequent word in the reviews.
# Instead, we first ask the AFINN sentiment dictionary which words have a
# positive or negative sentiment score. Words with score 0 are neutral, so they
# are removed from this chart.
# Some words can be sentiment words in one context but neutral hotel words in
# another context. For example, AFINN treats "lobby" as negative because of the
# political meaning, but a hotel lobby is just a place. We exclude those obvious
# hotel-context false positives here.
domain_neutral_words <- c("hotel", "resort", "tripadvisor", "review", "stay", "room", "villa", "service", "lobby")

sentiment_lexicon_words <- cleaned_tokens %>%
  distinct(word) %>%
  mutate(sentiment_score = syuzhet::get_sentiment(word, method = "afinn")) %>%
  filter(sentiment_score != 0) %>%
  filter(!word %in% domain_neutral_words)

# Now count only the review words that AFINN says are sentiment words.
# The bigger the word, the more often guests used that sentiment word.
sentiment_word_counts <- cleaned_tokens %>%
  inner_join(sentiment_lexicon_words, by = "word") %>%
  count(word, sentiment_score, sort = TRUE)

if (nrow(sentiment_word_counts) == 0) {
  message("No AFINN sentiment words were found in the cleaned review tokens, so Step 4 is saving a placeholder word cloud and continuing.")
  save_placeholder_plot(
    "wordcloud.png",
    "Sentiment Word Cloud",
    "No AFINN sentiment words were found after filtering the cleaned review tokens.",
    width = 5.4,
    height = 5.4
  )
} else {
  max_sentiment_cloud_words <- min(40, nrow(sentiment_word_counts))

  # Green words are positive sentiment words. Red words are negative sentiment words.
  sentiment_word_colors <- if_else(sentiment_word_counts$sentiment_score > 0, "#16A085", "#E74C3C")

  cat("Drawing the sentiment-only word cloud...\n")

  # Display the word cloud in the RStudio Plots tab only during interactive use.
  # In Rscript, the PNG file below is the intended saved output.
  if (interactive()) {
    set.seed(123)
    wordcloud(
      words = sentiment_word_counts$word,
      freq = sentiment_word_counts$n,
      min.freq = 2,
      max.words = max_sentiment_cloud_words,
      random.order = FALSE,
      rot.per = 0.2,
      ordered.colors = TRUE,
      colors = sentiment_word_colors
    )
  }

  # Open a digital "canvas" to draw the picture on
  png(file.path(figures_dir, "wordcloud.png"), width = 800, height = 800, res = 150)
  set.seed(123) # Lock the randomness so the cloud looks exactly the same every time we run it

  # Call the wordcloud drawing tool
  wordcloud(
    words = sentiment_word_counts$word, # What sentiment words to draw
    freq = sentiment_word_counts$n,     # How big to draw them based on frequency
    min.freq = 2,               # Ignore words that only appeared once
    max.words = max_sentiment_cloud_words, # Stop drawing after 40 words so it doesn't look messy
    random.order = FALSE,       # Put the biggest words right in the center
    rot.per = 0.2,              # Randomly rotate 20% of the words sideways
    ordered.colors = TRUE,      # Use each word's own positive/negative color
    colors = sentiment_word_colors # Green means positive, red means negative
  )
  dev.off() # Close the digital canvas and save the file!
}

# =====================================================================
# STEP 7: Draw Sentiment Trend Charts
# =====================================================================
# We want to see if the hotel's review sentiment changes over time.
# This section creates several different time-based charts because each chart
# answers a slightly different research question:
# 1. Monthly heatmap: Which months/years look stronger or weaker?
# 2. Monthly rolling trend: Is sentiment moving up or down over time?
# 3. Quarterly boxplot: How much do reviews vary inside each quarter?
# 4. Yearly boxplot: How much do reviews vary inside each year?
trend_reviews <- research_data %>%
  prepare_length_normalized_sentiment() %>%
  mutate(
    # The TripAdvisor export may use full dates or month-year labels.
    date_parsed = parse_review_dates(review_date),
    # score_afinn is a raw summed word score. For trend charts, normalize it
    # by review length so long reviews do not dominate month and year averages.
    # The target length is the median cleaned review length for this dataset.
    score_afinn = score_afinn_per_median_review,
    rating_number = readr::parse_number(as.character(rating))
  )

unparseable_review_dates <- trend_reviews %>%
  filter(is.na(date_parsed), !is.na(review_date), str_squish(as.character(review_date)) != "") %>%
  distinct(review_date)

if (nrow(unparseable_review_dates) > 0) {
  stop(
    paste(
      "The review_date column contains unsupported or ambiguous month-day review dates.",
      "Include a four-digit year before running trend charts.",
      "Problem values:",
      paste(head(unparseable_review_dates$review_date, 5), collapse = ", ")
    ),
    call. = FALSE
  )
}

trend_reviews <- trend_reviews %>%
  mutate(
    month_start = lubridate::floor_date(date_parsed, "month"),
    quarter_start = lubridate::floor_date(date_parsed, "quarter"),
    quarter_label = paste0(lubridate::year(date_parsed), " Q", lubridate::quarter(date_parsed)),
    year_start = lubridate::floor_date(date_parsed, "year"),
    year_label = as.character(lubridate::year(date_parsed))
  ) %>%
  # Ignore broken dates and reviews that cannot be normalized.
  filter(!is.na(date_parsed), !is.na(score_afinn_per_median_review))

# Give every calendar month a simple number: 1, 2, 3, and so on.
# Some months have no reviews. We still include those empty months so a
# "6-month rolling average" really means six calendar months, not six reviewed
# months that may be far apart.
month_lookup <- tibble(
  month_start = seq(
    min(trend_reviews$month_start),
    max(trend_reviews$month_start),
    by = "1 month"
  )
) %>%
  mutate(
    month_index = row_number(),
    month_label = format(month_start, "%b %Y"),
    quarter_start = lubridate::floor_date(month_start, "quarter"),
    quarter_label = paste0(lubridate::year(month_start), " Q", lubridate::quarter(month_start))
  )

trend_reviews <- trend_reviews %>%
  left_join(month_lookup, by = c("month_start", "quarter_start", "quarter_label"))

# These values help us place small statistic labels below some charts.
# score_min and score_max find the lowest and highest sentiment scores.
# score_range is the distance between them.
# We subtract a small part of that range to create empty space below the chart.
score_min <- min(trend_reviews$score_afinn)
score_max <- max(trend_reviews$score_afinn)
score_range <- max(score_max - score_min, 1)
stats_label_y <- score_min - score_range * 0.13
stats_axis_floor <- stats_label_y - score_range * 0.08
year_stats_label_y <- score_min - score_range * 0.18
year_stats_axis_floor <- year_stats_label_y - score_range * 0.24

# This helper adds a "prior average" to a monthly, quarterly, or yearly table.
# "Prior average" means: the average sentiment before the current period starts.
# Example:
# - For 2020, it uses all reviews before 2020.
# - For March 2024, it uses all reviews before March 2024.
# This lets us compare the current period against the hotel's previous history,
# instead of comparing it against an average that includes future reviews.
add_prior_period_average <- function(period_summary) {
  period_summary %>%
    mutate(
      cumulative_score_before = lag(cumsum(score_total)),
      cumulative_count_before = lag(cumsum(review_count)),
      prior_avg = cumulative_score_before / cumulative_count_before,
      stats_label = paste0("avg ", round(period_avg, 1), "\nn=", review_count)
    )
}

# This helper rounds numbers to one decimal place.
# We use it for labels so the chart says "17.5" instead of a long number like
# "17.5748031496063".
format_stat <- function(value) {
  format(round(value, 1), nsmall = 1, trim = TRUE)
}

# First count only the months that actually have reviews.
reviewed_month_averages <- trend_reviews %>%
  group_by(month_start, month_index, month_label, quarter_start, quarter_label) %>%
  summarise(
    period_avg = mean(score_afinn, na.rm = TRUE),
    period_median = median(score_afinn, na.rm = TRUE),
    period_trimmed_mean = calculate_trimmed_mean(score_afinn),
    period_q1 = quantile(score_afinn, 0.25, names = FALSE, na.rm = TRUE),
    period_q3 = quantile(score_afinn, 0.75, names = FALSE, na.rm = TRUE),
    period_min = min(score_afinn, na.rm = TRUE),
    period_max = max(score_afinn, na.rm = TRUE),
    review_count = n(),
    score_total = sum(score_afinn, na.rm = TRUE),
    .groups = "drop"
  )

# Create one row per calendar month.
# period_avg is the average sentiment score scaled to a median-length review.
# review_count tells us how many reviews were written in that month.
# score_total is used for rolling averages and prior averages.
month_averages <- month_lookup %>%
  left_join(
    reviewed_month_averages,
    by = c("month_start", "month_index", "month_label", "quarter_start", "quarter_label")
  ) %>%
  mutate(
    review_count = replace_na(review_count, 0L),
    score_total = replace_na(score_total, 0)
  ) %>%
  arrange(month_start) %>%
  add_prior_period_average() %>%
  mutate(
    # rolling_avg_6 is the 6-month rolling average.
    # For each month, it averages that month plus the previous five months.
    # This smooths out noisy spikes from months with only a few reviews.
    rolling_avg_6 = purrr::map_dbl(
      row_number(),
      ~ {
        window_start <- max(1, .x - 5)
        window_review_count <- sum(review_count[window_start:.x])
        if (window_review_count == 0) {
          NA_real_
        } else {
          sum(score_total[window_start:.x]) / window_review_count
        }
      }
    ),
    # These fields are used for the heatmap.
    # year_label becomes the heatmap row.
    # month_name becomes the heatmap column.
    # heatmap_label is the text printed inside each heatmap cell.
    year_label = as.character(lubridate::year(month_start)),
    month_name = factor(
      month.abb[lubridate::month(month_start)],
      levels = month.abb
    ),
    heatmap_label = if_else(
      review_count > 0,
      paste0(format_stat(period_avg), "\nn=", review_count),
      "n=0"
    )
  )

# quarter_bands stores the start and end position of each quarter on the monthly
# timeline. The rolling chart uses these bands as a light background so the
# viewer can quickly see where each quarter begins and ends.
quarter_bands <- month_lookup %>%
  group_by(quarter_start, quarter_label) %>%
  summarise(
    xmin = min(month_index) - 0.5,
    xmax = max(month_index) + 0.5,
    .groups = "drop"
  ) %>%
  mutate(band = row_number() %% 2)

# Create one row per quarter for the quarterly boxplot.
# We keep the quarter average, review count, and prior average so the chart can
# compare each quarter with the hotel's history before that quarter.
quarter_averages <- trend_reviews %>%
  group_by(quarter_start, quarter_label) %>%
  summarise(
    period_avg = mean(score_afinn, na.rm = TRUE),
    period_median = median(score_afinn, na.rm = TRUE),
    period_trimmed_mean = calculate_trimmed_mean(score_afinn),
    period_q1 = quantile(score_afinn, 0.25, names = FALSE, na.rm = TRUE),
    period_q3 = quantile(score_afinn, 0.75, names = FALSE, na.rm = TRUE),
    period_min = min(score_afinn, na.rm = TRUE),
    period_max = max(score_afinn, na.rm = TRUE),
    review_count = n(),
    score_total = sum(score_afinn, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(quarter_start) %>%
  mutate(quarter_index = row_number()) %>%
  add_prior_period_average() %>%
  left_join(quarter_bands, by = c("quarter_start", "quarter_label"))

# Create one row per year for the yearly boxplot.
# This table contains more statistics because the yearly chart has enough room
# to print a detailed statistics block below each box.
year_averages <- trend_reviews %>%
  group_by(year_label) %>%
  summarise(
    # Store all yearly scores temporarily so we can count outliers after
    # calculating the boxplot fences.
    scores = list(score_afinn),
    period_avg = mean(score_afinn, na.rm = TRUE),
    period_median = median(score_afinn, na.rm = TRUE),
    period_trimmed_mean = calculate_trimmed_mean(score_afinn),
    period_q1 = quantile(score_afinn, 0.25, names = FALSE, na.rm = TRUE),
    period_q3 = quantile(score_afinn, 0.75, names = FALSE, na.rm = TRUE),
    period_min = min(score_afinn, na.rm = TRUE),
    period_max = max(score_afinn, na.rm = TRUE),
    iqr = IQR(score_afinn),
    review_count = n(),
    score_total = sum(score_afinn, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(year_label) %>%
  mutate(year_index = row_number()) %>%
  add_prior_period_average() %>%
  mutate(
    lower_outlier_fence = period_q1 - 1.5 * iqr,
    upper_outlier_fence = period_q3 + 1.5 * iqr
  ) %>%
  # A boxplot normally treats very low or very high values as outliers when
  # they are more than 1.5 IQR away from the box.
  # Here we count those outliers manually so the students can see the number.
  rowwise() %>%
  mutate(n_outliers = sum(scores < lower_outlier_fence | scores > upper_outlier_fence)) %>%
  ungroup() %>%
  select(-stats_label) %>%
  select(-scores) %>%
  mutate(
    stats_label = paste0(
      "n=", review_count,
      "\navg=", format_stat(period_avg),
      "\nmedian=", format_stat(period_median),
      "\ntrimmed=", format_stat(period_trimmed_mean),
      "\nq1=", format_stat(period_q1),
      "\nq3=", format_stat(period_q3),
      "\nmin=", format_stat(period_min),
      "\nmax=", format_stat(period_max),
      "\nn_outliers=", n_outliers
    )
  )

# Build a CSV table that shows how each period compares with the hotel's past.
# This is not a management action rule. It is a statistical monitoring output:
# negative robust z-scores mean the current period is below the historical median.
# Require at least 3 reviews in the current period and at least 20 older reviews
# before raising a statistical flag. This avoids overreacting to tiny samples.
minimum_current_reviews_for_drift <- 3
minimum_baseline_reviews_for_drift <- 20

build_sentiment_period_summary <- function(data, period_type_value, period_start_col, period_label_col) {
  # The same function works for months, quarters, and years. The period_start_col
  # and period_label_col arguments tell R which date columns to group by.
  period_rows <- data %>%
    group_by(
      period_start = .data[[period_start_col]],
      period_label = .data[[period_label_col]]
    ) %>%
    # One summary row is created for each time period. We keep raw sentiment
    # scores for auditability and normalized scores for fair period comparisons.
    summarise(
      period_type = period_type_value,
      review_count = n(),
      median_review_word_count = first(median_review_word_count),
      mean_afinn_raw = mean(score_afinn_raw, na.rm = TRUE),
      median_afinn_raw = median(score_afinn_raw, na.rm = TRUE),
      trimmed_mean_afinn_raw = calculate_trimmed_mean(score_afinn_raw),
      mean_afinn_per_median_review = mean(score_afinn_per_median_review, na.rm = TRUE),
      median_afinn_per_median_review = median(score_afinn_per_median_review, na.rm = TRUE),
      trimmed_mean_afinn_per_median_review = calculate_trimmed_mean(score_afinn_per_median_review),
      mean_syuzhet_raw = mean(score_syuzhet_raw, na.rm = TRUE),
      median_syuzhet_raw = median(score_syuzhet_raw, na.rm = TRUE),
      trimmed_mean_syuzhet_raw = calculate_trimmed_mean(score_syuzhet_raw),
      mean_syuzhet_per_median_review = mean(score_syuzhet_per_median_review, na.rm = TRUE),
      median_syuzhet_per_median_review = median(score_syuzhet_per_median_review, na.rm = TRUE),
      trimmed_mean_syuzhet_per_median_review = calculate_trimmed_mean(score_syuzhet_per_median_review),
      mean_rating = mean(rating_number, na.rm = TRUE),
      median_rating = median(rating_number, na.rm = TRUE),
      trimmed_mean_rating = calculate_trimmed_mean(rating_number),
      low_rating_share = mean(rating_number <= 3, na.rm = TRUE),
      negative_text_share = mean(score_afinn_per_median_review < 0, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(period_start)

  period_rows %>%
    # rowwise() means the calculations below happen one period at a time.
    # That is important because every period has a different historical baseline.
    rowwise() %>%
    mutate(
      # The baseline contains only reviews before the current period. This prevents
      # future reviews from influencing a past period's warning score.
      baseline_review_count = sum(data$date_parsed < period_start & !is.na(data$score_afinn_per_median_review)),
      historical_median_afinn_per_median_review = if_else(
        baseline_review_count >= minimum_baseline_reviews_for_drift,
        median(data$score_afinn_per_median_review[data$date_parsed < period_start], na.rm = TRUE),
        NA_real_
      ),
      historical_mad_afinn_per_median_review = calculate_robust_mad(
        data$score_afinn_per_median_review[data$date_parsed < period_start],
        minimum_count = minimum_baseline_reviews_for_drift
      ),
      robust_z_afinn_median = calculate_robust_z(
        median_afinn_per_median_review,
        data$score_afinn_per_median_review[data$date_parsed < period_start],
        minimum_count = minimum_baseline_reviews_for_drift
      ),
      # Rating drift uses the same prior-history idea as sentiment drift, but it
      # looks at TripAdvisor star ratings instead of text sentiment.
      historical_median_rating = if_else(
        baseline_review_count >= minimum_baseline_reviews_for_drift,
        median(data$rating_number[data$date_parsed < period_start], na.rm = TRUE),
        NA_real_
      ),
      historical_mad_rating = calculate_robust_mad(
        data$rating_number[data$date_parsed < period_start],
        minimum_count = minimum_baseline_reviews_for_drift
      ),
      robust_z_rating_median = calculate_robust_z(
        median_rating,
        data$rating_number[data$date_parsed < period_start],
        minimum_count = minimum_baseline_reviews_for_drift
      ),
      # A TRUE flag means "this period deserves closer inspection." It does not
      # mean the project has proven a management or investment decision.
      sentiment_drift_flag = review_count >= minimum_current_reviews_for_drift &
        baseline_review_count >= minimum_baseline_reviews_for_drift &
        !is.na(robust_z_afinn_median) &
        robust_z_afinn_median <= -2,
      rating_drift_flag = review_count >= minimum_current_reviews_for_drift &
        baseline_review_count >= minimum_baseline_reviews_for_drift &
        !is.na(robust_z_rating_median) &
        robust_z_rating_median <= -2,
      any_drift_flag = sentiment_drift_flag | rating_drift_flag
    ) %>%
    ungroup()
}

sentiment_period_summary <- bind_rows(
  build_sentiment_period_summary(trend_reviews, "month", "month_start", "month_label"),
  build_sentiment_period_summary(trend_reviews, "quarter", "quarter_start", "quarter_label"),
  build_sentiment_period_summary(trend_reviews, "year", "year_start", "year_label")
)

# Save output/reports/sentiment_period_summary.csv for review and later writing.
write_csv(sentiment_period_summary, sentiment_period_summary_path)

# Add quarter_index and year_index back onto the review-level data.
# The boxplots use these simple numbers for clean x-axis positioning.
trend_reviews <- trend_reviews %>%
  left_join(select(quarter_averages, quarter_start, quarter_index), by = "quarter_start") %>%
  left_join(select(year_averages, year_label, year_index), by = "year_label")

# The monthly timeline has many months, so we show only every 6th month label.
# This keeps the x-axis readable.
month_breaks <- month_lookup$month_index[seq(1, nrow(month_lookup), by = 6)]
month_labels <- month_lookup$month_label[seq(1, nrow(month_lookup), by = 6)]
month_stat_labels <- month_averages %>%
  filter(month_index %in% month_breaks)

# The quarterly timeline has many quarters, so we label every 4th quarter.
# That is roughly one label per year.
quarter_breaks <- quarter_averages$quarter_index[seq(1, nrow(quarter_averages), by = 4)]
quarter_labels <- quarter_averages$quarter_label[seq(1, nrow(quarter_averages), by = 4)]

# Monthly heatmap for a compact month-by-year overview.
# In this chart:
# - Rows are years.
# - Columns are months.
# - Darker green means a higher average sentiment score.
# - Pale or red cells mean lower sentiment.
# - The text inside each cell shows the average score and number of reviews.
p4_heatmap <- ggplot(month_averages, aes(x = month_name, y = year_label, fill = period_avg)) +
  geom_tile(color = "white", linewidth = 0.4) +
  geom_text(aes(label = heatmap_label), size = 2.1, color = "#2C3E50", lineheight = 0.85) +
  scale_fill_gradient2(
    low = "#C0392B",
    mid = "#F7F9F9",
    high = "#16A085",
    midpoint = 0,
    name = "Average\nAFINN per\nmedian-length review",
    na.value = "#F4F6F7"
  ) +
  labs(
    title = "Monthly Sentiment Heatmap (AFINN per Median-Length Review)",
    subtitle = "Each tile shows monthly average length-normalized sentiment and review count",
    x = "Month",
    y = "Year"
  ) +
  theme_premium() +
  theme(
    legend.position = "right",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

show_plot_for_interactive_use(p4_heatmap)

ggsave(file.path(figures_dir, "sentiment_trend_monthly_heatmap.png"), plot = p4_heatmap, width = 10, height = 8, dpi = 300)

# Monthly rolling chart for the trend story.
# This chart is better than 189 tiny monthly boxplots because many months have
# very few reviews. Instead, it shows:
# - A grey line for the raw monthly average.
# - Circles for each monthly average.
# - Larger circles when a month has more reviews.
# - A blue 6-month rolling average to smooth the noise.
# - A dotted prior average line to compare the current month with past history.
p4_rolling <- ggplot() +
  geom_rect(
    data = quarter_bands,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = factor(band)),
    alpha = 0.08,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = month_averages,
    aes(x = month_index, y = period_avg),
    color = "#95A5A6",
    linewidth = 0.45,
    alpha = 0.7,
    inherit.aes = FALSE
  ) +
  geom_point(
    data = month_averages,
    aes(x = month_index, y = period_avg, size = review_count, color = period_avg),
    shape = 21,
    fill = "white",
    stroke = 0.9,
    alpha = 0.9,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = month_averages,
    aes(x = month_index, y = rolling_avg_6),
    color = "#2980B9",
    linewidth = 1.1,
    inherit.aes = FALSE
  ) +
  geom_line(
    data = filter(month_averages, !is.na(prior_avg)),
    aes(x = month_index, y = prior_avg),
    color = "#7F8C8D",
    linetype = "dotted",
    linewidth = 1,
    inherit.aes = FALSE
  ) +
  scale_fill_manual(values = c("0" = "#EAF2F8", "1" = "#FDF2E9")) +
  scale_color_gradient2(low = "#C0392B", mid = "#95A5A6", high = "#16A085", midpoint = 0) +
  scale_size_continuous(range = c(1.4, 5)) +
  scale_x_continuous(breaks = month_breaks, labels = month_labels) +
  labs(
    title = "Monthly Sentiment Trend with Rolling Average (AFINN per Median-Length Review)",
    subtitle = "Points show monthly averages sized by review count; blue line is the 6-month rolling average; dotted line is prior average",
    x = "Timeline (Month/Year)",
    y = "AFINN per median-length review"
  ) +
  theme_premium() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Show the chart in RStudio, but do not open a PDF device during Rscript runs.
show_plot_for_interactive_use(p4_rolling)

ggsave(file.path(figures_dir, "sentiment_trend_monthly_rolling.png"), plot = p4_rolling, width = 10, height = 5.5, dpi = 300)

# Monthly robust drift monitor. This chart saves output/figures/sentiment_drift_monitor.png.
# It views each month's median sentiment
# against only the reviews that came before that month. A value near 0 means the
# month looks typical. A value below -2 means it is unusually low by a robust
# median-and-MAD rule, if there are enough current and historical reviews.
monthly_drift_monitor <- sentiment_period_summary %>%
  filter(period_type == "month", !is.na(robust_z_afinn_median))

if (nrow(monthly_drift_monitor) > 0) {
  p4_drift <- ggplot(
    monthly_drift_monitor,
    aes(x = period_start, y = robust_z_afinn_median)
  ) +
    geom_hline(yintercept = 0, color = "#7F8C8D", linewidth = 0.45) +
    geom_hline(yintercept = -2, color = "#C0392B", linetype = "dashed", linewidth = 0.8) +
    geom_col(aes(fill = any_drift_flag), width = 24, alpha = 0.76) +
    geom_point(aes(size = review_count), color = "#2C3E50", alpha = 0.82) +
    scale_fill_manual(values = c("FALSE" = "#7FB3D5", "TRUE" = "#C0392B")) +
    scale_size_continuous(range = c(1.8, 5.2)) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(
      title = "Monthly Sentiment Drift Monitor",
      subtitle = "Monthly median AFINN compared with prior reviews using historical median and MAD",
      x = "Review month",
      y = "Robust z-score"
    ) +
    theme_premium() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  show_plot_for_interactive_use(p4_drift)
  ggsave(sentiment_drift_monitor_path, plot = p4_drift, width = 10, height = 5.5, dpi = 300)
} else {
  save_placeholder_plot(
    basename(sentiment_drift_monitor_path),
    "Monthly Sentiment Drift Monitor",
    "There are not enough historical reviews to calculate robust drift scores yet.",
    width = 10,
    height = 5.5
  )
}

# Quarterly boxplot for quarter-level statistics.
# A quarterly boxplot groups all reviews from the same quarter together.
# This is useful because quarters usually have more reviews than single months,
# so the distribution is more meaningful.
p5 <- ggplot(trend_reviews, aes(x = quarter_index, y = score_afinn, group = quarter_index)) +
  geom_boxplot(fill = "#D5F5E3", color = "#1E8449", alpha = 0.85, outlier.alpha = 0.35) +
  geom_point(
    data = quarter_averages,
    aes(x = quarter_index, y = period_avg),
    shape = 23,
    size = 2.8,
    fill = "#C0392B",
    color = "white",
    inherit.aes = FALSE
  ) +
  geom_line(
    data = filter(quarter_averages, !is.na(prior_avg)),
    aes(x = quarter_index, y = prior_avg),
    color = "#7F8C8D",
    linetype = "dotted",
    linewidth = 1,
    inherit.aes = FALSE
  ) +
  geom_text(
    data = quarter_averages,
    aes(x = quarter_index, y = stats_label_y, label = stats_label),
    angle = 90,
    hjust = 0.5,
    size = 1.9,
    color = "#34495E",
    inherit.aes = FALSE
  ) +
  scale_x_continuous(breaks = quarter_breaks, labels = quarter_labels) +
  scale_y_continuous(limits = c(stats_axis_floor, NA), expand = expansion(mult = c(0, 0.12))) +
  labs(
    title = "Quarterly Sentiment Distribution (AFINN per Median-Length Review)",
    subtitle = "Each box summarizes one quarter; labels show quarter avg and n; dotted line shows the average before each quarter",
    x = "Quarter",
    y = "AFINN per median-length review"
  ) +
  theme_premium() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))

show_plot_for_interactive_use(p5)
ggsave(file.path(figures_dir, "sentiment_trend_quarterly.png"), plot = p5, width = 14, height = 6, dpi = 300)

# Yearly boxplot for year-level statistics.
# The yearly chart has the most detailed labels because there are only about
# twenty years, which leaves enough room below each box.
# The label under each year shows:
# n = number of reviews
# avg = average sentiment score
# median = middle sentiment score
# q1 and q3 = the lower and upper edges of the box
# min and max = lowest and highest sentiment scores
# n_outliers = how many unusual values fall outside the whiskers
p6 <- ggplot(trend_reviews, aes(x = year_index, y = score_afinn, group = year_index)) +
  geom_boxplot(fill = "#FADBD8", color = "#922B21", alpha = 0.85, outlier.alpha = 0.35) +
  geom_point(
    data = year_averages,
    aes(x = year_index, y = period_avg),
    shape = 23,
    size = 3,
    fill = "#2C3E50",
    color = "white",
    inherit.aes = FALSE
  ) +
  geom_text(
    data = year_averages,
    aes(x = year_index, y = year_stats_label_y, label = stats_label),
    vjust = 0.5,
    size = 2,
    lineheight = 0.86,
    color = "#2C3E50",
    inherit.aes = FALSE
  ) +
  geom_line(
    data = filter(year_averages, !is.na(prior_avg)),
    aes(x = year_index, y = prior_avg),
    color = "#7F8C8D",
    linetype = "dotted",
    linewidth = 1,
    inherit.aes = FALSE
  ) +
  scale_x_continuous(breaks = year_averages$year_index, labels = year_averages$year_label) +
  scale_y_continuous(limits = c(year_stats_axis_floor, NA), expand = expansion(mult = c(0, 0.12))) +
  labs(
    title = "Yearly Sentiment Distribution (AFINN per Median-Length Review)",
    subtitle = "Each box summarizes one year; labels show n, mean, median, quartiles, min, max, and outliers",
    x = "Year",
    y = "AFINN per median-length review"
  ) +
  theme_premium() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

show_plot_for_interactive_use(p6)
ggsave(file.path(figures_dir, "sentiment_trend_yearly.png"), plot = p6, width = 16, height = 8, dpi = 300)

if (interactive()) {
  cat("Showing the emotions breakdown chart again in the RStudio Plots pane.\n")
  print(p2)
}

cat("Visualizations successfully drawn and saved to the 'output/figures/' folder!\n")
