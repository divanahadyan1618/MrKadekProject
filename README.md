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
├── 01_scraping.ipynb             # Notebook 1: Web Scraping TripAdvisor Reviews
├── 02_cleaning.ipynb             # Notebook 2: Text Preprocessing & Cleaning
├── 03_sentiment_analysis.ipynb   # Notebook 3: Sentiment Scoring (AFINN, NRC, Syuzhet)
├── 04_visualization.ipynb        # Notebook 4: Charts, Graphs, & Word Clouds
├── data/
│   ├── raw/                      # Raw scraped reviews (CSV format)
│   └── cleaned/                  # Preprocessed and tokenized text data
├── output/
│   ├── figures/                  # Saved charts, graphs, and word clouds (PNG/PDF)
│   └── reports/                  # Generated research summaries
└── scripts/
    └── helpers.R                 # Reusable helper functions for text cleaning
```

---

## 🛠️ The 4-Step Research Workflow

### Step 1: Web Scraping (`01_scraping.ipynb`)
Extract reviews dynamically from TripAdvisor. For this project, we target the prestigious **Bvlgari Resort Bali**. We collect:
* Review texts
* Rating scores (1-5 stars)
* Review dates
* User contributions (optional)

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
* **Word Clouds**: Instantly spot dominant topics (e.g., "authentic", "friendly" vs. "queue", "expensive").
* **Sentiment Over Time**: See how guest satisfaction changes during peak season vs. off-peak season.
* **Rating vs. Sentiment Divergence**: Discover cases where high ratings co-exist with negative remarks.

---

## ☁️ Run in Google Colab (No Installation Required!)

You can run these notebooks directly in your browser using Google Colab. The notebooks are pre-configured to download the dataset automatically.

- [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/divanahadyan1618/MrKadekProject/blob/master/01_scraping.ipynb) **Notebook 1: Web Scraping TripAdvisor Reviews**
- [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/divanahadyan1618/MrKadekProject/blob/master/02_cleaning.ipynb) **Notebook 2: Text Preprocessing & Cleaning**
- [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/divanahadyan1618/MrKadekProject/blob/master/03_sentiment_analysis.ipynb) **Notebook 3: Sentiment Scoring**
- [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/divanahadyan1618/MrKadekProject/blob/master/04_visualization.ipynb) **Notebook 4: Data Visualization & Insights**

---

## 🚀 How to Run Locally

1. **Start Jupyter Notebook**:
   Open a terminal (e.g., PowerShell or Command Prompt) in this directory and run:
   ```bash
   jupyter notebook
   ```
2. **Open in Browser**:
   Your browser will automatically open to the Jupyter dashboard.
3. **Execute Steps Sequentially**:
   Start with `01_scraping.ipynb` and proceed in order (01 ➔ 02 ➔ 03 ➔ 04). Each notebook contains clear explanations and R code blocks that can be executed cell-by-cell.

---

## 🤖 Partnering with ChatGPT

As highlighted in the presentation, ChatGPT can act as your:
1. **Coding Assistant**: Ask for explanations of R functions or packages.
2. **Troubleshooter**: Copy-paste R errors and ask ChatGPT for a fix.
3. **Analytical Brainstormer**: Share sentiment trends and ask ChatGPT to suggest operational improvements for the hotel management.

*Tip: Always use clear and specific prompts for best results!*
