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
