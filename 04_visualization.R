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

# Print the chart so it shows up in RStudio!
print(p1)

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

print(p1b)

ggsave(file.path(figures_dir, "sentiment_by_rating_boxplot.png"), plot = p1b, width = 9.5, height = 5.8, dpi = 300)

# =====================================================================
# STEP 4: Draw the Deep Emotion Chart (Joy, Trust, Anger, etc.)
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

# Print the chart so it shows up in RStudio!
print(p2)

ggsave(file.path(figures_dir, "emotions_breakdown.png"), plot = p2, width = 8, height = 5, dpi = 300)

# =====================================================================
# STEP 5: Draw the Word Cloud
# =====================================================================
# A Word Cloud shows the most frequently used words. The bigger the word, the more it was used!
# We 'filter' out boring words like 'hotel' and 'bali' because they waste space.
word_counts <- cleaned_tokens %>%
  count(word, sort = TRUE) %>%
  filter(!word %in% c("hotel", "resort", "tripadvisor", "review", "stay", "room", "villa", "service"))

cat("Drawing the word cloud...\n")

# Display the word cloud in the RStudio Plots tab!
set.seed(123)
wordcloud(
  words = word_counts$word,
  freq = word_counts$n,
  min.freq = 2,
  max.words = 40,
  random.order = FALSE,
  rot.per = 0.2,
  colors = brewer.pal(8, "Dark2")
)

# Open a digital "canvas" to draw the picture on
png(file.path(figures_dir, "wordcloud.png"), width = 800, height = 800, res = 150)
set.seed(123) # Lock the randomness so the cloud looks exactly the same every time we run it

# Call the wordcloud drawing tool
wordcloud(
  words = word_counts$word,   # What words to draw
  freq = word_counts$n,       # How big to draw them based on frequency
  min.freq = 2,               # Ignore words that only appeared once
  max.words = 40,             # Stop drawing after 40 words so it doesn't look messy
  random.order = FALSE,       # Put the biggest words right in the center
  rot.per = 0.2,              # Randomly rotate 20% of the words sideways
  colors = brewer.pal(8, "Dark2") # Paint them with cool colors
)
dev.off() # Close the digital canvas and save the file!

# =====================================================================
# STEP 6: Draw Sentiment Trend Charts
# =====================================================================
# We want to see if the hotel's review sentiment changes over time.
# This section creates several different time-based charts because each chart
# answers a slightly different research question:
# 1. Monthly heatmap: Which months/years look stronger or weaker?
# 2. Monthly rolling trend: Is sentiment moving up or down over time?
# 3. Quarterly boxplot: How much do reviews vary inside each quarter?
# 4. Yearly boxplot: How much do reviews vary inside each year?
parse_review_dates <- function(date_values) {
  # Dates can be written in different formats.
  # This helper tries several common date formats until one works.
  # suppressWarnings() keeps R from printing scary warning messages every time
  # one date format does not match.
  date_text <- as.character(date_values)
  parsed <- as.Date(suppressWarnings(lubridate::ymd(date_text)))

  missing_dates <- is.na(parsed)
  parsed[missing_dates] <- as.Date(suppressWarnings(lubridate::mdy(date_text[missing_dates])))

  missing_dates <- is.na(parsed)
  parsed[missing_dates] <- as.Date(suppressWarnings(lubridate::dmy(date_text[missing_dates])))

  missing_dates <- is.na(parsed)
  parsed[missing_dates] <- as.Date(suppressWarnings(lubridate::my(date_text[missing_dates])))

  parsed
}

trend_reviews <- research_data %>%
  mutate(
    # The TripAdvisor export may use full dates or month-year labels.
    date_parsed = parse_review_dates(review_date),
    month_start = lubridate::floor_date(date_parsed, "month"),
    quarter_start = lubridate::floor_date(date_parsed, "quarter"),
    quarter_label = paste0(lubridate::year(date_parsed), " Q", lubridate::quarter(date_parsed)),
    year_label = as.character(lubridate::year(date_parsed))
  ) %>%
  filter(!is.na(date_parsed), !is.na(score_afinn)) # Ignore broken dates and scores

