# Methodological Framework for TripAdvisor Sentiment Analysis of Bvlgari Resort Bali and Future Decision-Support Extensions

## Abstract

This methodology paper specifies a reproducible analytical framework for transforming online hotel reviews into structured sentiment evidence. The project uses a prepared TripAdvisor review corpus for Bvlgari Resort Bali and implements a staged R workflow for data validation, text preprocessing, lexicon-based sentiment scoring, emotion extraction, and temporal visualization. The methodological design follows a single-case digital trace research strategy: one luxury resort is treated as a bounded case, while reviews are treated as naturally occurring electronic word-of-mouth records of guest experience. The final analytical dataset contains 762 TripAdvisor reviews from October 2006 to May 2026, including star ratings, review dates, stay dates, reviewer metadata, optional aspect ratings, cleaned review text, negation-adjusted Syuzhet sentiment scores, negation-adjusted AFINN sentiment scores, and NRC emotion scores.

The implemented framework supports academic analysis of the relationship between numerical ratings, textual sentiment, emotion categories, service-quality dimensions, and time-based review patterns. It now also produces statistical period-monitoring outputs that compare review periods with prior history using length-normalized sentiment, medians, trimmed means, and robust median absolute deviation indicators. A management and investment decision layer is not currently implemented in the project code; it is presented as a future development path that would build on the existing analytical outputs.

The paper also defines the study's limitations. Lexicon-based sentiment scoring is transparent and replicable, but it can misread sarcasm, complex negation, multilingual expressions, cultural context, and domain-specific meanings. TripAdvisor reviews are not a statistically representative sample of all guests, and observed sentiment is mediated by platform behavior, reviewer motivation, review timing, and unobserved operational conditions. For these reasons, the implemented methodology emphasizes triangulation across ratings, sentiment scores, aspect ratings, review text, and temporal patterns before any future management or investment conclusions are drawn.

Keywords: TripAdvisor, sentiment analysis, hotel reviews, luxury resort, Bvlgari Resort Bali, electronic word of mouth, AFINN, Syuzhet, NRC Emotion Lexicon, service quality, temporal analysis, future decision support.

## 1. Introduction

Online reviews have become a major source of evidence for tourism and hospitality research because they record guest evaluations in a natural digital setting. In luxury hospitality, reviews are especially valuable because guest satisfaction is shaped not only by functional quality but also by emotional experience, perceived exclusivity, value, personalization, aesthetics, privacy, and service recovery. A five-star property may maintain a high average rating while still accumulating text-based signs of dissatisfaction about value, maintenance, dining, staff coordination, or expectation mismatch. Conversely, a guest may give a modest numerical rating while writing positively about specific aspects of the experience. For this reason, rating-only analysis is methodologically incomplete.

This project develops a sentiment-analysis methodology for Bvlgari Resort Bali using TripAdvisor review data. The implemented objective is not merely to classify reviews as positive or negative; it is to create a transparent analytical corpus that can support rating-sentiment comparison, emotion profiling, and temporal interpretation. The methodology is inspired by tourism sentiment studies that combine digital review corpora, text cleaning, lexicon-based scoring, temporal interpretation, and qualitative contextualization. The attached reference paper on informal language and cultural appreciation in TripAdvisor reviews of Balinese Ayam Betutu demonstrates a rigorous academic pattern that is also relevant here: define a bounded tourism object, analyze all accessible reviews in the selected corpus, preprocess text transparently, apply lexicon-based sentiment methods, visualize temporal patterns, interpret discrepancies between ratings and text, and state limitations clearly.

The present methodology extends that type of approach to a luxury-hotel case. The current codebase produces cleaned data, scored sentiment outputs, and visual trend artifacts. A further decision-support layer is proposed as future work: rather than stopping at descriptive sentiment results, a future version could formalize what should happen when the rating or sentiment of reviews drifts away from a baseline over a number of periods. That future extension would require baseline definition, period aggregation, drift thresholds, confidence rules, and action pathways that are not yet coded in the repository.

## 2. Research Purpose and Methodological Objectives

The purpose of the study is to design and document a reproducible methodology for analyzing TripAdvisor reviews of Bvlgari Resort Bali. The implemented workflow produces research-ready sentiment, emotion, rating, and visualization outputs. Operational and investment decision rules are discussed only as future extensions that could be built on top of these outputs.

The methodological objectives are:

1. To validate and standardize a prepared TripAdvisor review dataset for a single luxury hotel case.
2. To preprocess guest review text into a clean corpus suitable for tokenization and lexicon-based sentiment analysis.
3. To score review narratives using multiple lexicon-based methods, including Syuzhet, AFINN, and the NRC emotion categories.
4. To compare textual sentiment with TripAdvisor star ratings and optional aspect ratings.
5. To visualize sentiment distribution, rating-sentiment alignment, emotion profiles, word-level sentiment terms, and time-based sentiment trends.
6. To identify how the implemented outputs could support a future early-warning framework for detecting rating and sentiment drift across periods.
7. To outline, as future work, how persistent drift patterns could be mapped to management and investment decision categories.

The methodology is therefore primarily analytical. It explains how the data are processed and how the resulting indicators should be interpreted responsibly. Prescriptive management and investment rules are treated as a recommended extension, not as a feature currently implemented in the R workflow.

## 3. Research Design

### 3.1 Digital Trace Single-Case Study

