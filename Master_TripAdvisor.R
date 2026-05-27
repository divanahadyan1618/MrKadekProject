# =====================================================================
# MASTER R SCRIPT: TripAdvisor Sentiment Analysis Workflow
# =====================================================================
# Run the full workflow in order:
# 1. Validate and import the prepared review CSV.
# 2. Clean and tokenize review text.
# 3. Score review sentiment and emotions.
# 4. Generate visualizations.
# 5. Link aspect ratings to review text for diagnostic interpretation.

source("01_data_import.R")
source("02_cleaning.R")
source("03_sentiment_analysis.R")
source("04_visualization.R")
source("05_aspect_text_analysis.R")
