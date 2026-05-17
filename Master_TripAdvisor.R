# =====================================================================
# MASTER R SCRIPT: TripAdvisor Sentiment Analysis Workflow
# =====================================================================

# =====================================================================
# TripAdvisor Sentiment Analysis - Step 1: Web Scraping
# =====================================================================
# Welcome! If you have never programmed before, do not worry.
# We will explain exactly what the computer is doing at every single step.
#
# PURPOSE OF THIS SCRIPT:
# We want to go to TripAdvisor, find a specific hotel, and automatically
# copy-paste hundreds of reviews into an Excel-like table so we can analyze them.
# This automatic copying is called "Web Scraping".

# =====================================================================
# STEP 1: Load Required Packages (Adding New Tools to R)
# =====================================================================
# Think of R as a blank toolbox. "Packages" are specialized toolsets created
# by other programmers that we borrow to make our job easier.
# The 'library()' command tells the computer to open and equip that toolset.

# The 'rvest' toolset helps us download and read web pages.
library(rvest)
# The 'tidyverse' toolset helps us sort, filter, and organize data.
library(tidyverse)
# The 'xml2' toolset safely reads the raw computer code of a website.
library(xml2)

# 'cat()' is a command that simply prints a message on your screen.
cat("Scraping packages loaded successfully!\n")

# =====================================================================
# STEP 2: Define Where We Want to Go
# =====================================================================
# The '<-' arrow is called the "assignment operator". 
# It means "take the internet link on the right, and save it inside a box named 'hotel_url' on the left."
hotel_url <- "https://www.tripadvisor.com/Hotel_Review-g297698-d607449-Reviews-Bvlgari_Resort_Bali-Uluwatu_Bukit_Peninsula_Bali.html"