The study uses a single-case digital trace design. Bvlgari Resort Bali is treated as the focal case, and TripAdvisor reviews are treated as digital traces of guest experience. A single-case design is appropriate because luxury resorts are highly context-dependent: the brand promise, location, villa format, service model, butler experience, food and beverage offer, price point, and guest expectations are all specific to the property. A multi-hotel design would support broader generalization, but it would weaken the property-specific interpretation needed for any later decision-support extension.

### 3.2 Mixed Quantitative and Qualitative Logic

The project combines quantitative and qualitative logic. The quantitative component includes star ratings, aspect ratings, sentiment scores, emotion counts, review counts, period averages, medians, and trend indicators. The qualitative component remains embedded in the review text: low-scoring periods, outlier reviews, and divergent rating-sentiment cases must be interpreted by reading the guest narratives. This mixed logic is important because sentiment scores can identify where to look, but the actual operational cause is usually found in the text.

### 3.3 Reproducible Computational Workflow

The workflow is implemented in R through separate scripts:

| Script | Methodological role |
|---|---|
| `01_data_import.R` | Validates that the prepared raw review CSV exists and contains required fields. |
| `02_cleaning.R` | Loads the raw data, standardizes columns, cleans text, tokenizes reviews, removes stopwords, and saves cleaned outputs. |
| `03_sentiment_analysis.R` | Scores cleaned text using Syuzhet and AFINN, classifies review sentiment, extracts NRC emotion categories, and saves the scored dataset. |
| `04_visualization.R` | Produces sentiment distribution, rating-sentiment, emotion, word cloud, and temporal trend visualizations. |
| `05_aspect_text_analysis.R` | Links structured aspect ratings to review text by comparing low-aspect and high-aspect reviews, producing key-term tables, mismatch tables, qualitative examples, and aspect-text visualizations. |
| `scripts/data_config.R` | Centralizes file paths for raw data, cleaned data, sentiment scores, and figures. |
| `scripts/helpers.R` | Provides reusable helper functions for text cleaning, stopword removal, slang normalization, and source-column standardization. |

This modular design improves transparency because each methodological stage can be inspected, rerun, and modified independently.

## 4. Case Selection

Bvlgari Resort Bali is selected as a luxury-hotel case because its market position depends heavily on intangible experience attributes: exclusivity, privacy, aesthetics, personalized service, food and beverage quality, spa and leisure amenities, room and villa quality, and perceived value. These dimensions are well suited to review-based analysis because guests often describe them in narrative form.

The single-property focus also supports future management relevance. A general hotel sentiment model can describe broad industry patterns, but managers need property-specific evidence. For example, an observed decline in sentiment could imply different follow-up questions depending on whether the associated text concerns butler service, dining price, villa maintenance, cleanliness, privacy, buggy transport, beach access, or value perception. The current project surfaces these analytical signals; it does not yet automate managerial recommendations.

## 5. Data Source and Corpus Construction

### 5.1 Raw Dataset

The project uses a prepared TripAdvisor review CSV located at `data/raw/reviews.csv`. The import script validates that the file exists and contains required columns:

- `review_id`
- `hotel_name`
- `title`
- `review_text`
- `rating`
- `review_date`
- `stay_date`
- `trip_type`

The current raw dataset contains 762 rows and 19 source columns after removing direct reviewer identifiers. All rows are associated with Bvlgari Resort Bali and have non-empty review text. The final sentiment-scored dataset contains 762 rows and 33 columns.

### 5.2 Temporal Coverage

The review-date range in the current dataset is October 2006 to May 18, 2026. The stay-date range is September 2006 to May 2026. This long time span enables longitudinal analysis, but it also creates methodological challenges. TripAdvisor platform design, guest demographics, hotel operations, travel patterns, and global tourism conditions changed substantially over this period. Therefore, long-term trend interpretation must consider context and should not treat all periods as directly comparable.

### 5.3 Data Fields

The raw corpus includes both narrative and structured fields:

| Field group | Examples | Methodological use |
|---|---|---|
| Identification | `review_id`, `hotel_name`, `source` | Traceability and data validation. |
| Review content | `title`, `review_text` | Text cleaning, tokenization, sentiment analysis, qualitative interpretation. |
| Rating fields | `rating`, `value_rating`, `rooms_rating`, `location_rating`, `cleanliness_rating`, `service_rating`, `sleep_quality_rating` | Rating-sentiment comparison and aspect-level diagnosis. |
| Time fields | `review_date`, `review_date_raw`, `stay_date` | Monthly, quarterly, yearly, and rolling trend analysis. |
| Reviewer context | `reviewer_contributions`, `trip_type` | Optional segmentation and bias assessment without direct reviewer identifiers. |
| Operational hints | `insider_tip`, `page_offset` | Supplementary context and data provenance. |

Direct reviewer identifiers, including bare `author` or `reviewer` fields, are removed from the tracked analysis datasets because they are not required for the implemented aggregate analysis. Academic and managerial outputs should aggregate reviewer-level information unless explicit permission exists.

### 5.4 Corpus Summary

The current scored dataset has the following descriptive structure:

