# TripAdvisor Sentiment Analysis for Hospitality & Tourism Research

Welcome to the **TripAdvisor Sentiment Analysis** research environment. This workspace is specifically designed for hospitality and tourism students and researchers to analyze tourist experiences, compliments, operational bottlenecks, and service quality using Big Data and Artificial Intelligence (AI).

This project uses **R** in a **Jupyter Notebook** environment, with optional collaboration from **ChatGPT** as a coding and troubleshooting partner.

---

## 📌 Project Overview

Traditional hospitality research relies heavily on numeric satisfaction scores or star ratings. However, numbers don't tell the whole story. A 5-star hotel can still have complaints about cleanliness or waiting times. 

By analyzing **Electronic Word of Mouth (e-WOM)**—the text reviews left by guests—we can unlock authentic, real-time, and massive-scale consumer insights. This project demonstrates how to collect, clean, analyze, and visualize reviews from the **Bvlgari Resort Bali**, a luxury resort, to extract actionable business intelligence.

---

## 📂 Directory Structure

This workspace is organized as follows:

```text
KADEK AWIKWOK/
├── README.md                     # This file (Project Overview)
├── 01_data_import.ipynb          # Notebook 1: Import prepared review CSV
├── 02_cleaning.ipynb             # Notebook 2: Text Preprocessing & Cleaning
├── 03_sentiment_analysis.ipynb   # Notebook 3: Sentiment Scoring (AFINN, NRC, Syuzhet)
├── 04_visualization.ipynb        # Notebook 4: Charts, Graphs, & Word Clouds
├── 05_aspect_text_analysis.R     # Step 5: Aspect ratings linked to review text
├── data/
│   ├── raw/                      # Raw prepared TripAdvisor review CSV
│   └── cleaned/                  # Preprocessed and tokenized text data
├── output/
│   ├── figures/                  # Saved charts, graphs, and word clouds (PNG/PDF)
│   └── reports/                  # Generated research summaries
└── scripts/
    └── helpers.R                 # Reusable helper functions for text cleaning
```

---

## 🛠️ The 5-Step Research Workflow

### Step 1: Import Review CSV (`01_data_import.ipynb`)
Load the prepared TripAdvisor review CSV for **Bvlgari Resort Bali**. The raw CSV includes:
* Review texts
* Rating scores (1-5 stars)
* Review dates
* Stay dates and trip types
* Non-identifying reviewer context such as contribution counts and trip type

### Step 2: Data Cleaning & Preprocessing (`02_cleaning.ipynb`)
Raw reviews are noisy. We clean the text by:
* Converting to lowercase
* Removing HTML tags, punctuation, emojis, and special characters
* Eliminating common English stopwords (e.g., "the", "was", "and")
* Normalizing slang words

### Step 3: Sentiment Analysis & Scoring (`03_sentiment_analysis.ipynb`)
Apply lexicographical models to identify the emotional sentiment of words:
* **AFINN Lexicon**: Scores words on an integer scale from -5 (negative) to +5 (positive).
* **Syuzhet/NRC Lexicon**: Classifies text into emotions (joy, trust, anger, fear, anticipation, etc.) and positive/negative categories.