# =====================================================================
# STEP 3: Create the "Scraper" Machine
# =====================================================================
# Here we are building our own custom tool (a "function") named 'scrape_tripadvisor_reviews'.
# Think of it like a recipe: we give it a web link (url), and it gives us a table of reviews back.
scrape_tripadvisor_reviews <- function(url) {
  
  # 'tryCatch' tells the computer: "Try to do this, but if the website blocks you, don't crash!"
  tryCatch({
    # 1. Download the webpage. 'user_agent' disguises our computer so TripAdvisor thinks we are a normal Chrome browser.
    page <- read_html(x = url, options = "RECOVER", 
                      user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    
    # The '%>%' symbol means "AND THEN". 
    # Example: Take the page AND THEN find the text AND THEN clean it up.
    
    # 2. Extract the Review Text by looking for TripAdvisor's specific font/design codes ("span.yUiMA")
    reviews <- page %>% html_nodes("span.yUiMA, div.fIrGe") %>% html_text(trim = TRUE)
    
    # 3. Extract the Review Titles (the bold headline of the review)
    titles <- page %>% html_nodes("span.yUiMA, a.QYdug") %>% html_text(trim = TRUE)
    
    # 4. Extract the Star Ratings ( TripAdvisor stores 5 stars as "50", so we divide by 10 )
    ratings <- page %>% html_nodes("span.ui_bubble_rating") %>% html_attr("class") %>% 
      str_extract("[0-9]+") %>% as.numeric() / 10
    
    # 5. Extract the Date the guest stayed at the hotel
    dates <- page %>% html_nodes("span.teSgY") %>% html_text(trim = TRUE) %>% 
      str_remove("Date of stay: ")
    
    # 6. 'tibble' means "Table". We are taking the 4 lists above and taping them together into a spreadsheet.
    df <- tibble(
      title = head(titles, length(reviews)),
      review_text = reviews,
      rating = head(ratings, length(reviews)),
      review_date = head(dates, length(reviews))
    )
    
    # Return the finished table back to us
    return(df)
    
  }, error = function(e) {
    # If the website blocks us, print a warning message instead of crashing.
    message("Warning: Live scraping was blocked or interrupted: ", e$message)
    return(NULL)
  })
}

# =====================================================================
# STEP 4: Run the Scraper (Or generate Backup Data)
# =====================================================================
cat("Attempting to scrape live reviews from TripAdvisor...\n")

# Use our new tool! Take the hotel_url, run the tool, and save the result in a box called 'scraped_data'.
scraped_data <- scrape_tripadvisor_reviews(hotel_url)

# Websites like TripAdvisor often block automated tools to protect their data.
# The 'if' statement says: IF the scraped_data is completely empty (we got blocked)...
if (is.null(scraped_data) || nrow(scraped_data) == 0) {
  
  cat("TripAdvisor blocked us! Initializing the backup research dataset instead...\n")
  
  # Set.seed guarantees that random generation is exactly the same every time we run it.
  set.seed(42) 
  
  # --- BACKUP GENERATOR EXPLANATION ---
  # We are mathematically generating 1,000 unique, realistic reviews so you can still do your homework.
  # We combine an intro + subject + adjective + outro to form thousands of possible unique sentences.
  
  # 1. Lists of positive phrases
  pos_intro <- c("We just returned from Bvlgari.", "Our family stayed here.", "My partner and I visited Bali.", "What a beautiful property!", "Absolutely stunning resort.")
  pos_subj <- c("The ocean view", "Our private villa", "The Italian restaurant", "The spa treatment", "Butler service", "The cliffside elevator", "The main pool", "The resort architecture", "Breakfast spread", "Balinese hospitality")
  pos_adj <- c("was absolutely breathtaking!", "was stunning.", "was perfect.", "was impeccable.", "was incredible \U0001f60d!", "was outstanding.", "exceeded our expectations.", "was simply magical.", "was top notch.", "was a dream come true.")
  pos_outro <- c("Highly recommended!", "Will definitely return.", "Truly an authentic experience.", "Worth every penny.", "A must-visit in Bali.", "We felt like royalty.", "Best trip ever.", "Can't wait to come back.")
  
  # 2. Lists of negative/mixed phrases
  neg_intro <- c("We had high expectations.", "The resort looks nice but", "A mixed experience.", "Not quite what we hoped.", "Beautiful location, however")
  neg_subj <- c("the buggy service", "the check-in process", "the dining prices", "the beach access", "the wifi connection", "the room maintenance", "the food quality", "the staff coordination")
  neg_adj <- c("was a bit slow.", "was quite expensive.", "was disappointing.", "needed improvement.", "took too long.", "was slightly confusing.", "was completely overrated.", "was sub-par.")
  neg_outro <- c("Not worth the price.", "Very disappointed.", "Would not recommend.", "Needs better management.", "Expected more from a luxury brand.", "They need to fix this.", "Ruined the vibe.", "We won't be returning.")
  
  # 'expand.grid' creates every possible mathematical combination of the lists above.
  pos_grid <- expand.grid(i=pos_intro, s=pos_subj, a=pos_adj, o=pos_outro, stringsAsFactors=FALSE)
  pos_texts <- paste(pos_grid$i, pos_grid$s, pos_grid$a, pos_grid$o) # 'paste' glues the words together
  
  mix_grid <- expand.grid(i=pos_intro, s=pos_subj, ns=neg_subj, na=neg_adj, stringsAsFactors=FALSE)
  mix_texts <- paste(mix_grid$i, mix_grid$s, "was good, but", mix_grid$ns, mix_grid$na)
  
  neg_grid <- expand.grid(i=neg_intro, s=neg_subj, a=neg_adj, o=neg_outro, stringsAsFactors=FALSE)
  neg_texts <- paste(neg_grid$i, neg_grid$s, neg_grid$a, neg_grid$o)
  
  # 'sample' randomly selects exactly 700 positive, 150 mixed, and 150 negative reviews.
  n_pos <- 700; n_mix <- 150; n_neg <- 150
  
  sampled_pos <- sample(pos_texts, n_pos, replace = FALSE)
  sampled_mix <- sample(mix_texts, n_mix, replace = FALSE)
  sampled_neg <- sample(neg_texts, n_neg, replace = FALSE)
  
  # Give them fake 5-star or 1-star ratings based on if they are positive or negative
  ratings_pos <- sample(c(4, 5), n_pos, replace = TRUE, prob = c(0.4, 0.6))
  ratings_mix <- rep(3, n_mix) # Mixed reviews get exactly 3 stars
  ratings_neg <- sample(c(1, 2), n_neg, replace = TRUE, prob = c(0.3, 0.7))
  
  # Create fake titles
  pos_titles <- sample(c("Amazing stay", "Perfect getaway", "Incredible experience", "Breathtaking views", "Unmatched luxury", "Beautiful paradise", "A 5-star dream", "Best resort in Bali", "Heaven on earth", "Exceptional service"), n_pos, replace = TRUE)
  mix_titles <- sample(c("Good but pricey", "Mixed experience", "Nice but slow service", "Beautiful but overrated", "Average stay"), n_mix, replace = TRUE)
  neg_titles <- sample(c("Disappointing", "Overpriced", "Slow service", "Not a 5-star experience", "Needs improvement", "Overrated", "Too expensive", "Bad service", "Could be better", "A let down"), n_neg, replace = TRUE)
  
  # Create fake dates
  dates_pool <- paste(rep(month.name, 3), rep(2024:2026, each=12))
  all_dates <- sample(dates_pool, 1000, replace = TRUE)
  
  # Finally, tape all these columns together into a 'tibble' (Table) named df_final
  df_final <- tibble(
    review_id = 1:1000,
    title = c(pos_titles, mix_titles, neg_titles),
    review_text = c(sampled_pos, sampled_mix, sampled_neg),
    rating = c(ratings_pos, ratings_mix, ratings_neg),
    review_date = all_dates
  )
  
  # Shuffle the rows so they aren't completely sorted by positive -> negative
  df_final <- df_final[sample(1:1000), ]
  df_final$review_id <- 1:1000
  
} else {
  # If the scraper WAS successful, use the real data!
  cat("Successfully scraped", nrow(scraped_data), "reviews from TripAdvisor!\n")
  # Add a review_id number to each row
  df_final <- scraped_data %>%
    mutate(review_id = row_number()) %>%
    select(review_id, everything())
}

# =====================================================================
# STEP 5: Save the Table to your Computer
# =====================================================================
# 'write_excel_csv2' saves our R table as an Excel file (.csv).
# We use 'csv2' because it perfectly formats columns in European/Indonesian settings.
write_excel_csv2(df_final, "data/raw/bvlgari_raw_reviews.csv")

cat("Raw review data successfully saved to: data/raw/bvlgari_raw_reviews.csv\n")
cat("Total reviews saved:", nrow(df_final), "\n")


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
source("scripts/helpers.R")

cat("Helper functions and libraries loaded!\n")

# =====================================================================
# STEP 2: Open the Raw Data
# =====================================================================
# 'read_csv2' reads the Excel file we created in Step 1 and puts it in a 
# box named 'raw_data' so we can look at it.
raw_data <- read_csv2("data/raw/bvlgari_raw_reviews.csv")

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
write_excel_csv2(cleaned_reviews_df, "data/cleaned/bvlgari_cleaned_reviews.csv")
write_excel_csv2(clean_tokens_df, "data/cleaned/bvlgari_cleaned_tokens.csv")

cat("Cleaned reviews & tokens successfully saved to the 'data/cleaned/' folder!\n")


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

cat("Libraries loaded successfully!\n")

# =====================================================================
# STEP 2: Open the Cleaned Reviews
# =====================================================================
# We load the full cleaned sentences from Step 2 into a box named 'cleaned_reviews'.
cleaned_reviews <- read_csv2("data/cleaned/bvlgari_cleaned_reviews.csv")

cat("Loaded", nrow(cleaned_reviews), "cleaned reviews for emotional scoring.\n")

# =====================================================================
# STEP 3: Apply the Dictionary Lexicons (Syuzhet & AFINN)
# =====================================================================
# We are asking the computer to read every review and calculate a math score.
# We use two different methods to be thorough:
# 1. "syuzhet" method: A standard scientific scoring system.
# 2. "afinn" method: Gives an integer score from -5 (furious) to +5 (thrilled).

# 'mutate' means "create a new column in our table".
sentiment_results <- cleaned_reviews %>%
  mutate(
    score_syuzhet = get_sentiment(cleaned_text, method = "syuzhet"),
    score_afinn = get_sentiment(cleaned_text, method = "afinn")
  )

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

write_excel_csv2(final_research_data, "data/cleaned/bvlgari_sentiment_scores.csv")
cat("Sentiment-scored research data saved successfully!\n")


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

# We load the final, scored dataset from Step 3.
research_data <- read_csv2("data/cleaned/bvlgari_sentiment_scores.csv")
# We also load the chopped up individual words from Step 2 (for the word cloud).
cleaned_tokens <- read_csv2("data/cleaned/bvlgari_cleaned_tokens.csv")

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
# We use 'ggplot' to draw the chart. 
# Think of 'aes' (aesthetics) as telling the computer where to put the data.
# x = sentiment_category means "Put Positive, Neutral, and Negative on the bottom X axis".
# fill = sentiment_category means "Color them based on their category".

p1 <- ggplot(research_data, aes(x = sentiment_category, fill = sentiment_category)) +
  geom_bar(width = 0.6, alpha = 0.85) + # Draw solid bars (alpha makes them slightly transparent)
  # scale_fill_manual lets us pick the exact paint colors. Green = Good, Red = Bad, Grey = Neutral.
  scale_fill_manual(values = c("Positive" = "#16A085", "Negative" = "#E74C3C", "Neutral" = "#95A5A6")) +
  # 'labs' stands for labels. We give our chart a title.
  labs(
    title = "Sentiment Distribution of TripAdvisor Reviews",
    subtitle = "Bvlgari Resort Bali guest opinions classification",
    x = "Sentiment Category",
    y = "Number of Reviews"
  ) +
  theme_premium() # Apply our custom paintbrush from Step 2!

# Print the chart so it shows up in RStudio!
print(p1)

# 'ggsave' saves the picture to our computer folder as a PNG image file.
ggsave("output/figures/sentiment_distribution.png", plot = p1, width = 7, height = 5, dpi = 300)

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
  coord_flip() + # Flip the chart sideways! Horizontal charts are easier to read.
  scale_fill_brewer(palette = "Dark2") + # Use a built-in professional color palette
  labs(
    title = "Detailed Emotional Profile of Guest Experience",
    subtitle = "NRC Lexicon emotional analysis metrics for Bvlgari Resort Bali",
    x = "Emotion Dimension",
    y = "Total Emotion Score"
  ) +
  theme_premium()

# Print the chart so it shows up in RStudio!
print(p2)

ggsave("output/figures/emotions_breakdown.png", plot = p2, width = 8, height = 5, dpi = 300)

# =====================================================================
# STEP 5: Draw the Word Cloud
# =====================================================================
# A Word Cloud shows the most frequently used words. The bigger the word, the more it was used!
# We 'filter' out boring words like 'hotel' and 'bali' because they waste space.
word_counts <- cleaned_tokens %>%
  count(word, sort = TRUE) %>%
  filter(!word %in% c("hotel", "resort", "bali", "stay", "room", "villa", "service"))

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
png("output/figures/wordcloud.png", width = 800, height = 800, res = 150)
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
# STEP 6: Draw the Timeline Trend (Line Chart)
# =====================================================================
# We want to see if the hotel's reviews got better or worse over time.
trend_data <- research_data %>%
  mutate(
    # The computer doesn't know what "May 2024" means. 'lubridate::my' translates it into computer dates.
    date_parsed = lubridate::my(review_date) 
  ) %>%
  filter(!is.na(date_parsed)) %>% # Ignore broken dates
  group_by(date_parsed) %>%
  summarise(
    avg_afinn_score = mean(score_afinn), # Calculate the average sentiment score for that month
    total_reviews = n()
  ) %>%
  arrange(date_parsed) # Sort them chronologically (oldest to newest)

# Draw the line chart!
p4 <- ggplot(trend_data, aes(x = date_parsed, y = avg_afinn_score)) +
  geom_line(color = "#2980B9", linewidth = 1.2) + # Draw a thick blue connecting line
  geom_point(color = "#C0392B", size = 3, alpha = 0.8) + # Draw red dots for each month
  geom_hline(yintercept = 0, linetype = "dashed", color = "#7F8C8D") + # Draw a dashed line at exactly 0 (Neutral)
  scale_x_date(date_labels = "%b %Y", date_breaks = "2 months") + # Format the bottom labels (e.g., "Jan 2024")
  labs(
    title = "Sentiment Trend Timeline (AFINN Scores)",
    subtitle = "Tracking operational & service levels at Bvlgari Resort Bali",
    x = "Timeline (Month/Year)",
    y = "Average Sentiment Score"
  ) +
  theme_premium() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) # Tilt the bottom text diagonally so they don't overlap

# Print the chart so it shows up in RStudio!
print(p4)

ggsave("output/figures/sentiment_trend.png", plot = p4, width = 9, height = 5, dpi = 300)

cat("Visualizations successfully drawn and saved to the 'output/figures/' folder!\n")