| Metric | Value |
|---|---:|
| Total reviews | 762 |
| Hotel name | Bvlgari Resort Bali |
| Review-date range | 2006-10-01 to 2026-05-18 |
| Stay-date range | 2006-09-01 to 2026-05-01 |
| Mean star rating | 4.56 |
| Median star rating | 5.00 |
| 5-star reviews | 596 |
| 4-star reviews | 77 |
| 3-star reviews | 38 |
| 2-star reviews | 22 |
| 1-star reviews | 29 |
| Positive sentiment labels | 733 |
| Neutral sentiment labels | 2 |
| Negative sentiment labels | 27 |
| Mean AFINN score | 21.13 |
| Median AFINN score | 17.00 |
| Mean Syuzhet score | 8.60 |
| Median Syuzhet score | 6.62 |

These figures show a strongly positive and high-rating corpus. This high skew is typical of many luxury-hotel review datasets and makes methodological caution necessary. Mean values alone can hide deterioration in a small but important subset of reviews. Therefore, the current monitoring outputs include median and robust summaries, while future decision-support work should add richer low-rating share, negative-share, and aspect-specific trigger logic.

### 5.5 Structured Aspect Rating Availability

The dataset also includes structured aspect ratings for value, rooms, location, cleanliness, service, and sleep quality. These fields are not merely supplementary metadata. They provide a middle layer between the overall star rating and the open-ended review text. Overall ratings indicate broad satisfaction, while aspect ratings show which part of the guest experience may be driving satisfaction or dissatisfaction.

Coverage varies by aspect because not every reviewer supplies every structured rating. Therefore, aspect analysis must report the number of available ratings before interpreting any aspect-level score:

| Aspect | Rated reviews | Coverage |
|---|---:|---:|
| Value | 339 | 44.5% |
| Rooms | 322 | 42.3% |
| Location | 337 | 44.2% |
| Cleanliness | 327 | 42.9% |
| Service | 440 | 57.7% |
| Sleep quality | 272 | 35.7% |

Substantive aspect findings are presented later in the analytical sequence, after the paper explains rating-sentiment alignment. This ordering prevents the corpus description section from drawing operational conclusions before the relevant method has been introduced.

## 6. Data Validation and Standardization

The first methodological stage is validation. `01_data_import.R` checks that the prepared CSV exists, has non-zero file size, includes required columns, contains rows with review text, identifies Bvlgari Resort Bali as the only analyzed property, and omits direct reviewer identifiers, forbidden source metadata, TripAdvisor source-disclosure text in trip type values, and embedded contact markers from any raw column. This step prevents downstream scripts from silently analyzing an incomplete, malformed, mixed-property, or privacy-inappropriate file.

The second stage is schema standardization. The helper function `standardize_hotel_reviews()` maps source-specific column names into a consistent internal structure:

- `review_id`
- `hotel_name`
- `title`
- `review_text`
- `rating`
- `review_date`

The function also preserves additional source fields, including aspect ratings and non-identifying reviewer context such as contribution counts. Direct reviewer identifiers and source-response metadata are excluded. This design is important for reproducibility because review exports may differ in column naming. A standardized schema allows the cleaning, scoring, and visualization scripts to remain stable even if the raw export format changes.

## 7. Text Preprocessing

### 7.1 Cleaning

Text preprocessing is implemented in `scripts/helpers.R` through the `clean_text()` function. The cleaning process:

1. Converts text to lowercase.
2. Removes HTML tags.
3. Removes loose angle brackets, URLs, and web handles.
4. Transliterates accented letters and Unicode punctuation to ASCII where possible.
5. Replaces remaining non-ASCII characters and emojis with spaces so neighboring words do not get joined together.
6. Removes punctuation and special symbols.
7. Removes digits.
8. Squishes repeated whitespace.

This procedure produces a simplified textual representation suitable for lexicon matching. The main advantage is transparency: the rule set is explicit and reproducible. The main disadvantage is loss of some linguistic nuance. For example, punctuation, capitalization, emojis, and non-English characters may carry sentiment information. This loss is acceptable for a first-stage lexicon workflow, but it should be acknowledged as a limitation.

### 7.2 Slang Normalization

The `normalize_slang()` function applies a small dictionary of common informal expressions, such as mapping elongated or abbreviated forms to standard English forms. Examples include:

- `sooo` to `so`
- `gooo+d` to `good`
- `looo+ve` to `love`
- `pls` to `please`
- `vry` to `very`

This step recognizes that TripAdvisor reviews often include informal language. However, the current dictionary is intentionally conservative. Expanding it should be done carefully and documented because aggressive normalization can erase culturally meaningful expressions.

The helper also standardizes straight and smart apostrophe contractions before sentiment scoring. This matters because expressions such as "don't recommend" or "didn't like" must be converted to explicit negation forms before punctuation and Unicode cleanup, otherwise the negation can be lost and positive words such as "recommend" can be scored incorrectly. Unicode punctuation is also treated as a word boundary rather than deleted, which prevents joined tokens from distorting sentiment scores and aspect key-term reports.

### 7.3 Tokenization

The cleaned review text is tokenized using `tidytext::unnest_tokens()`, creating one row per word. Tokenization supports word-frequency analysis, stopword removal, word clouds, and sentiment-word filtering. The final token file contains 48,563 token rows after preprocessing.

### 7.4 Stopword Removal

Stopwords are removed using the `tidytext` stopword list. This reduces the influence of high-frequency function words such as "the", "and", and "is". Stopword removal is appropriate for word-frequency visualization but should not be used blindly for every NLP task. Some function words can matter for negation, modality, or phrase-level meaning. Because this project uses lexicon-based word matching, stopword removal is primarily used for token-level summaries rather than for preserving syntactic structure.

## 8. Sentiment and Emotion Scoring

