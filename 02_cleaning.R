# =====================================================================
# TripAdvisor Sentiment Analysis - Step 2: Data Cleaning & Preprocessing
# =====================================================================
# Welcome! If you have never programmed before, do not worry.
# We will explain exactly what the computer is doing at every single step.
#
# PURPOSE OF THIS SCRIPT:
# Text written by humans is very "messy". We use emojis, punctuation like "!!!",
# and slang like "u" instead of "you". Before a computer can understand emotions, 
# we have to scrub all this "noise" away. This is called Text Pre-Processing.

# =====================================================================
# STEP 1: Load Required Packages (Adding Tools)
# =====================================================================
# 'tidyverse' helps us filter and change table data easily.
library(tidyverse)
# 'tidytext' is a specialized toolset used purely for analyzing text and words.
library(tidytext)

# We wrote a file called 'helpers.R' that contains our secret cleaning recipes.
# 'source()' tells the computer to load our custom recipes into memory.
source("scripts/data_config.R")
source("scripts/helpers.R")

cat("Helper functions and libraries loaded!\n")

# =====================================================================
# STEP 2: Open the Raw Data
# =====================================================================
# 'read_csv' opens the prepared reviews CSV that Step 1 validated.
if (!file.exists(raw_reviews_path)) {
  stop(
    paste(
      "Missing raw review data at:",
      raw_reviews_path,
      "Run Step 1 first with: Rscript 01_data_import.R"
    ),
    call. = FALSE
  )
}

raw_data <- read_csv(raw_reviews_path, show_col_types = FALSE, guess_max = 10000)

sample_size <- suppressWarnings(as.integer(Sys.getenv("HOTEL_REVIEW_SAMPLE_SIZE", "0")))
if (!is.na(sample_size) && sample_size > 0 && nrow(raw_data) > sample_size) {
  raw_data <- raw_data %>% slice_head(n = sample_size)
  cat("Using the first", sample_size, "reviews because HOTEL_REVIEW_SAMPLE_SIZE is set.\n")
}

raw_data <- standardize_hotel_reviews(raw_data)

cat("Successfully loaded", nrow(raw_data), "raw reviews!\n")

# =====================================================================
# STEP 3: The Cleaning Pipeline
# =====================================================================
# The %>% symbol is a "pipe". It means "AND THEN".
# We are taking the raw data, AND THEN changing (mutating) the text column.
# 
# Our custom 'clean_text' recipe removes numbers, exclamation marks, and emojis.
# Our custom 'normalize_slang' recipe fixes internet slang (e.g., sooo -> so).

cleaned_reviews_df <- raw_data %>%
  mutate(
    # Create a new column called 'cleaned_text' that contains the scrubbed reviews.
    cleaned_text = clean_text(review_text),
    cleaned_text = normalize_slang(cleaned_text)
  )

# Let's print out the 2nd row to see what the computer did!
cat("--- THIS WAS THE MESSY ORIGINAL TEXT ---\n", cleaned_reviews_df$review_text[2], "\n\n")
cat("--- THIS IS THE PERFECTLY CLEANED TEXT ---\n", cleaned_reviews_df$cleaned_text[2], "\n")

# =====================================================================
# STEP 4: Tokenization (Chopping Sentences into Words)
# =====================================================================
# Computers don't read paragraphs; they read individual words.
# 'unnest_tokens' is a tool that takes a full sentence and chops it up.
# If a review is 10 words long, this tool creates 10 separate rows in our table!
# This process is formally called "Tokenization".

tokenized_df <- cleaned_reviews_df %>%
  unnest_tokens(output = word, input = cleaned_text)

cat("After chopping the sentences, we have", nrow(tokenized_df), "individual words!\n")

# =====================================================================
# STEP 5: Stopwords Removal (Throwing away useless words)
# =====================================================================
# "Stopwords" are words like "the", "and", "is", "at".
# They are required for human grammar, but they have zero emotion.
# If we ask the computer "Is the word 'the' happy or sad?", it gets confused.
# So, we use 'remove_stopwords' to delete them completely.

clean_tokens_df <- remove_stopwords(tokenized_df, word_column = "word")

cat("After throwing away useless stopwords, we only have", nrow(clean_tokens_df), "important words left.\n")

# =====================================================================
# STEP 6: Save the Clean Data
# =====================================================================
# We now have two beautiful, clean tables. 
# 1. cleaned_reviews_df: The full sentences (used for scoring the hotel).
# 2. clean_tokens_df: The chopped individual words (used for the wordcloud).

# Let's save them to the computer!
dir.create(dirname(cleaned_reviews_path), recursive = TRUE, showWarnings = FALSE)

write_csv(cleaned_reviews_df, cleaned_reviews_path)
write_csv(clean_tokens_df, cleaned_tokens_path)

cat("Cleaned reviews & tokens successfully saved to the 'data/cleaned/' folder!\n")