# Give every month a simple number: 1, 2, 3, and so on.
# This makes it easier to draw long timelines because ggplot can place months
# evenly across the x-axis.
month_lookup <- trend_reviews %>%
  distinct(month_start) %>%
  arrange(month_start) %>%
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

# Create one row per month.
# period_avg is the average sentiment score for that month.
# review_count tells us how many reviews were written in that month.
# score_total is used for rolling averages and prior averages.
month_averages <- trend_reviews %>%
  group_by(month_start, month_index, month_label, quarter_start, quarter_label) %>%
  summarise(
    period_avg = mean(score_afinn),
    review_count = n(),
    score_total = sum(score_afinn),
    .groups = "drop"
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
        sum(score_total[window_start:.x]) / sum(review_count[window_start:.x])
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
    heatmap_label = paste0(format_stat(period_avg), "\nn=", review_count)
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
    period_avg = mean(score_afinn),
    review_count = n(),
    score_total = sum(score_afinn),
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
    period_avg = mean(score_afinn),
    period_median = median(score_afinn),
    period_q1 = quantile(score_afinn, 0.25, names = FALSE),
    period_q3 = quantile(score_afinn, 0.75, names = FALSE),
    period_min = min(score_afinn),
    period_max = max(score_afinn),
    iqr = IQR(score_afinn),
    review_count = n(),
    score_total = sum(score_afinn),
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
      "\nq1=", format_stat(period_q1),
      "\nq3=", format_stat(period_q3),
      "\nmin=", format_stat(period_min),
      "\nmax=", format_stat(period_max),
      "\nn_outliers=", n_outliers
    )
  )

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
    name = "Average\nAFINN"
  ) +
  labs(
    title = "Monthly Sentiment Heatmap (AFINN Scores)",
    subtitle = "Each tile shows monthly average sentiment and review count",
    x = "Month",
    y = "Year"
  ) +
  theme_premium() +
  theme(
    legend.position = "right",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

print(p4_heatmap)

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
    title = "Monthly Sentiment Trend with Rolling Average (AFINN Scores)",
    subtitle = "Points show monthly averages sized by review count; blue line is the 6-month rolling average; dotted line is prior average",
    x = "Timeline (Month/Year)",
    y = "AFINN Sentiment Score"
  ) +
  theme_premium() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Print the chart so it shows up in RStudio!
print(p4_rolling)

ggsave(file.path(figures_dir, "sentiment_trend.png"), plot = p4_rolling, width = 10, height = 5.5, dpi = 300)
ggsave(file.path(figures_dir, "sentiment_trend_monthly_rolling.png"), plot = p4_rolling, width = 10, height = 5.5, dpi = 300)

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
    title = "Quarterly Sentiment Distribution (AFINN Scores)",
    subtitle = "Each box summarizes one quarter; labels show quarter avg and n; dotted line shows the average before each quarter",
    x = "Quarter",
    y = "AFINN Sentiment Score"
  ) +
  theme_premium() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))

print(p5)
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
    title = "Yearly Sentiment Distribution (AFINN Scores)",
    subtitle = "Each box summarizes one year; labels show n, mean, median, quartiles, min, max, and outliers",
    x = "Year",
    y = "AFINN Sentiment Score"
  ) +
  theme_premium() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(p6)
ggsave(file.path(figures_dir, "sentiment_trend_yearly.png"), plot = p6, width = 16, height = 8, dpi = 300)

if (interactive()) {
  cat("Showing the emotions breakdown chart again in the RStudio Plots pane.\n")
  print(p2)
}

cat("Visualizations successfully drawn and saved to the 'output/figures/' folder!\n")