### 8.1 Lexicon-Based Sentiment Rationale

The study uses lexicon-based sentiment analysis because it is transparent, replicable, and suitable for educational settings. A lexicon approach maps words to preassigned sentiment or emotion values. Unlike black-box machine-learning models, lexicon results can be inspected and explained to non-technical stakeholders. This transparency would also be useful if a future management or investment decision-support layer were added.

The limitation is that lexicons may not fully capture sarcasm, idioms, multilingual content, domain-specific meanings, complex negation, or context-dependent sentiment. For instance, a word that is negative in a political context may be neutral in a hotel context. The visualization script explicitly excludes some domain-neutral terms from sentiment word clouds when their lexicon meaning is inappropriate for hotel reviews.

### 8.2 Syuzhet Score

The Syuzhet score is calculated with the project's `score_negation_aware_sentiment()` helper using the Syuzhet lexicon. The helper scores each word, then reverses sentiment-bearing words that appear shortly after simple negators such as "not", "never", "without", and "cannot". This prevents phrases such as "cannot recommend" from being treated as positive only because "recommend" is a positive lexicon word. The resulting Syuzhet score provides a continuous sentiment estimate for each cleaned review. The project uses the Syuzhet score to classify reviews into:

- Positive: Syuzhet score greater than 0
- Negative: Syuzhet score less than 0
- Neutral: Syuzhet score equal to 0

This classification is simple and transparent, but it should not be overinterpreted. A very slightly positive score and a strongly positive score are both labeled positive, so the continuous score should be retained for analysis. In the aspect-text diagnostics, Syuzhet is also normalized to the dataset's median cleaned review length before aspect-level averaging so that longer reviews do not automatically receive larger aspect sentiment means.

### 8.3 AFINN Score

The AFINN score is calculated with the same `score_negation_aware_sentiment()` helper using the AFINN lexicon. AFINN assigns integer valence values to sentiment-bearing words and sums them across text after the simple negation adjustment. In this project, AFINN is especially useful for:

- Rating-sentiment boxplots.
- Monthly, quarterly, and yearly trend charts, after normalizing AFINN to the median cleaned review length.
- Rolling sentiment averages, using the same length-normalized trend score.
- Prior-period comparisons, using the same length-normalized trend score.
- Aspect-text alignment diagnostics, using the same length-normalized score when comparing low and high aspect ratings.

Summed AFINN scores are sensitive to review length because longer reviews contain more sentiment words. This is not inherently wrong, because longer reviews may express more total evaluative content, but it should be considered when comparing short and long reviews. For that reason, the temporal charts calculate AFINN scaled to the dataset's median cleaned review length before averaging monthly, quarterly, and yearly periods, and the aspect-text diagnostics use the same median-length normalization for AFINN and Syuzhet aspect-level summaries. In the current corpus, the median cleaned review length is 112 words.

### 8.4 NRC Emotion Scores

The NRC emotion extraction is performed using `get_nrc_sentiment()`. It produces counts for the following emotion dimensions:

- anger
- anticipation
- disgust
- fear
- joy
- sadness
- surprise
- trust

It also produces positive and negative word counts. Emotion categories are useful for future operational interpretation because they distinguish different types of dissatisfaction. For example, anger may indicate service failure or perceived unfairness, disgust may indicate cleanliness or food-quality issues, fear may indicate safety or uncertainty, and sadness may indicate disappointment relative to expectations. These interpretations should be verified through the text rather than inferred from emotion labels alone.

## 9. Rating-Sentiment Alignment

The methodology compares star ratings with textual sentiment because ratings and review narratives capture related but different constructs. Ratings are compressed numerical judgments. Text contains explanations, contradictions, and nuance.

The project produces a rating-sentiment boxplot that groups AFINN scores by TripAdvisor star rating. This supports three analytical checks:

1. Convergent validity: higher star ratings should generally align with higher text sentiment.
2. Divergence detection: high ratings with low sentiment may indicate polite rating behavior or mixed experiences.
3. Severity detection: low ratings with strongly negative text may indicate service failures requiring deeper qualitative review.

For future management interpretation, rating-sentiment divergence may be more useful than average sentiment. A five-star review that contains negative comments about dining, value, or room maintenance could serve as an early warning before the numerical rating declines. The current project visualizes this relationship but does not yet implement automated warning logic.

## 10. Aspect-Rating Analysis

The corpus includes optional aspect ratings for value, rooms, location, cleanliness, service, and sleep quality. These aspect ratings provide a bridge between unstructured text and operational departments.

The implemented visualization workflow now treats aspect ratings as part of the core analysis rather than as a future extension. It generates an aspect summary table, a low-score table, a yearly aspect-rating heatmap, and a list of reviews where the overall rating is high but at least one aspect rating is low.

Aspect ratings should be interpreted with two statistics rather than one. The mean indicates the central tendency, while the low-score share indicates the proportion of guests who rated that aspect from 1 to 3 stars. Low-score share is important because a luxury property can maintain a high average while still accumulating a meaningful minority of weak aspect evaluations.

| Aspect | Valid ratings | Coverage | Mean | Median | Low-score share, 1-3 |
|---|---:|---:|---:|---:|---:|
| Value | 339 | 44.5% | 4.06 | 4.00 | 25.1% |
| Rooms | 322 | 42.3% | 4.52 | 5.00 | 12.4% |
| Location | 337 | 44.2% | 4.56 | 5.00 | 11.3% |
| Cleanliness | 327 | 42.9% | 4.57 | 5.00 | 10.7% |
| Service | 440 | 57.7% | 4.67 | 5.00 | 7.7% |
| Sleep quality | 272 | 35.7% | 4.55 | 5.00 | 10.7% |

