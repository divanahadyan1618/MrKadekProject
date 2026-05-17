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
