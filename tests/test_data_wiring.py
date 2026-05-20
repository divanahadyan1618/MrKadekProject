import subprocess
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class DataWiringTests(unittest.TestCase):
    def test_data_import_script_uses_prepared_csv(self):
        script = (PROJECT_ROOT / "01_data_import.R").read_text()
        config = (PROJECT_ROOT / "scripts" / "data_config.R").read_text()
        self.assertIn("Prepared TripAdvisor review CSV", config)
        self.assertIn('file.path("data", "raw", "reviews.csv")', config)
        self.assertIn("validate_prepared_reviews", script)

    def test_checked_in_csv_omits_internal_and_response_metadata(self):
        csv_header = (PROJECT_ROOT / "data" / "raw" / "reviews.csv").read_text().splitlines()[0]
        columns = csv_header.split(",")
        removed_columns = [
            "reviewer_helpful_votes",
            "machine_translated",
            "show_original_available",
            "has_management_response",
            "management_response_text",
            "management_response_header",
            "management_response_author",
            "management_response_role",
            "management_response_date",
            "review_url",
            "page_url",
            "source_observed_at",
            "source_snapshot_id",
        ]
        for column in removed_columns:
            with self.subTest(column=column):
                self.assertNotIn(column, columns)

    def test_generated_outputs_are_gitignored_but_raw_reviews_csv_is_tracked(self):
        raw_result = subprocess.run(
            ["git", "check-ignore", "--no-index", "data/raw/reviews.csv"],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertNotEqual(raw_result.returncode, 0, raw_result.stdout)

        paths = [
            "data/cleaned/hotel_cleaned_reviews.csv",
            "data/cleaned/hotel_cleaned_tokens.csv",
            "data/cleaned/hotel_sentiment_scores.csv",
            "output/figures/sentiment_distribution.png",
        ]
        for path in paths:
            with self.subTest(path=path):
                result = subprocess.run(
                    ["git", "check-ignore", "--no-index", path],
                    cwd=PROJECT_ROOT,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_legacy_bvlgari_csv_paths_are_not_used_by_scripts(self):
        paths = [
            "01_data_import.R",
            "02_cleaning.R",
            "03_sentiment_analysis.R",
            "04_visualization.R",
            "Master_TripAdvisor.R",
            "README.md",
            "scripts/data_config.R",
        ]
        for path in paths:
            with self.subTest(path=path):
                text = (PROJECT_ROOT / path).read_text()
                self.assertNotIn("bvlgari_raw_reviews.csv", text)
                self.assertNotIn("bvlgari_cleaned_reviews.csv", text)
                self.assertNotIn("bvlgari_cleaned_tokens.csv", text)
                self.assertNotIn("bvlgari_sentiment_scores.csv", text)

    def test_private_capture_tool_is_not_mentioned(self):
        forbidden = "path" + "glass"
        paths = [
            "01_data_import.R",
            "02_cleaning.R",
            "03_sentiment_analysis.R",
            "04_visualization.R",
            "Master_TripAdvisor.R",
            "README.md",
            "data/README.md",
            "scripts/data_config.R",
            "scripts/helpers.R",
            "01_data_import.ipynb",
            "02_cleaning.ipynb",
            "03_sentiment_analysis.ipynb",
            "04_visualization.ipynb",
            "Colab_Master_TripAdvisor.ipynb",
        ]
        for path in paths:
            with self.subTest(path=path):
                text = (PROJECT_ROOT / path).read_text().lower()
                self.assertNotIn(forbidden, text)

    def test_step_one_uses_data_import_language(self):
        forbidden_terms = ["scr" + "ap", "01_" + "scr" + "aping"]
        paths = [
            "01_data_import.R",
            "02_cleaning.R",
            "03_sentiment_analysis.R",
            "04_visualization.R",
            "Master_TripAdvisor.R",
            "README.md",
            "data/README.md",
            "scripts/data_config.R",
            "scripts/helpers.R",
            "01_data_import.ipynb",
            "02_cleaning.ipynb",
            "03_sentiment_analysis.ipynb",
            "04_visualization.ipynb",
            "Colab_Master_TripAdvisor.ipynb",
        ]
        for path in paths:
            with self.subTest(path=path):
                text = (PROJECT_ROOT / path).read_text().lower()
                for forbidden in forbidden_terms:
                    self.assertNotIn(forbidden, text)

    def test_visualization_redisplays_emotions_chart_for_rstudio(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn("Showing the emotions breakdown chart again", script)
        self.assertIn("print(p2)", script)

    def test_visualization_labels_bar_chart_counts(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn('count(sentiment_category, name = "review_count")', script)
        self.assertIn("geom_text(aes(label = review_count)", script)
        self.assertIn("geom_text(aes(label = format(score, big.mark = \",\"))", script)

    def test_visualization_bins_sentiment_by_rating(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn("rating_group", script)
        self.assertIn("average_rating", script)
        self.assertIn("Sentiment Score Distribution by TripAdvisor Rating", script)
        self.assertIn("sentiment_by_rating_boxplot.png", script)
        self.assertIn("rating_average_line", script)
        self.assertIn("stat_summary", script)

    def test_visualization_uses_monthly_trend_charts_and_period_boxplots(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn("Monthly Sentiment Heatmap", script)
        self.assertIn("Monthly Sentiment Trend with Rolling Average", script)
        self.assertIn("Quarterly Sentiment Distribution", script)
        self.assertIn("Yearly Sentiment Distribution", script)
        self.assertIn("sentiment_trend_monthly_heatmap.png", script)
        self.assertIn("sentiment_trend_monthly_rolling.png", script)
        self.assertIn("sentiment_trend_quarterly.png", script)
        self.assertIn("sentiment_trend_yearly.png", script)
        self.assertIn("period_avg", script)
        self.assertIn("prior_avg", script)
        self.assertIn("rolling_avg_6", script)
        self.assertIn("stats_label_y", script)
        self.assertIn("period_median", script)
        self.assertIn("period_q1", script)
        self.assertIn("period_q3", script)
        self.assertIn("period_min", script)
        self.assertIn("period_max", script)
        self.assertIn("n_outliers", script)
        self.assertNotIn("Series avg:", script)


if __name__ == "__main__":
    unittest.main()