In this dataset, value is the weakest structured dimension: it has the lowest mean rating and the highest low-score share. Methodologically, this does not automatically imply a pricing problem, but it does identify value perception as an important diagnostic area for qualitative review. Service is the strongest structured dimension, with the highest mean and the lowest low-score share.

The project also generates a review-level table for cases where the overall rating is high, but at least one aspect rating is low. In the current corpus, 60 reviews have an overall rating of 4 or 5 while reporting at least one aspect score of 3 or lower. These reviews are analytically important because they show mostly satisfied guests who still signaled specific weaknesses. For example, a five-star review with a low value score may reflect admiration for the property but hesitation about price fairness, inclusions, or expectation setting.

For future management interpretation, aspect ratings should be mapped to likely operational domains:

| Aspect signal | Likely diagnostic domain |
|---|---|
| Value weakness | Price fairness, inclusions, package design, communication of luxury value. |
| Rooms weakness | Villa condition, lighting, bedding, maintenance, renovation priority. |
| Cleanliness weakness | Housekeeping quality assurance and inspection process. |
| Service weakness | Staffing, training, responsiveness, personalization, service recovery. |
| Sleep-quality weakness | Noise, bedding, room environment, privacy, night operations. |
| Location weakness | Transportation, accessibility, arrival experience, expectation setting. |

This mapping is interpretive rather than causal. Any future action should be grounded in the review text and, where possible, triangulated with operational records.

The current workflow now implements that linkage in `05_aspect_text_analysis.R`. The script treats aspect ratings as weak review-level labels and compares the text of low-aspect reviews against high-aspect reviews. This produces five additional evidence types:

1. Aspect-conditioned word and phrase tables that show terms appearing unusually often in low-scoring aspect reviews.
2. Aspect-specific sentiment summaries that compare text sentiment, negative-text share, and emotion counts by structured aspect.
3. Aspect-text mismatch tables for cases such as high overall ratings with low aspect ratings, or high aspect ratings with negative text.
4. Qualitative review examples that support manual reading of low-aspect cases.
5. Visualizations including aspect sentiment boxplots, low-score word and phrase charts, a negative-term heatmap, and mismatch count charts.

The interpretation remains cautious. Aspect ratings apply to whole reviews, not individual sentences. Therefore, a word associated with low service ratings should be described as service-associated text, not as definitive evidence that the word refers only to service. This distinction is important for academic validity and for responsible managerial use.

## 11. Temporal Analysis

### 11.1 Date Parsing

The visualization script includes a `parse_review_dates()` helper that attempts several common date formats:

- year-month-day
- month-day-year
- day-month-year
- month-year

This is necessary because review datasets often contain inconsistent date formats. Reviews with unparseable dates are excluded from time-series visualization but retained in the scored dataset.

### 11.2 Monthly, Quarterly, and Yearly Aggregation

The methodology uses multiple period lengths because each answers a different question:

| Period | Purpose |
|---|---|
| Monthly | Detect short-term changes and seasonal signals. |
| Quarterly | Reduce monthly noise and support operational review cycles. |
| Yearly | Summarize long-run distribution and structural change. |

The project generates:

- Monthly sentiment heatmap.
- Monthly rolling sentiment trend.
- Quarterly sentiment distribution.
- Yearly sentiment distribution.

### 11.3 Rolling Average and Prior Average

The monthly rolling chart uses a six-month rolling average. This smooths noisy month-level changes, especially when some months have few reviews. The script also computes a prior average, defined as the average sentiment before the current period. This avoids comparing a period to a future-informed all-time average. If decision-support functionality is later implemented, prior baselines would be more realistic because managers only know past performance at the time a decision is made.

## 12. Statistical Drift Monitoring and Future Decision Support

### 12.1 Rationale

The current project now implements statistical drift-monitoring outputs, but it does not implement management recommendations or investment recommendations. This distinction matters. The code can show when a period looks unusual relative to prior review history, but it does not decide what the hotel should do. Operational action still requires qualitative reading, business context, and managerial judgment.

In operational terms, the future decision-support question remains:

If the rating or sentiment of reviews drifts away from the mean, median, or historical baseline over a specified number of periods, what should management do?

The current implementation answers the narrower methodological question: which periods deserve closer inspection because their sentiment or rating distribution is unusually low compared with earlier reviews?

### 12.2 Implemented Period Monitoring Metrics

The visualization script writes `output/reports/sentiment_period_summary.csv`. For each month, quarter, and year, it reports:

- Mean star rating.
- Median star rating.
- Trimmed mean star rating.
- Mean, median, and trimmed mean AFINN sentiment on the raw summed scale.
- Mean, median, and trimmed mean AFINN sentiment after scaling each review to the dataset's median cleaned review length.
- Mean, median, and trimmed mean Syuzhet sentiment on both the raw and median-length-normalized scales.
- Percentage of reviews rated 1 to 3.
- Percentage of reviews with negative median-length-normalized AFINN sentiment.
- Review count for the period.
- Historical median and historical MAD for prior-period AFINN and rating baselines.
- Robust z-score fields for median sentiment and median rating.
- Statistical drift flags for unusually low sentiment or rating periods.