### Step 4: Data Visualization & Insights (`04_visualization.ipynb`)
Convert numbers and scores into high-impact visuals:
* **Sentiment Distribution**: Count how many reviews are positive, neutral, or negative.
* **Rating vs. Sentiment Boxplot**: Group reviews by 1-star to 5-star TripAdvisor rating and compare the written text sentiment inside each rating group. The dashed line shows the hotel's average TripAdvisor rating, and the diamonds show average text sentiment per rating group.
* **Aspect Rating Diagnostics**: Compare value, rooms, location, cleanliness, service, and sleep quality using average ratings, low-score shares, and yearly heatmaps.
* **Emotion Breakdown**: Compare emotion categories such as joy, trust, anger, fear, and sadness.
* **Sentiment Word Cloud**: Instantly spot the most repeated AFINN-scored sentiment words. Neutral topic words are intentionally excluded, so the cloud focuses on words such as "beautiful", "friendly", "excellent", or "bad".
* **Monthly Sentiment Heatmap**: Read the calendar pattern quickly. Each tile is one month in one year, colored by average AFINN sentiment per 100 cleaned words and labeled with the number of reviews.
* **Monthly Rolling Trend**: Follow the sentiment trend over time. The blue line smooths length-normalized monthly sentiment using a 6-month rolling average, and the dotted line compares each month to the average of all earlier reviews.
* **Quarterly Boxplot**: Summarize review sentiment spread for each quarter. This is less noisy than monthly boxplots because each quarter usually has more reviews.
* **Yearly Boxplot with Statistics**: Summarize each year's sentiment distribution with `n`, average, median, quartiles, minimum, maximum, and outlier count printed below the chart.

### Step 5: Aspect-Text Diagnostics (`05_aspect_text_analysis.R`)
Connect structured aspect ratings to the written reviews:
* **Aspect-Conditioned Text Mining**: Compare words and phrases in low aspect reviews (`1-3`) against high aspect reviews (`4-5`).
* **Aspect-Specific Sentiment**: Summarize length-normalized text sentiment, negative-text share, and emotion counts by aspect.
* **Aspect-Text Mismatch Review Table**: Identify cases such as high overall ratings with low aspect ratings, or high aspect ratings with negative text.
* **Key-Term Tables by Aspect**: Save low-score-associated words and phrases for value, rooms, location, cleanliness, service, and sleep quality.
* **Aspect-Text Visualizations**: Generate boxplots, word and phrase charts, a negative-term heatmap, and mismatch count charts for qualitative interpretation.

---

## ☁️ Run in Google Colab (No Local Installation Required!)

You can run this entire project in your browser using Google Colab in a single, unified workspace. The master notebook contains the full workflow from data import through visualization and aspect-text diagnostics. Run the setup cell first; it installs the required R packages inside the temporary Colab session. Then upload `reviews.csv` into the Colab file browser, or place the same file at `data/raw/reviews.csv`, before running Step 1.

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/divanahadyan1618/MrKadekProject/blob/master/Colab_Master_TripAdvisor.ipynb) **Open the Master Research Notebook**

---

## 🚀 How to Run Locally

1. **Install R packages once**:
   The dated CRAN snapshot keeps package versions stable when the project is rerun.
   ```r
   cran_snapshot_url <- "https://packagemanager.posit.co/cran/2026-05-26"
   install.packages(c("tidyverse", "tidytext", "syuzhet", "wordcloud", "RColorBrewer", "lubridate", "IRkernel"), repos = cran_snapshot_url)
   IRkernel::installspec(user = TRUE)
   ```
2. **Start Jupyter Notebook**:
   Open a terminal (e.g., PowerShell or Command Prompt) in this directory and run:
   ```bash
   jupyter notebook
   ```
3. **Open in Browser**:
   Your browser will automatically open to the Jupyter dashboard.
4. **Execute Steps Sequentially**:
   Start with `01_data_import.ipynb` and proceed through `04_visualization.ipynb`. Step 5 is an R script, so run `Rscript 05_aspect_text_analysis.R` from the terminal after Steps 1-4, or run `Rscript Master_TripAdvisor.R` to execute the full workflow in order.

---

## 🤖 Partnering with ChatGPT

As highlighted in the presentation, ChatGPT can act as your:
1. **Coding Assistant**: Ask for explanations of R functions or packages.
2. **Troubleshooter**: Copy-paste R errors and ask ChatGPT for a fix.
3. **Analytical Brainstormer**: Share sentiment trends and ask ChatGPT to suggest operational improvements for the hotel management.

*Tip: Always use clear and specific prompts for best results!*
