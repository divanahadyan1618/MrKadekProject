# =====================================================================
# TripAdvisor Sentiment Analysis - Step 3: Sentiment Lexicon Scoring
# =====================================================================
# Welcome! If you have never programmed before, do not worry.
# We will explain exactly what the computer is doing at every single step.
#
# PURPOSE OF THIS SCRIPT:
# How does a computer know if a review is happy or angry? It uses a "Lexicon".
# A Lexicon is simply a giant dictionary where scientists have manually assigned 
# numeric scores to words. For example: "excellent" = +4, "dirty" = -3.
# We will scan our clean reviews against these dictionaries to calculate a final score.

# =====================================================================
# STEP 1: Load Required Packages
# =====================================================================
# 'tidyverse' and 'tidytext' help us read and manipulate our tables.
library(tidyverse)
library(tidytext)

# 'syuzhet' is a very famous toolset built specifically for Sentiment Analysis.
# It contains the massive dictionaries we need to score emotions.
library(syuzhet)
source("scripts/data_config.R")
source("scripts/helpers.R")

cat("Libraries loaded successfully!\n")

# =====================================================================
# STEP 2: Open the Cleaned Reviews
# =====================================================================
# We load the full cleaned sentences from Step 2 into a box named 'cleaned_reviews'.
if (!file.exists(cleaned_reviews_path)) {
  stop(
    paste(
      "Missing cleaned review data at:",
      cleaned_reviews_path,
      "Run Step 2 first with: Rscript 02_cleaning.R"
    ),
    call. = FALSE
  )
}

cleaned_reviews <- read_csv(cleaned_reviews_path, show_col_types = FALSE)

cat("Loaded", nrow(cleaned_reviews), "cleaned reviews for emotional scoring.\n")

# =====================================================================
# STEP 3: Apply the Dictionary Lexicons (Syuzhet & AFINN)
# =====================================================================
# We are asking the computer to read every review and calculate a math score.
# We use two different methods to be thorough:
# 1. "syuzhet" method: A standard scientific scoring system.
# 2. "afinn" method: The word-level lexicon runs from -5 (furious) to
#    +5 (thrilled). For a full review, the method adds those word scores
#    together, so score_afinn is a summed review score and can be above +5
#    or below -5.
# The helper below flips sentiment words that appear right after negators such
# as "not", "never", "without", or "cannot". This keeps phrases like "cannot
# recommend" from being counted as positive just because "recommend" is positive.
# We also count the words in each cleaned review. The raw sentiment scores are
# still saved, but the workflow also creates length-normalized scores using the
# median review length in this dataset. That means the denominator comes from the
# hotel's own data instead of from a round number chosen by hand.

# 'mutate' means "create a new column in our table".
sentiment_results <- cleaned_reviews %>%
  mutate(
    # review_word_count stores how long each cleaned review is.
    # We need this because raw sentiment scores grow when a review has more words.
    review_word_count = count_cleaned_words(cleaned_text),
    score_syuzhet = score_negation_aware_sentiment(cleaned_text, method = "syuzhet"),
    score_afinn = score_negation_aware_sentiment(cleaned_text, method = "afinn")
  )

# Find the "typical" review length in this dataset.
# We ignore empty reviews because a review with 0 words cannot be used as a
# sensible denominator.
median_review_word_count <- sentiment_results %>%
  filter(review_word_count > 0) %>%
  summarise(value = median(review_word_count), .groups = "drop") %>%
  pull(value)

# If every cleaned review somehow had 0 words, normalization would be impossible.
# Stop here with a plain explanation instead of creating misleading NA scores.
if (length(median_review_word_count) == 0 || is.na(median_review_word_count)) {
  stop("No cleaned words were found, so sentiment scores cannot be length-normalized.", call. = FALSE)
}

sentiment_results <- sentiment_results %>%
  mutate(
    median_review_word_count = median_review_word_count,
    # These normalized scores keep the original direction of sentiment but put
    # short and long reviews onto the same typical-review length.
    score_syuzhet_per_median_review = normalize_score_to_word_count(
      score_syuzhet,
      review_word_count,
      median_review_word_count
    ),
    score_afinn_per_median_review = normalize_score_to_word_count(
      score_afinn,
      review_word_count,
      median_review_word_count
    )
  )

cat("Median cleaned review length used for normalization:", median_review_word_count, "words\n")

# =====================================================================
# STEP 4: Classify the Scores into Simple Categories
# =====================================================================
# A numeric score like "1.45" is hard to understand.
# We use 'case_when' (which is like a giant IF statement) to categorize them:
# IF the score is greater than 0  -> "Positive"
# IF the score is less than 0     -> "Negative"
# IF the score is exactly 0       -> "Neutral"

sentiment_classified <- sentiment_results %>%
  mutate(
    sentiment_category = case_when(
      score_syuzhet > 0 ~ "Positive",
      score_syuzhet < 0 ~ "Negative",
      TRUE              ~ "Neutral" # TRUE here means "everything else"
    )
  )

# Now, let's group all the "Positive" and "Negative" rows together and count them!
sentiment_summary <- sentiment_classified %>%
  group_by(sentiment_category) %>%
  summarise(
    count = n(), # n() counts the number of rows
    percentage = (n() / nrow(sentiment_classified)) * 100 # Calculate the percentage %
  )

# Print the final report to the screen
print(sentiment_summary)

# =====================================================================
# STEP 5: NRC Deep Emotion Extraction
# =====================================================================
# "Positive" or "Negative" is too basic. What if we want to know if guests are ANGRY or AFRAID?
# The 'NRC' lexicon checks text against 8 human emotions:
# (anger, anticipation, disgust, fear, joy, sadness, surprise, trust).
#
# UNDERSTANDING NRC SCORES: The output scores for NRC emotions represent the frequency 
# or counts of words associated with each specific emotion category found in the text. 
# For example, a "joy" score of 3 means there were 3 words in the review associated with joy.

cat("Processing deep emotions. The computer is reading thousands of words, please wait a few seconds...\n")

# 'get_nrc_sentiment' returns a table showing exactly how much 'joy' or 'anger' is in the text.
nrc_emotions <- get_nrc_sentiment(sentiment_classified$cleaned_text)

# 'bind_cols' acts like glue. It takes our original table, and glues the new emotion columns to the right side of it.
final_research_data <- bind_cols(sentiment_classified, nrc_emotions)

# =====================================================================
# STEP 6: Save the Scored Data
# =====================================================================
# Our table now has the original text, the numeric scores, the positive/negative labels, AND the 8 deep emotions!
# We save this final master dataset to the computer.

write_csv(final_research_data, sentiment_scores_path)
cat("Sentiment-scored research data saved successfully!\n")