The review count is treated as a required confidence input. A period with two reviews should not be interpreted the same way as a period with fifty reviews unless the content indicates a severe risk.

### 12.3 Baseline Definitions

The implemented baseline is a prior cumulative baseline: each period is compared only with reviews posted before that period. This avoids future leakage. For example, a month in 2024 is not compared with reviews from 2025 or 2026.

Future decision-support work could add two additional baselines:

1. Rolling baseline: the mean or median over the previous k periods.
2. Seasonal baseline: the same month or quarter in prior years.

For luxury hospitality, a rolling baseline is likely to be the most practical. A six-month or twelve-month rolling baseline could detect current drift without being dominated by early historical reviews. Seasonal baselines would be useful when travel demand and guest mix are seasonal.

### 12.4 Robust Drift Calculation

For a monitored metric M in period t, simple drift is:

```text
drift_t = M_t - baseline_t
```

For metrics where lower is worse, such as average rating or average sentiment, negative drift would be the concern. For metrics where higher is worse, such as low-rating share or anger count, positive drift would be the concern.

The implemented monitor uses a robust standardized form for median sentiment and median rating:

```text
robust_z_t = (period_median_t - historical_median_t) / historical_MAD_t
```

MAD means median absolute deviation. It is preferable here because review sentiment is skewed, review volume varies by period, and isolated outlier reviews should not control the baseline. The script only calculates robust z-scores after enough prior reviews exist. It sets a statistical flag when the current period has at least three reviews, the prior baseline has at least twenty reviews, and the robust z-score is at or below -2. This flag is a triage signal, not proof of operational failure.

### 12.5 Future Persistence Rule

A future framework should not react to every fluctuation. It should evaluate persistence over n periods:

```text
trigger if drift is unfavorable for n consecutive periods
```

For a future decision-support extension, the following default ladder is recommended:

| Level | Trigger | Interpretation |
|---|---|---|
| Watch | Metric is worse than baseline for 2 consecutive periods. | Possible emerging issue. |
| Investigate | Metric is worse than baseline by more than normal variation for 2 periods. | Likely operational signal. |
| Act | Low-rating share doubles or sentiment declines for 3 consecutive periods. | Intervention required. |
| Escalate | Service, cleanliness, rooms, safety, or value drops sharply with negative text evidence. | Senior management and investment review required. |

The number of periods should be adjusted based on review volume. If monthly review volume is low, quarterly periods would be more reliable.

### 12.6 Minimum Volume Rule

The current script uses minimum counts before assigning statistical flags, but it does not yet assign interpretive confidence labels. A future decision-support implementation should assign each period a confidence label:

| Period review count | Confidence |
|---:|---|
| 1 to 4 | Low confidence; read reviews manually. |
| 5 to 9 | Moderate confidence; combine with adjacent periods if needed. |
| 10 or more | Higher confidence for aggregate metrics. |

This would prevent overreaction to thin data. However, severe complaints involving safety, cleanliness, discrimination, or major service failure should still be reviewed immediately even if the period count is small.

## 13. Future Work: Pattern-to-Action Interpretation

Pattern-to-action mapping is not currently implemented in the repository. It is a proposed future layer that could be developed after the statistical drift outputs are validated and trigger-state rules are defined. The current drift metrics become managerially useful only when different patterns are mapped to different action pathways.

| Observed pattern | Likely interpretation | Illustrative management response | Illustrative investment response |
|---|---|---|---|
| Rating down and sentiment down | Broad guest-experience decline. | Root-cause review, department-level service audit, immediate service recovery. | Consider targeted investment if text points to assets, rooms, F&B, or facilities. |
| Rating stable but sentiment down | Guests still rate highly, but language is cooling. | Early warning review; inspect high-rating reviews with negative text. | Protect experience drivers before ratings decline. |
| Rating down but sentiment stable | Value or expectation mismatch. | Review price communication, package design, inclusions, and pre-arrival promises. | Invest in perceived-value enhancements before discounting. |
| Value rating down | Price no longer feels justified. | Audit inclusions, transparency, upsell friction, and guest expectation setting. | Invest in visible value creators or reposition packages. |
| Service rating down | Core luxury promise is weakening. | Retrain staff, audit butler handoffs, review staffing ratios, improve recovery protocols. | Invest in staffing, language capability, training, and retention. |
| Rooms or cleanliness down | Physical product or maintenance issue. | Inspect recurring room/villa defects and housekeeping process. | Prioritize capex, preventive maintenance, refurbishment, or quality-control systems. |
| Food and beverage complaints rise | Dining experience is weakening. | Review menu, breakfast, wait times, price-value, and service coordination. | Invest in kitchen/service capacity, restaurant refresh, or menu development. |
| Negative emotions increase | Emotional intensity of complaints is rising. | Read negative-emotion reviews manually; classify by failure type. | Escalate if linked to structural experience gaps. |
| Sentiment volatility rises | Experience consistency problem. | Compare peak/off-peak periods, staff shifts, occupancy, and guest segments. | Invest in process standardization and operational resilience. |

## 14. Future Work: Qualitative Review of Outliers

When the statistical drift monitor flags a period, it should always be followed by qualitative reading. The recommended future process is:

1. Identify periods or segments that triggered watch, investigate, act, or escalate.
2. Extract reviews from those periods with low rating, low sentiment, high anger, high disgust, or high negative word counts.
3. Read the original `review_text`, not only the cleaned text.
4. Code the complaint themes manually or semi-manually.
5. Distinguish controllable issues from uncontrollable factors.
6. Assign each controllable theme to an operational owner.
7. Track whether the theme persists after intervention.

This qualitative step would protect the method from false precision. A negative score can show where to look, but the review text explains what actually happened.

## 15. Visualization Strategy

The project generates several visual outputs, each with a methodological purpose:

| Figure | Purpose |
|---|---|
| Sentiment distribution | Shows overall positive, neutral, and negative classification balance. |
| Rating-sentiment boxplot | Compares textual sentiment with star ratings and identifies divergence. |
| Aspect mean ratings | Compares structured value, rooms, location, cleanliness, service, and sleep-quality ratings. |
| Aspect low-score share | Identifies dimensions where 1-3 star aspect ratings are concentrated. |
| Yearly aspect-rating heatmap | Shows whether structured aspect ratings change across years while displaying available rating counts. |
| Aspect sentiment boxplot | Compares whole-review text sentiment across structured aspect-rating levels. |
| Aspect low-score key terms | Shows words most associated with low aspect scores compared with high aspect scores. |
| Aspect low-score key phrases | Shows two-word phrases most associated with low aspect scores compared with high aspect scores. |
| Aspect negative-term heatmap | Highlights negative sentiment words that appear unusually often in low-aspect reviews. |
| Aspect-text mismatch counts | Shows where rating and text signals disagree and require qualitative review. |
| Emotion breakdown | Shows dominant NRC emotion categories across the corpus. |
| Sentiment word cloud | Highlights frequent sentiment-bearing words after filtering domain-neutral terms. |
| Monthly heatmap | Shows median-length-normalized sentiment intensity by month and year. |
| Monthly rolling trend | Shows smoothed median-length-normalized sentiment movement and prior-average comparison. |
| Monthly drift monitor | Shows monthly robust z-scores for median sentiment against prior review history. |
| Quarterly boxplot | Shows within-quarter distribution of AFINN scaled to a median-length review. |
| Yearly boxplot | Shows long-term distribution, average, median, trimmed mean, quartiles, and outliers for AFINN scaled to a median-length review. |

Visualizations should be interpreted as analytical aids, not as evidence by themselves. Each chart should be connected back to the underlying reviews and operational context.

## 16. Reliability, Validity, and Triangulation

### 16.1 Reliability

Reliability is supported by scripted preprocessing, centralized configuration, deterministic cleaning rules, and reproducible outputs. The same raw CSV and scripts should produce the same cleaned and scored files.

### 16.2 Construct Validity

Construct validity is strengthened by measuring guest experience through multiple indicators:

- Star rating.
- Textual sentiment.
- Emotion categories.
- Aspect ratings.
- Review text themes.
- Temporal patterns.

No single indicator is treated as sufficient. For example, a decline in average AFINN score should be checked against star ratings, aspect ratings, and review narratives.

### 16.3 Internal Validation

Internal validation is achieved through triangulation across lexicons and structured ratings. If ratings, AFINN scores, Syuzhet scores, and negative-emotion counts all move in the same direction, confidence increases. If they diverge, the divergence itself becomes an analytical finding.

### 16.4 External Validity

External validity is limited because the study focuses on one luxury resort and one review platform. The analytical workflow can be adapted to other hotels, but any future drift thresholds and interpretation rules should be recalibrated for each property's review volume, market segment, language mix, and brand promise.

## 17. Ethical and Data Governance Considerations

The project uses online review data, but public availability does not remove ethical responsibility. The following safeguards are recommended:

1. Report aggregate patterns rather than identifying individual reviewers.
2. Avoid quoting long review passages unless necessary and properly attributed.
3. Do not track reviewer names in this project; if future work requires identifiable reviewer information, keep it outside the public analysis outputs and document the access controls.
4. Preserve raw text for auditability but limit unnecessary redistribution.
5. Avoid using sentiment scores to profile or target individual guests.
6. If decision-support features are later added, treat algorithmic outputs as supporting evidence, not as final judgments.
7. Respect platform rules and data-use restrictions when acquiring or refreshing data.

The ethical stance is particularly important because luxury-hotel reviews may include personal travel details, family arrangements, special occasions, complaints, and staff names.

## 18. Limitations

Several limitations must be acknowledged.

First, TripAdvisor reviewers are self-selected. They may not represent all guests, and review behavior may vary by nationality, age, travel purpose, satisfaction intensity, and digital habits.

Second, star ratings are skewed toward positive evaluations. In this corpus, the median rating is 5.0, which means small declines in the average may matter even when the overall rating remains high.

Third, lexicon-based sentiment analysis can misinterpret context. The implemented scoring now handles simple local negation windows, but it may still struggle with sarcasm, complex negation, multilingual content, idioms, local cultural terms, and luxury-hospitality vocabulary.

Fourth, summed AFINN and Syuzhet scores are influenced by review length. Longer reviews may receive larger positive or negative totals simply because they contain more sentiment words. The trend charts and aspect-text diagnostic summaries reduce this problem by scaling sentiment to the dataset's median cleaned review length where period or aspect means are compared. Any remaining displays that use summed sentiment scores should still be read with review length in mind.

Fifth, review dates may not equal stay dates. A guest may post a review weeks or months after the actual stay. Where possible, stay dates should be used for operational diagnosis and review dates should be used for public-perception timing.

Sixth, platform and scraping conditions may affect what data are available. Historical reviews, hidden text, management responses, translated reviews, or deleted reviews may not be consistently captured.

Seventh, investment decisions require financial data not present in the review corpus. Sentiment can identify demand-side pain points and experience drivers, but it cannot by itself estimate return on investment. A future investment layer would need to combine review analytics with occupancy, ADR, RevPAR, margin, capex cost, maintenance logs, complaint records, and competitive benchmarking.

## 19. Recommended Extensions

The current methodology can be extended in several ways:

1. Compare raw and median-length-normalized AFINN and Syuzhet side by side in selected diagnostic tables so readers can distinguish total evaluative content from normalized sentiment intensity.
2. Extend the current aspect-text analysis from review-level weak labels to sentence-level or phrase-level aspect classification for service, rooms, value, dining, spa, beach, and privacy.
3. Use manual coding on low-rating and high-negative-emotion reviews to validate automated themes.
4. Add multilingual handling for non-English reviews.
5. Compare review-date trends with stay-date trends.
6. Extend the implemented drift metrics to low-rating share, negative-share, emotion rates, and aspect ratings.
7. Add trigger-state logic for watch, investigate, act, and escalate categories.
8. Add a qualitative review workflow for reviews that trigger low-rating, low-sentiment, or high-negative-emotion alerts.
9. Incorporate management responses and response time as service recovery indicators.
10. Add competitor benchmarks for comparable luxury resorts in Bali.
11. Link sentiment drift to occupancy, ADR, RevPAR, renovation timelines, maintenance records, and complaint logs.
12. Build a dashboard with trigger states and action recommendations.
13. Conduct sensitivity analysis using monthly, quarterly, and semiannual periods.
14. Add unsupervised review-authenticity risk screening as a future methodological extension, using reviewer sparsity, text-shape anomalies, rating-sentiment mismatch, near-duplicate detection, temporal context, and multivariate anomaly models to prioritize manual inspection rather than classify reviews as fake. This extension should explicitly separate period-level signals from review-level evidence: high review volume in a month should trigger contextual review, not automatically increase suspicion for every review in that month. Robustness checks should include temporal ablation, threshold sensitivity analysis, and human validation of sampled low-, moderate-, and high-risk reviews.

## 20. Conclusion

This methodology transforms TripAdvisor reviews of Bvlgari Resort Bali into a structured research dataset and visualization workflow. It begins with data validation and text preprocessing, applies multiple lexicon-based sentiment and emotion measures, compares text sentiment with star and aspect ratings, visualizes sentiment patterns over time, and produces robust period-monitoring outputs. The current project does not yet implement management or investment decision logic. Its future methodological contribution would be a decision-support extension in which persistent unfavorable drift is mapped to tiered management and investment responses.

The framework is academically rigorous because it specifies the corpus, preprocessing rules, analytical measures, validation logic, limitations, and ethical constraints. It is also a foundation for future managerial use because it produces the indicators that a later decision-support system would need. The central principle is caution with actionability: do not treat sentiment movement as meaningful until it is persistent, supported by enough review volume, triangulated with ratings or aspect scores, interpreted through the actual review text, and connected to operational or financial evidence.

## References

Adnyana, P. P., Wiweka, K., Lochan, A., & Trisdyani, N. L. P. (2026). Beyond taste: A sentiment analysis of informal language and cultural appreciation in Tripadvisor reviews of Balinese Ayam Betutu. *SOSIOHUMANIORA: Jurnal Ilmiah Ilmu Sosial dan Humaniora, 12*(1), 176-197. https://doi.org/10.30738/sosio.v12i1.21041

Bichler, B. F., Pikkemaat, B., & Peters, M. (2021). Exploring the role of service quality, atmosphere and food for revisits in restaurants by using an e-mystery guest approach. *Journal of Hospitality and Tourism Insights, 4*(3), 351-369. https://doi.org/10.1108/JHTI-04-2020-0048

Filieri, R., Alguezaui, S., & McLeay, F. (2015). Why do travelers trust TripAdvisor? Antecedents of trust towards consumer-generated media and its influence on recommendation adoption and word of mouth. *Tourism Management, 51*, 174-185. https://doi.org/10.1016/j.tourman.2015.05.007

Kandampully, J., & Suhartanto, D. (2000). Customer loyalty in the hotel industry: The role of customer satisfaction and image. *International Journal of Contemporary Hospitality Management, 12*(6), 346-351. https://doi.org/10.1108/09596110010342559

Litvin, S. W. (2019). Hofstede, cultural differences, and TripAdvisor hotel reviews. *International Journal of Tourism Research, 21*(5), 712-717. https://doi.org/10.1002/jtr.2298

Liu, B. (2022). *Sentiment analysis: Mining opinions, sentiments, and emotions*. Cambridge University Press.

Mohammad, S. M., & Turney, P. D. (2013). *NRC Emotion Lexicon*. National Research Council Canada. https://doi.org/10.4224/21270984

Nielsen, F. A. (2011). A new ANEW: Evaluation of a word list for sentiment analysis in microblogs. *Proceedings of the ESWC2011 Workshop on Making Sense of Microposts*, 93-98.

Silge, J., & Robinson, D. (2016). tidytext: Text mining and analysis using tidy data principles in R. *Journal of Open Source Software, 1*(3), 37. https://doi.org/10.21105/joss.00037
