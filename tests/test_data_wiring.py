import csv
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class DataWiringTests(unittest.TestCase):
    def copy_project_for_workflow_test(self):
        temp_dir = Path(tempfile.mkdtemp(prefix="mrkadek-workflow-"))
        project_copy = temp_dir / "project"
        shutil.copytree(
            PROJECT_ROOT,
            project_copy,
            ignore=shutil.ignore_patterns(
                ".git",
                ".Rproj.user",
                "__pycache__",
                ".ipynb_checkpoints",
                "Rplots.pdf",
            ),
        )
        return temp_dir, project_copy

    def test_data_import_script_uses_prepared_csv(self):
        script = (PROJECT_ROOT / "01_data_import.R").read_text()
        config = (PROJECT_ROOT / "scripts" / "data_config.R").read_text()
        self.assertIn("Prepared TripAdvisor review CSV", config)
        self.assertIn('file.path("data", "raw", "reviews.csv")', config)
        self.assertIn("validate_prepared_reviews", script)

    def test_data_import_fails_when_all_review_text_is_blank(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type",
                        "1,Bvlgari Resort Bali,Blank one,   ,5,May 2026,May 2026,Couple",
                        "2,Bvlgari Resort Bali,Blank two,,4,May 2026,May 2026,Family",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("no usable review text", (result.stdout + result.stderr).lower())
        finally:
            shutil.rmtree(temp_dir)

    def test_data_import_rejects_reviews_for_other_hotels(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Couple",
                        "2,Other Bali Hotel,Wrong hotel,This row should not be analyzed.,4,May 2026,May 2026,Family",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Bvlgari Resort Bali", result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_data_import_rejects_blank_hotel_names_in_review_rows(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Couple",
                        "2,,Unidentified hotel,This row should not be analyzed.,4,May 2026,May 2026,Family",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("blank hotel_name", (result.stdout + result.stderr).lower())
        finally:
            shutil.rmtree(temp_dir)

    def test_root_uploaded_reviews_are_validated_before_replacing_prepared_csv(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            original_raw_data = raw_path.read_bytes()
            root_upload = project_copy / "reviews.csv"
            root_upload.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type",
                        "1,Other Bali Hotel,Wrong hotel,This row should not be accepted.,4,May 2026,May 2026,Family",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                raw_path.read_bytes(),
                original_raw_data,
                "An invalid root reviews.csv must not overwrite the prepared raw CSV.",
            )
            self.assertIn("Bvlgari Resort Bali", result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_data_import_rejects_direct_reviewer_identifier_columns(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type,reviewer_name,reviewer_location",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Couple,Alice Reviewer,Jakarta",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("direct reviewer identifier", (result.stdout + result.stderr).lower())
            self.assertIn("reviewer_name", result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_data_import_allows_reviewer_location_for_geography_summaries(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type,reviewer_location",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Couple,Jakarta Indonesia",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_data_import_rejects_non_whitelisted_location_metadata(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type,user_location",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Couple,Jakarta Indonesia",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("direct reviewer identifier", (result.stdout + result.stderr).lower())
            self.assertIn("user_location", result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_data_import_rejects_bare_author_and_reviewer_columns(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type,author,reviewer",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Couple,Alice Reviewer,Bob Reviewer",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("direct reviewer identifier", (result.stdout + result.stderr).lower())
            self.assertIn("author", result.stdout + result.stderr)
            self.assertIn("reviewer", result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_data_import_rejects_forbidden_source_metadata_columns(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type,review_url,management_response_text",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Couple,https://example.test/review/1,Thank you from Manager Alice",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("forbidden source metadata", (result.stdout + result.stderr).lower())
            self.assertIn("review_url", result.stdout + result.stderr)
            self.assertIn("management_response_text", result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_root_uploaded_reviews_with_contacts_do_not_replace_prepared_csv(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            original_raw_data = raw_path.read_bytes()
            root_upload = project_copy / "reviews.csv"
            root_upload.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type",
                        "1,Bvlgari Resort Bali,Contact,Please email guest@example.com or visit https://example.test/review,5,May 2026,May 2026,Couple",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                raw_path.read_bytes(),
                original_raw_data,
                "A root reviews.csv with embedded contacts must not overwrite the prepared raw CSV.",
            )
            self.assertIn("embedded contact", (result.stdout + result.stderr).lower())
        finally:
            shutil.rmtree(temp_dir)

    def test_root_uploaded_reviews_with_contacts_in_extra_columns_do_not_replace_prepared_csv(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            original_raw_data = raw_path.read_bytes()
            root_upload = project_copy / "reviews.csv"
            root_upload.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type,guest_note",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Couple,Email guest@example.com for details",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                raw_path.read_bytes(),
                original_raw_data,
                "A root reviews.csv with extra-column contacts must not overwrite the prepared raw CSV.",
            )
            self.assertIn("embedded contact", (result.stdout + result.stderr).lower())
            self.assertIn("guest_note", result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_root_uploaded_reviews_with_trip_type_disclosures_do_not_replace_prepared_csv(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            original_raw_data = raw_path.read_bytes()
            root_upload = project_copy / "reviews.csv"
            root_upload.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type",
                        "1,Bvlgari Resort Bali,Good stay,The room was excellent.,5,May 2026,May 2026,Traveled as a couple Review collected in partnership with this hotel",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "01_data_import.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(
                raw_path.read_bytes(),
                original_raw_data,
                "A root reviews.csv with trip-type source disclosures must not overwrite the prepared raw CSV.",
            )
            self.assertIn("source-disclosure", (result.stdout + result.stderr).lower())
            self.assertIn("trip_type", result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

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

    def test_tracked_csv_outputs_omit_direct_reviewer_identifiers_but_keep_location_context(self):
        review_level_paths = [
            PROJECT_ROOT / "data" / "raw" / "reviews.csv",
            PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_reviews.csv",
            PROJECT_ROOT / "data" / "cleaned" / "hotel_sentiment_scores.csv",
        ]
        for path in review_level_paths:
            with self.subTest(path=path):
                columns = path.read_text().splitlines()[0].split(",")
                self.assertNotIn("reviewer_name", columns)
                self.assertIn("reviewer_location", columns)

        token_columns = (
            PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_tokens.csv"
        ).read_text().splitlines()[0].split(",")
        self.assertNotIn("reviewer_name", token_columns)
        self.assertNotIn("reviewer_location", token_columns)

    def test_standardized_reviews_drop_future_reviewer_identifier_columns(self):
        r_code = """
        source("scripts/helpers.R")
        example_reviews <- tibble::tibble(
          review_id = "r1",
          hotel_name = "Bvlgari Resort Bali",
          title = "Great stay",
          review_text = "The room was excellent.",
          rating = "5",
          review_date = "Apr 2026",
          reviewer_id = "reviewer-123",
          user_id = "user-456",
          author_id = "author-789",
          member_id = "member-000",
          reviewer_location = "Jakarta Indonesia",
          reviewer_contributions = "12"
        )
        standardized <- standardize_hotel_reviews(example_reviews)
        forbidden <- c("reviewer_id", "user_id", "author_id", "member_id")
        if (any(forbidden %in% names(standardized))) {
          stop("Direct reviewer identifier columns were retained.")
        }
        if (!"reviewer_location" %in% names(standardized)) {
          stop("Reviewer location should be retained for aggregate geography summaries.")
        }
        if (!"reviewer_contributions" %in% names(standardized)) {
          stop("Non-identifying reviewer contribution count was removed.")
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_standardized_reviews_only_keep_whitelisted_reviewer_location_context(self):
        r_code = """
        source("scripts/helpers.R")
        example_reviews <- tibble::tibble(
          review_id = "r1",
          hotel_name = "Bvlgari Resort Bali",
          title = "Great stay",
          review_text = "The room was excellent.",
          rating = "5",
          review_date = "Apr 2026",
          reviewer_location = "Jakarta Indonesia",
          user_location = "Private user place",
          author_location = "Private author place",
          member_location = "Private member place",
          profile_location = "Private profile place"
        )
        standardized <- standardize_hotel_reviews(example_reviews)
        if (!"reviewer_location" %in% names(standardized)) {
          stop("Reviewer location should be retained for aggregate geography summaries.")
        }
        forbidden <- c("user_location", "author_location", "member_location", "profile_location")
        if (any(forbidden %in% names(standardized))) {
          stop("Non-whitelisted reviewer location metadata was retained.")
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_standardized_reviews_canonicalize_reviewer_location_aliases(self):
        r_code = """
        source("scripts/helpers.R")

        camel_case_reviews <- tibble::tibble(
          review_id = "r1",
          hotel_name = "Bvlgari Resort Bali",
          title = "Great stay",
          review_text = "The room was excellent.",
          rating = "5",
          review_date = "Apr 2026",
          reviewerLocation = "Jakarta Indonesia"
        )
        camel_case_standardized <- standardize_hotel_reviews(camel_case_reviews)
        if (!"reviewer_location" %in% names(camel_case_standardized)) {
          stop("Camel-case reviewer location was not canonicalized.")
        }
        if ("reviewerLocation" %in% names(camel_case_standardized)) {
          stop("Camel-case reviewer location leaked through under its source name.")
        }
        if (camel_case_standardized$reviewer_location[[1]] != "Jakarta Indonesia") {
          stop("Camel-case reviewer location value changed during standardization.")
        }

        spaced_reviews <- tibble::tibble(
          review_id = "r2",
          hotel_name = "Bvlgari Resort Bali",
          title = "Great stay",
          review_text = "The room was excellent.",
          rating = "5",
          review_date = "Apr 2026",
          `Reviewer Location` = "Singapore Singapore"
        )
        spaced_standardized <- standardize_hotel_reviews(spaced_reviews)
        if (!"reviewer_location" %in% names(spaced_standardized)) {
          stop("Spaced reviewer location was not canonicalized.")
        }
        if ("Reviewer Location" %in% names(spaced_standardized)) {
          stop("Spaced reviewer location leaked through under its source name.")
        }
        if (spaced_standardized$reviewer_location[[1]] != "Singapore Singapore") {
          stop("Spaced reviewer location value changed during standardization.")
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_standardized_reviews_drop_bare_author_and_reviewer_columns(self):
        r_code = """
        source("scripts/helpers.R")
        example_reviews <- tibble::tibble(
          review_id = "r1",
          hotel_name = "Bvlgari Resort Bali",
          title = "Great stay",
          review_text = "The room was excellent.",
          rating = "5",
          review_date = "Apr 2026",
          author = "Alice Reviewer",
          reviewer = "Bob Reviewer",
          reviewer_contributions = "12"
        )
        standardized <- standardize_hotel_reviews(example_reviews)
        forbidden <- c("author", "reviewer")
        if (any(forbidden %in% names(standardized))) {
          stop("Bare author or reviewer columns were retained.")
        }
        if (!"reviewer_contributions" %in% names(standardized)) {
          stop("Non-identifying reviewer contribution count was removed.")
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_generic_name_column_is_not_treated_as_hotel_name(self):
        r_code = """
        source("scripts/helpers.R")
        example_reviews <- tibble::tibble(
          name = "Alice Reviewer",
          review_text = "The room was excellent.",
          rating = "5",
          review_date = "Apr 2026"
        )
        standardized <- standardize_hotel_reviews(example_reviews)
        if (!is.na(standardized$hotel_name[[1]])) {
          stop(paste("Generic name leaked into hotel_name:", standardized$hotel_name[[1]]))
        }
        if ("name" %in% names(standardized)) {
          stop("Generic name column was retained as analysis metadata.")
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_standardized_reviews_drop_forbidden_source_metadata_columns(self):
        r_code = """
        source("scripts/helpers.R")
        example_reviews <- tibble::tibble(
          review_id = "r1",
          hotel_name = "Bvlgari Resort Bali",
          title = "Great stay",
          review_text = "The room was excellent.",
          rating = "5",
          review_date = "Apr 2026",
          review_url = "https://example.test/review/r1",
          page_url = "https://example.test/page",
          source_observed_at = "2026-05-01",
          source_snapshot_id = "snapshot-1",
          reviewer_helpful_votes = "5",
          machine_translated = "false",
          show_original_available = "false",
          has_management_response = "true",
          management_response_text = "Thank you.",
          management_response_header = "Response",
          management_response_author = "Manager",
          management_response_role = "General Manager",
          management_response_date = "Apr 2026",
          insider_tip = "Ask for a cliff villa."
        )
        standardized <- standardize_hotel_reviews(example_reviews)
        forbidden <- c(
          "review_url",
          "page_url",
          "source_observed_at",
          "source_snapshot_id",
          "reviewer_helpful_votes",
          "machine_translated",
          "show_original_available",
          "has_management_response",
          "management_response_text",
          "management_response_header",
          "management_response_author",
          "management_response_role",
          "management_response_date"
        )
        if (any(forbidden %in% names(standardized))) {
          stop("Forbidden source metadata columns were retained.")
        }
        if (!"insider_tip" %in% names(standardized)) {
          stop("Allowed operational context was removed.")
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_standardized_reviews_drop_camel_case_metadata_columns(self):
        r_code = """
        source("scripts/helpers.R")
        example_reviews <- tibble::tibble(
          review_id = "r1",
          hotel_name = "Bvlgari Resort Bali",
          title = "Great stay",
          review_text = "The room was excellent.",
          rating = "5",
          review_date = "Apr 2026",
          reviewerName = "Alice Reviewer",
          userName = "alice123",
          profileUrl = "https://example.test/profile/alice",
          reviewUrl = "https://example.test/review/r1",
          managementResponseText = "Thank you.",
          managementResponseDate = "Apr 2026",
          reviewerContributions = "12"
        )
        standardized <- standardize_hotel_reviews(example_reviews)
        forbidden <- c(
          "reviewerName",
          "userName",
          "profileUrl",
          "reviewUrl",
          "managementResponseText",
          "managementResponseDate"
        )
        if (any(forbidden %in% names(standardized))) {
          stop("CamelCase reviewer or source metadata columns were retained.")
        }
        if (!"reviewerContributions" %in% names(standardized)) {
          stop("Non-identifying reviewer contribution count was removed.")
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_cleaned_token_csv_only_tracks_review_id_and_word(self):
        columns = (PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_tokens.csv").read_text().splitlines()[0].split(",")
        self.assertEqual(columns, ["review_id", "word"])

    def test_tracked_review_text_omits_embedded_urls_and_emails(self):
        url_or_email_pattern = re.compile(
            r"https?://|www\.|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
            re.IGNORECASE,
        )
        self.assertIsNotNone(url_or_email_pattern.search("https://example.com/review"))
        self.assertIsNotNone(url_or_email_pattern.search("www.example.com/review"))
        self.assertIsNotNone(url_or_email_pattern.search("guest@example.com"))
        paths = [
            PROJECT_ROOT / "data" / "raw" / "reviews.csv",
            PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_reviews.csv",
            PROJECT_ROOT / "data" / "cleaned" / "hotel_sentiment_scores.csv",
        ]
        for path in paths:
            with self.subTest(path=path):
                text = path.read_text()
                self.assertIsNone(url_or_email_pattern.search(text))

    def test_tracked_trip_type_omits_review_collection_disclosures(self):
        paths = [
            PROJECT_ROOT / "data" / "raw" / "reviews.csv",
            PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_reviews.csv",
            PROJECT_ROOT / "data" / "cleaned" / "hotel_sentiment_scores.csv",
        ]
        forbidden_fragments = [
            "review collected in partnership",
            "official review collection partners",
            "business uses tools provided by tripadvisor",
        ]
        for path in paths:
            with self.subTest(path=path):
                with path.open(newline="", encoding="utf-8") as handle:
                    reader = csv.DictReader(handle)
                    self.assertIn("trip_type", reader.fieldnames)
                    for row in reader:
                        trip_type = (row.get("trip_type") or "").lower()
                        for fragment in forbidden_fragments:
                            self.assertNotIn(fragment, trip_type)

    def test_cleaned_review_text_has_no_angle_bracket_fragments(self):
        cleaned_reviews = PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_reviews.csv"
        sentiment_scores = PROJECT_ROOT / "data" / "cleaned" / "hotel_sentiment_scores.csv"
        for path in [cleaned_reviews, sentiment_scores]:
            with self.subTest(path=path):
                self.assertNotIn("<min", path.read_text())

    def test_clean_text_removes_angle_bracket_fragments(self):
        r_code = """
        source("scripts/helpers.R")
        cleaned <- clean_text("<8min w/a")
        if (stringr::str_detect(cleaned, "[<>]")) {
          stop(paste("Angle-bracket fragment remained:", cleaned))
        }
        if (!stringr::str_detect(cleaned, "min")) {
          stop(paste("Expected the non-symbol text to remain:", cleaned))
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_clean_text_keeps_word_boundaries_around_unicode_punctuation(self):
        r_code = r"""
        source("scripts/helpers.R")
        raw_text <- "open\uFF0Ci meant it\uFF0Cand breakfast sucks\uFF0Ccant even"
        cleaned <- clean_text(normalize_slang(raw_text))
        bad_tokens <- c("openi", "itand", "suckscannot")
        found_bad_tokens <- bad_tokens[stringr::str_detect(cleaned, bad_tokens)]
        if (length(found_bad_tokens) > 0) {
          stop(paste("Unicode punctuation glued words together:", cleaned))
        }
        if (!stringr::str_detect(cleaned, "open i")) {
          stop(paste("Expected a boundary between open and i:", cleaned))
        }
        if (!stringr::str_detect(cleaned, "it and")) {
          stop(paste("Expected a boundary between it and and:", cleaned))
        }
        if (!stringr::str_detect(cleaned, "sucks cannot")) {
          stop(paste("Expected a boundary between sucks and cannot:", cleaned))
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_punctuation_slang_is_normalized_before_cleaning(self):
        r_code = """
        source("scripts/helpers.R")
        normalized <- normalize_slang("w/ service and w/o issues")
        cleaned <- clean_text(normalized)
        if (!stringr::str_detect(cleaned, "with service")) {
          stop(paste("w/ was not normalized to with:", cleaned))
        }
        if (!stringr::str_detect(cleaned, "without issues")) {
          stop(paste("w/o was not normalized to without:", cleaned))
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_smart_apostrophe_contractions_are_normalized_before_sentiment_scoring(self):
        r_code = r"""
        source("scripts/helpers.R")
        raw_text <- "I don\u2019t recommend this place"
        cleaned <- clean_text(normalize_slang(raw_text))
        if (!stringr::str_detect(cleaned, "do not recommend")) {
          stop(paste("Smart-apostrophe contraction was not expanded:", cleaned))
        }
        afinn_score <- score_negation_aware_sentiment(cleaned, method = "afinn")
        syuzhet_score <- score_negation_aware_sentiment(cleaned, method = "syuzhet")
        if (afinn_score >= 0 || syuzhet_score >= 0) {
          stop(paste("Negated recommendation should score negative:", afinn_score, syuzhet_score))
        }
        """
        result = subprocess.run(
            ["Rscript", "-e", r_code],
            cwd=PROJECT_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_sentiment_scoring_handles_negated_recommendation_complaints(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            cleaned_path = project_copy / "data" / "cleaned" / "hotel_cleaned_reviews.csv"
            cleaned_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,cleaned_text",
                        "1,Bvlgari Resort Bali,Bad stay,I cannot recommend this place,1,May 2026,i cannot recommend this place",
                    ]
                )
                + "\n"
            )
            result = subprocess.run(
                ["Rscript", "03_sentiment_analysis.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            with (project_copy / "data" / "cleaned" / "hotel_sentiment_scores.csv").open(
                newline="",
                encoding="utf-8",
            ) as handle:
                row = next(csv.DictReader(handle))

            self.assertLess(float(row["score_afinn"]), 0)
            self.assertLess(float(row["score_syuzhet"]), 0)
            self.assertEqual(row["review_word_count"], "5")
            self.assertEqual(row["median_review_word_count"], "5")
            self.assertAlmostEqual(
                float(row["score_afinn_per_median_review"]),
                float(row["score_afinn"]),
            )
            self.assertAlmostEqual(
                float(row["score_syuzhet_per_median_review"]),
                float(row["score_syuzhet"]),
            )
            self.assertEqual(row["sentiment_category"], "Negative")
        finally:
            shutil.rmtree(temp_dir)

    def test_actual_smart_apostrophe_one_star_review_is_negative(self):
        cleaned_reviews = PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_reviews.csv"
        with cleaned_reviews.open(newline="", encoding="utf-8") as handle:
            cleaned_row = next(row for row in csv.DictReader(handle) if row["review_id"] == "572509733")

        self.assertIn("do not recommend", cleaned_row["cleaned_text"])

        sentiment_scores = PROJECT_ROOT / "data" / "cleaned" / "hotel_sentiment_scores.csv"
        with sentiment_scores.open(newline="", encoding="utf-8") as handle:
            scored_row = next(row for row in csv.DictReader(handle) if row["review_id"] == "572509733")

        self.assertEqual(scored_row["rating"], "1")
        self.assertLess(float(scored_row["score_syuzhet"]), 0)
        self.assertEqual(scored_row["sentiment_category"], "Negative")

    def test_actual_unicode_punctuation_review_keeps_word_boundaries(self):
        cleaned_reviews = PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_reviews.csv"
        with cleaned_reviews.open(newline="", encoding="utf-8") as handle:
            cleaned_row = next(row for row in csv.DictReader(handle) if row["review_id"] == "197330067")

        cleaned_text = cleaned_row["cleaned_text"]
        for bad_token in ["openi", "itand", "homefood", "suckscannot"]:
            with self.subTest(bad_token=bad_token):
                self.assertIsNone(re.search(rf"\b{bad_token}\b", cleaned_text))

        self.assertIn("open i meant", cleaned_text)
        self.assertIn("it and my husband", cleaned_text)
        self.assertIn("home food are", cleaned_text)
        self.assertIn("breakfast sucks cannot", cleaned_text)

        cleaned_tokens = PROJECT_ROOT / "data" / "cleaned" / "hotel_cleaned_tokens.csv"
        with cleaned_tokens.open(newline="", encoding="utf-8") as handle:
            review_tokens = [
                row["word"]
                for row in csv.DictReader(handle)
                if row["review_id"] == "197330067"
            ]

        self.assertIn("sucks", review_tokens)
        self.assertIn("home", review_tokens)
        self.assertIn("food", review_tokens)
        self.assertNotIn("suckscannot", review_tokens)

    def test_required_cleaned_csvs_are_plain_git_files_not_lfs(self):
        required_csvs = [
            "data/cleaned/hotel_cleaned_reviews.csv",
            "data/cleaned/hotel_cleaned_tokens.csv",
            "data/cleaned/hotel_sentiment_scores.csv",
        ]
        for path in required_csvs:
            with self.subTest(path=path):
                result = subprocess.run(
                    ["git", "check-attr", "-a", "--", path],
                    cwd=PROJECT_ROOT,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("filter: lfs", result.stdout)
                self.assertNotIn("diff: lfs", result.stdout)
                self.assertNotIn("merge: lfs", result.stdout)
                first_line = (PROJECT_ROOT / path).read_text().splitlines()[0]
                self.assertNotIn("version https://git-lfs.github.com/spec/v1", first_line)

    def test_analysis_outputs_are_trackable(self):
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
            "output/figures/aspect_mean_ratings.png",
            "output/figures/aspect_low_score_share.png",
            "output/figures/aspect_yearly_rating_heatmap.png",
            "output/figures/aspect_sentiment_by_rating_boxplot.png",
            "output/figures/aspect_low_score_key_terms.png",
            "output/figures/aspect_low_score_key_phrases.png",
            "output/figures/aspect_negative_term_heatmap.png",
            "output/figures/aspect_text_mismatch_counts.png",
            "output/reports/aspect_rating_summary.csv",
            "output/reports/high_overall_low_aspect_reviews.csv",
            "output/reports/aspect_text_alignment.csv",
            "output/reports/aspect_text_band_summary.csv",
            "output/reports/aspect_text_key_terms.csv",
            "output/reports/aspect_text_key_phrases.csv",
            "output/reports/aspect_text_mismatches.csv",
            "output/reports/aspect_qualitative_examples.csv",
            "output/reports/annual_review_profile.csv",
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
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertTrue((PROJECT_ROOT / path).exists())

    def test_sampled_workflow_handles_sparse_aspect_ratings_without_root_pdf(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            env = os.environ.copy()
            env["HOTEL_REVIEW_SAMPLE_SIZE"] = "1"
            result = subprocess.run(
                ["Rscript", "Master_TripAdvisor.R"],
                cwd=project_copy,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse(
                (project_copy / "Rplots.pdf").exists(),
                "Non-interactive workflow runs should not create root Rplots.pdf",
            )
            combined_output = result.stdout + result.stderr
            self.assertIn("No usable structured aspect ratings", combined_output)
            self.assertIn("Skipping Step 5", combined_output)
            self.assertFalse((project_copy / "output" / "reports" / "aspect_rating_summary.csv").exists())
            self.assertFalse((project_copy / "output" / "figures" / "aspect_mean_ratings.png").exists())
            self.assertFalse((project_copy / "output" / "reports" / "aspect_text_key_terms.csv").exists())
        finally:
            shutil.rmtree(temp_dir)

    def test_master_workflow_handles_neutral_reviews_without_wordcloud_crash(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type",
                        "1,Bvlgari Resort Bali,Neutral one,The table is in the room.,3,May 2026,May 2026,Couple",
                        "2,Bvlgari Resort Bali,Neutral two,There is a chair and a door.,3,Apr 2026,Apr 2026,Family",
                    ]
                )
                + "\n"
            )

            result = subprocess.run(
                ["Rscript", "Master_TripAdvisor.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("No AFINN sentiment words", result.stdout + result.stderr)
            self.assertTrue((project_copy / "output" / "figures" / "wordcloud.png").exists())
        finally:
            shutil.rmtree(temp_dir)

    def test_master_workflow_skips_step_five_when_aspect_columns_are_absent(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            raw_path = project_copy / "data" / "raw" / "reviews.csv"
            raw_path.write_text(
                "\n".join(
                    [
                        "review_id,hotel_name,title,review_text,rating,review_date,stay_date,trip_type",
                        "1,Bvlgari Resort Bali,Good stay,The staff were excellent and the room was beautiful.,5,May 2026,May 2026,Couple",
                        "2,Bvlgari Resort Bali,Bad value,The view was nice but the price was terrible.,2,Apr 2026,Apr 2026,Family",
                    ]
                )
                + "\n"
            )
            for output_path in list((project_copy / "output" / "reports").glob("aspect_*.csv")) + [
                project_copy / "output" / "reports" / "high_overall_low_aspect_reviews.csv",
            ]:
                output_path.unlink(missing_ok=True)
            for output_path in (project_copy / "output" / "figures").glob("aspect_*.png"):
                output_path.unlink(missing_ok=True)

            result = subprocess.run(
                ["Rscript", "Master_TripAdvisor.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Skipping Step 5", result.stdout + result.stderr)
            self.assertFalse((project_copy / "output" / "reports" / "aspect_text_alignment.csv").exists())
        finally:
            shutil.rmtree(temp_dir)

    def test_visualization_rejects_ambiguous_month_day_review_dates(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        try:
            scores_path = project_copy / "data" / "cleaned" / "hotel_sentiment_scores.csv"
            with scores_path.open(newline="", encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
                fieldnames = rows[0].keys()
            rows[0]["review_date"] = "May 18"
            with scores_path.open("w", newline="", encoding="utf-8") as handle:
                writer = csv.DictWriter(handle, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(rows)

            result = subprocess.run(
                ["Rscript", "04_visualization.R"],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("ambiguous month-day review dates", (result.stdout + result.stderr).lower())
        finally:
            shutil.rmtree(temp_dir)

    def test_monthly_rolling_average_uses_calendar_months(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        r_code = """
        source("04_visualization.R")
        target_month <- as.Date("2021-04-01")
        window_start <- min(seq(target_month, by = "-1 month", length.out = 6))
        expected <- trend_reviews %>%
          filter(month_start >= window_start, month_start <= target_month) %>%
          summarise(value = sum(score_afinn) / n(), .groups = "drop") %>%
          pull(value)
        actual <- month_averages %>%
          filter(month_start == target_month) %>%
          pull(rolling_avg_6)
        if (length(actual) != 1 || !isTRUE(all.equal(actual, expected))) {
          stop(
            paste(
              "The 6-month rolling average must use calendar months.",
              "Expected", expected,
              "but got", paste(actual, collapse = ", ")
            )
          )
        }
        """
        try:
            result = subprocess.run(
                ["Rscript", "-e", r_code],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_trend_charts_average_length_normalized_afinn_scores(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        r_code = """
        source("04_visualization.R")
        required_columns <- c(
          "score_afinn_raw",
          "review_word_count",
          "median_review_word_count",
          "score_afinn_per_median_review"
        )
        missing_columns <- setdiff(required_columns, names(trend_reviews))
        if (length(missing_columns) > 0) {
          stop(paste("Missing normalized trend columns:", paste(missing_columns, collapse = ", ")))
        }

        monthly_check <- trend_reviews %>%
          group_by(month_start) %>%
          summarise(
            normalized_avg = mean(score_afinn_per_median_review, na.rm = TRUE),
            raw_avg = mean(score_afinn_raw, na.rm = TRUE),
            .groups = "drop"
          ) %>%
          filter(abs(normalized_avg - raw_avg) > 1e-6) %>%
          slice_head(n = 1)

        if (nrow(monthly_check) == 0) {
          stop("The fixture needs at least one month where raw and normalized AFINN differ.")
        }

        target_month <- monthly_check$month_start[[1]]
        expected <- monthly_check$normalized_avg[[1]]
        actual <- month_averages %>%
          filter(month_start == target_month) %>%
          pull(period_avg)

        if (length(actual) != 1 || !isTRUE(all.equal(actual, expected))) {
          stop(
            paste(
              "Trend charts must average median-review-normalized AFINN scores.",
              "Expected", expected,
              "but got", paste(actual, collapse = ", ")
            )
          )
        }
        """
        try:
            result = subprocess.run(
                ["Rscript", "-e", r_code],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_sentiment_period_summary_uses_robust_median_monitoring(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        r_code = """
        source("04_visualization.R")
        required_columns <- c(
          "period_type",
          "period_start",
          "period_label",
          "review_count",
          "median_review_word_count",
          "mean_afinn_raw",
          "median_afinn_raw",
          "trimmed_mean_afinn_raw",
          "mean_afinn_per_median_review",
          "median_afinn_per_median_review",
          "trimmed_mean_afinn_per_median_review",
          "historical_median_afinn_per_median_review",
          "historical_mad_afinn_per_median_review",
          "robust_z_afinn_median",
          "sentiment_drift_flag"
        )
        missing_columns <- setdiff(required_columns, names(sentiment_period_summary))
        if (length(missing_columns) > 0) {
          stop(paste("Missing period-monitoring columns:", paste(missing_columns, collapse = ", ")))
        }

        target_month <- sentiment_period_summary %>%
          filter(period_type == "month", review_count > 0) %>%
          slice_head(n = 1)
        if (nrow(target_month) != 1) {
          stop("The fixture needs at least one reviewed month.")
        }

        expected <- trend_reviews %>%
          filter(month_start == target_month$period_start[[1]]) %>%
          summarise(
            mean_afinn_per_median_review = mean(score_afinn_per_median_review, na.rm = TRUE),
            median_afinn_per_median_review = median(score_afinn_per_median_review, na.rm = TRUE),
            trimmed_mean_afinn_per_median_review = calculate_trimmed_mean(score_afinn_per_median_review),
            .groups = "drop"
          )

        actual_values <- target_month %>%
          select(
            mean_afinn_per_median_review,
            median_afinn_per_median_review,
            trimmed_mean_afinn_per_median_review
          )

        if (!isTRUE(all.equal(actual_values, expected, tolerance = 1e-6))) {
          stop("Period summary must use mean, median, and trimmed mean on median-review-normalized AFINN.")
        }

        if (!file.exists(sentiment_period_summary_path)) {
          stop("The period summary CSV was not written.")
        }
        if (!file.exists(sentiment_drift_monitor_path)) {
          stop("The robust drift monitor chart was not written.")
        }
        """
        try:
            result = subprocess.run(
                ["Rscript", "-e", r_code],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_aspect_text_alignment_uses_length_normalized_afinn_scores(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        r_code = """
        source("05_aspect_text_analysis.R")
        required_columns <- c("score_afinn_raw", "score_afinn_per_median_review")
        missing_columns <- setdiff(required_columns, names(aspect_reviews))
        if (length(missing_columns) > 0) {
          stop(paste("Missing normalized aspect columns:", paste(missing_columns, collapse = ", ")))
        }

        aspect_check <- aspect_reviews %>%
          filter(!is.na(aspect_rating), !is.na(score_afinn_per_median_review), !is.na(score_afinn_raw)) %>%
          group_by(aspect_key) %>%
          summarise(
            normalized_avg = mean(score_afinn_per_median_review, na.rm = TRUE),
            raw_avg = mean(score_afinn_raw, na.rm = TRUE),
            .groups = "drop"
          ) %>%
          filter(abs(normalized_avg - raw_avg) > 1e-6) %>%
          slice_head(n = 1)

        if (nrow(aspect_check) == 0) {
          stop("The fixture needs at least one aspect where raw and normalized AFINN differ.")
        }

        alignment <- readr::read_csv(
          file.path(reports_dir, "aspect_text_alignment.csv"),
          show_col_types = FALSE
        )
        actual <- alignment %>%
          filter(aspect_key == aspect_check$aspect_key[[1]]) %>%
          pull(mean_afinn_sentiment)
        expected <- round(aspect_check$normalized_avg[[1]], 3)

        if (length(actual) != 1 || !isTRUE(all.equal(actual, expected))) {
          stop(
            paste(
              "Aspect alignment must average length-normalized AFINN scores.",
              "Expected", expected,
              "but got", paste(actual, collapse = ", ")
            )
          )
        }
        """
        try:
            result = subprocess.run(
                ["Rscript", "-e", r_code],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_aspect_text_alignment_uses_length_normalized_syuzhet_scores(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        r_code = """
        source("05_aspect_text_analysis.R")
        required_columns <- c("score_syuzhet_raw", "score_syuzhet_per_median_review")
        missing_columns <- setdiff(required_columns, names(aspect_reviews))
        if (length(missing_columns) > 0) {
          stop(paste("Missing normalized Syuzhet aspect columns:", paste(missing_columns, collapse = ", ")))
        }

        aspect_check <- aspect_reviews %>%
          filter(!is.na(aspect_rating), !is.na(score_syuzhet_per_median_review), !is.na(score_syuzhet_raw)) %>%
          group_by(aspect_key) %>%
          summarise(
            normalized_avg = mean(score_syuzhet_per_median_review, na.rm = TRUE),
            raw_avg = mean(score_syuzhet_raw, na.rm = TRUE),
            .groups = "drop"
          ) %>%
          filter(abs(normalized_avg - raw_avg) > 1e-6) %>%
          slice_head(n = 1)

        if (nrow(aspect_check) == 0) {
          stop("The fixture needs at least one aspect where raw and normalized Syuzhet differ.")
        }

        alignment <- readr::read_csv(
          file.path(reports_dir, "aspect_text_alignment.csv"),
          show_col_types = FALSE
        )
        actual <- alignment %>%
          filter(aspect_key == aspect_check$aspect_key[[1]]) %>%
          pull(mean_syuzhet_sentiment)
        expected <- round(aspect_check$normalized_avg[[1]], 3)

        if (length(actual) != 1 || !isTRUE(all.equal(actual, expected))) {
          stop(
            paste(
              "Aspect alignment must average length-normalized Syuzhet scores.",
              "Expected", expected,
              "but got", paste(actual, collapse = ", ")
            )
          )
        }
        """
        try:
            result = subprocess.run(
                ["Rscript", "-e", r_code],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_aspect_phrase_mining_preserves_negated_complaints(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        r_code = """
        source("05_aspect_text_analysis.R")
        phrases <- readr::read_csv(
          file.path(reports_dir, "aspect_text_key_phrases.csv"),
          show_col_types = FALSE
        )
        expected_phrases <- c("not worth", "not recommend", "not cleaned", "no apology")
        missing_phrases <- setdiff(expected_phrases, phrases$term)
        if (length(missing_phrases) > 0) {
          stop(paste("Negated complaint phrases were dropped:", paste(missing_phrases, collapse = ", ")))
        }
        negated_rows <- phrases %>%
          filter(term %in% expected_phrases)
        if (any(negated_rows$term_sentiment != "negative")) {
          stop("Negated complaint phrases should be marked as negative terms.")
        }
        """
        try:
            result = subprocess.run(
                ["Rscript", "-e", r_code],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_aspect_rating_summary_names_percent_columns_as_percentages(self):
        with (PROJECT_ROOT / "output" / "reports" / "aspect_rating_summary.csv").open(
            newline="",
            encoding="utf-8",
        ) as handle:
            reader = csv.DictReader(handle)
            columns = reader.fieldnames
        self.assertIn("low_score_pct", columns)
        self.assertIn("very_low_score_pct", columns)
        self.assertNotIn("low_score_share", columns)
        self.assertNotIn("very_low_score_share", columns)

    def test_visualization_aspect_summary_uses_length_normalized_afinn_scores(self):
        temp_dir, project_copy = self.copy_project_for_workflow_test()
        r_code = """
        source("04_visualization.R")
        required_columns <- c("score_afinn_raw", "score_afinn_per_median_review")
        missing_columns <- setdiff(required_columns, names(aspect_data))
        if (length(missing_columns) > 0) {
          stop(paste("Missing normalized visualization aspect columns:", paste(missing_columns, collapse = ", ")))
        }
        compared_rows <- aspect_data %>%
          filter(!is.na(score_afinn_number), !is.na(score_afinn_per_median_review))
        if (nrow(compared_rows) == 0) {
          stop("The fixture needs at least one review with normalized AFINN.")
        }
        if (!isTRUE(all.equal(compared_rows$score_afinn_number, compared_rows$score_afinn_per_median_review))) {
          stop("Visualization aspect summaries must use length-normalized AFINN scores.")
        }
        """
        try:
            result = subprocess.run(
                ["Rscript", "-e", r_code],
                cwd=project_copy,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            shutil.rmtree(temp_dir)

    def test_rolling_average_regression_test_runs_in_temp_copy(self):
        test_source = (PROJECT_ROOT / "tests" / "test_data_wiring.py").read_text()
        method_start = test_source.index("def test_monthly_rolling_average_uses_calendar_months")
        method_end = test_source.index("def test_rolling_average_regression_test_runs_in_temp_copy", method_start)
        method_source = test_source[method_start:method_end]
        self.assertIn("project_copy", method_source)
        self.assertIn("copy_project_for_workflow_test", method_source)
        self.assertNotIn("cwd=PROJECT_ROOT", method_source)

    def test_data_readme_matches_tracked_analysis_output_policy(self):
        text = (PROJECT_ROOT / "data" / "README.md").read_text()
        self.assertNotIn("intentionally not tracked", text)
        self.assertIn("tracked", text)

    def test_colab_master_installs_required_r_packages(self):
        readme = (PROJECT_ROOT / "README.md").read_text()
        notebook = (PROJECT_ROOT / "Colab_Master_TripAdvisor.ipynb").read_text()
        self.assertNotIn("No Installation Required", readme)
        self.assertIn("No Local Installation Required", readme)
        self.assertIn("install.packages", notebook)
        self.assertIn("tidyverse", notebook)
        self.assertIn("wordcloud", notebook)

    def test_local_and_colab_package_installs_use_dated_cran_snapshot(self):
        readme = (PROJECT_ROOT / "README.md").read_text()
        notebook = (PROJECT_ROOT / "Colab_Master_TripAdvisor.ipynb").read_text()
        snapshot_url = "https://packagemanager.posit.co/cran/2026-05-26"
        self.assertIn(snapshot_url, readme)
        self.assertIn(snapshot_url, notebook)
        self.assertNotIn("cloud.r-project.org", notebook)

    def test_colab_setup_installs_required_packages_from_snapshot_even_if_present(self):
        notebook = json.loads((PROJECT_ROOT / "Colab_Master_TripAdvisor.ipynb").read_text())
        setup_cell = "".join(notebook["cells"][2]["source"])
        self.assertIn("install.packages(required_packages, repos = cran_snapshot_url)", setup_cell)
        self.assertNotIn("missing_packages <- setdiff(required_packages, installed_packages)", setup_cell)

    def test_readme_local_notebook_workflow_registers_r_kernel(self):
        readme = (PROJECT_ROOT / "README.md").read_text()
        self.assertIn("IRkernel", readme)
        self.assertIn("IRkernel::installspec", readme)

    def test_readme_explains_step_five_runs_as_script(self):
        readme = (PROJECT_ROOT / "README.md").read_text()
        self.assertIn("05_aspect_text_analysis.R", readme)
        self.assertIn("Rscript 05_aspect_text_analysis.R", readme)

    def test_colab_master_includes_step_five_and_embedded_support_files(self):
        text = (PROJECT_ROOT / "Colab_Master_TripAdvisor.ipynb").read_text()
        self.assertIn("Setup Shared Project Files", text)
        self.assertIn("scripts/data_config.R", text)
        self.assertIn("scripts/helpers.R", text)
        self.assertIn("Step 5: Aspect Text Analysis", text)
        self.assertIn("aspect_text_alignment.csv", text)

    def test_colab_setup_does_not_copy_unvalidated_root_upload(self):
        notebook = json.loads((PROJECT_ROOT / "Colab_Master_TripAdvisor.ipynb").read_text())
        setup_cell = "".join(notebook["cells"][2]["source"])
        self.assertNotIn('file.copy("reviews.csv", raw_reviews_path, overwrite = TRUE)', setup_cell)
        self.assertIn("Upload reviews.csv before running Step 1", setup_cell)

    def test_colab_setup_embeds_current_privacy_helper_rules(self):
        notebook = json.loads((PROJECT_ROOT / "Colab_Master_TripAdvisor.ipynb").read_text())
        setup_cell = "".join(notebook["cells"][2]["source"])
        self.assertIn('\\"author\\"', setup_cell)
        self.assertIn('\\"reviewer\\"', setup_cell)
        self.assertIn("direct_reviewer_identifier_columns <- c", setup_cell)

    def test_colab_step_one_validates_root_uploaded_reviews_csv_before_copying(self):
        notebook = json.loads((PROJECT_ROOT / "Colab_Master_TripAdvisor.ipynb").read_text())
        step_one_cell = "".join(notebook["cells"][4]["source"])
        self.assertIn('file.exists("reviews.csv")', step_one_cell)
        self.assertIn('file.copy("reviews.csv", raw_reviews_path, overwrite = TRUE)', step_one_cell)
        self.assertIn('validate_prepared_reviews("reviews.csv", announce = FALSE)', step_one_cell)
        self.assertIn('"author"', step_one_cell)
        self.assertIn('"reviewer"', step_one_cell)
        self.assertIn("forbidden source metadata", step_one_cell)
        self.assertIn("source_disclosure_pattern", step_one_cell)
        self.assertIn("source-disclosure", step_one_cell)
        self.assertIn("embedded_contact_pattern", step_one_cell)
        self.assertIn("scanned_columns <- names(reviews)", step_one_cell)
        self.assertIn("embedded contact markers in raw columns", step_one_cell)
        self.assertLess(
            step_one_cell.index('validate_prepared_reviews("reviews.csv", announce = FALSE)'),
            step_one_cell.index('file.copy("reviews.csv", raw_reviews_path, overwrite = TRUE)'),
        )

    def test_visualization_notebook_matches_visualization_script_sections(self):
        script_lines = (PROJECT_ROOT / "04_visualization.R").read_text().splitlines()
        script_block_count = sum(line.startswith("# =====================================================================") for line in script_lines) // 2
        notebook = (PROJECT_ROOT / "04_visualization.ipynb").read_text()
        notebook_code_cells = notebook.count('"cell_type": "code"')
        self.assertGreaterEqual(notebook_code_cells, script_block_count)
        self.assertIn("aspect_rating_columns", notebook)
        self.assertIn("aspect_mean_ratings.png", notebook)

    def test_notebook_updater_appends_extra_script_blocks(self):
        updater = (PROJECT_ROOT / "scripts" / "update_notebooks_eli5.R").read_text()
        self.assertIn("append_missing_code_cells", updater)
        self.assertNotIn("silently ignore extra script blocks", updater)

    def test_generated_notebooks_use_valid_execution_counts(self):
        for path in [
            "01_data_import.ipynb",
            "02_cleaning.ipynb",
            "03_sentiment_analysis.ipynb",
            "04_visualization.ipynb",
            "Colab_Master_TripAdvisor.ipynb",
        ]:
            with self.subTest(path=path):
                notebook = json.loads((PROJECT_ROOT / path).read_text())
                for cell in notebook["cells"]:
                    if cell["cell_type"] == "code":
                        execution_count = cell.get("execution_count")
                        self.assertTrue(
                            execution_count is None or isinstance(execution_count, int),
                            f"{path} has invalid execution_count {execution_count!r}",
                        )
                        self.assertIsInstance(
                            cell.get("metadata"),
                            dict,
                            f"{path} has invalid code-cell metadata {cell.get('metadata')!r}",
                        )

    def test_local_r_workspace_artifacts_are_absent(self):
        local_artifacts = [
            ".RData",
            ".Rhistory",
            ".Rproj.user",
            ".DS_Store",
            "output/.DS_Store",
        ]
        for path in local_artifacts:
            with self.subTest(path=path):
                self.assertFalse(
                    (PROJECT_ROOT / path).exists(),
                    f"{path} is a local session artifact and should not be kept in the checkout.",
                )

    def test_legacy_bvlgari_csv_paths_are_not_used_by_scripts(self):
        paths = [
            "01_data_import.R",
            "02_cleaning.R",
            "03_sentiment_analysis.R",
            "04_visualization.R",
            "05_aspect_text_analysis.R",
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
            "05_aspect_text_analysis.R",
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
            "05_aspect_text_analysis.R",
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

    def test_visualization_word_cloud_uses_only_sentiment_words(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn("sentiment_lexicon_words", script)
        self.assertIn("sentiment_word_counts", script)
        self.assertIn("domain_neutral_words", script)
        self.assertIn('syuzhet::get_sentiment(word, method = "afinn")', script)
        self.assertIn("filter(sentiment_score != 0)", script)
        self.assertIn("filter(!word %in% domain_neutral_words)", script)
        self.assertIn("ordered.colors = TRUE", script)
        self.assertNotRegex(script, r"(?m)^word_counts <- cleaned_tokens")

    def test_visualization_bins_sentiment_by_rating(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn("rating_group", script)
        self.assertIn("average_rating", script)
        self.assertIn("Sentiment Score Distribution by TripAdvisor Rating", script)
        self.assertIn("sentiment_by_rating_boxplot.png", script)
        self.assertIn("rating_average_line", script)
        self.assertIn("stat_summary", script)

    def test_afinn_comment_explains_review_scores_are_sums(self):
        script = (PROJECT_ROOT / "03_sentiment_analysis.R").read_text()
        self.assertIn("word-level", script)
        self.assertIn("summed review score", script)

    def test_visualization_uses_structured_aspect_rating_outputs(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn("aspect_rating_columns", script)
        self.assertIn("value_rating", script)
        self.assertIn("rooms_rating", script)
        self.assertIn("cleanliness_rating", script)
        self.assertIn("service_rating", script)
        self.assertIn("sleep_quality_rating", script)
        self.assertIn("aspect_rating_summary.csv", script)
        self.assertIn("high_overall_low_aspect_reviews.csv", script)
        self.assertIn("aspect_mean_ratings.png", script)
        self.assertIn("aspect_low_score_share.png", script)
        self.assertIn("aspect_yearly_rating_heatmap.png", script)

    def test_visualization_uses_monthly_trend_charts_and_period_boxplots(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn("Monthly Sentiment Heatmap", script)
        self.assertIn("Monthly Sentiment Trend with Rolling Average", script)
        self.assertIn("Quarterly Sentiment Distribution", script)
        self.assertIn("Yearly Sentiment Distribution", script)
        self.assertIn("sentiment_trend_monthly_heatmap.png", script)
        self.assertIn("sentiment_trend_monthly_rolling.png", script)
        self.assertIn("sentiment_drift_monitor.png", script)
        self.assertIn("sentiment_period_summary.csv", script)
        self.assertIn("sentiment_trend_quarterly.png", script)
        self.assertIn("sentiment_trend_yearly.png", script)
        self.assertIn("period_avg", script)
        self.assertIn("prior_avg", script)
        self.assertIn("rolling_avg_6", script)
        self.assertIn("calculate_robust_z", script)
        self.assertIn("period_trimmed_mean", script)
        self.assertIn("stats_label_y", script)
        self.assertIn("period_median", script)
        self.assertIn("period_q1", script)
        self.assertIn("period_q3", script)
        self.assertIn("period_min", script)
        self.assertIn("period_max", script)
        self.assertIn("n_outliers", script)
        self.assertNotIn("Series avg:", script)

    def test_visualization_writes_annual_review_profile_with_location_and_rating_distribution(self):
        script = (PROJECT_ROOT / "04_visualization.R").read_text()
        self.assertIn("Annual Review Profile", script)
        self.assertIn("annual_review_profile_path", script)
        self.assertIn("reviewer_location", script)
        self.assertIn("regions_with_minimum_reviews", script)
        self.assertIn("rating_5_star_reviews", script)
        self.assertIn("rating_1_star_reviews", script)

        with (PROJECT_ROOT / "output" / "reports" / "annual_review_profile.csv").open(
            newline="", encoding="utf-8"
        ) as handle:
            rows = list(csv.DictReader(handle))

        self.assertTrue(rows)
        self.assertEqual(rows[-1]["year"], "Total")
        self.assertEqual(rows[-1]["review_count"], "762")
        self.assertEqual(rows[-1]["rating_5_star_reviews"], "596")
        self.assertEqual(rows[-1]["rating_1_star_reviews"], "29")
        self.assertIn("Singapore, Singapore", rows[-1]["regions_with_minimum_reviews"])

    def test_aspect_text_analysis_links_aspects_to_review_text(self):
        script = (PROJECT_ROOT / "05_aspect_text_analysis.R").read_text()
        self.assertIn("aspect_text_alignment.csv", script)
        self.assertIn("aspect_text_band_summary.csv", script)
        self.assertIn("aspect_text_key_terms.csv", script)
        self.assertIn("aspect_text_key_phrases.csv", script)
        self.assertIn("aspect_text_mismatches.csv", script)
        self.assertIn("aspect_qualitative_examples.csv", script)
        self.assertIn("aspect_sentiment_by_rating_boxplot.png", script)
        self.assertIn("aspect_low_score_key_terms.png", script)
        self.assertIn("aspect_low_score_key_phrases.png", script)
        self.assertIn("aspect_negative_term_heatmap.png", script)
        self.assertIn("aspect_text_mismatch_counts.png", script)
        self.assertIn("Low aspect score (1-3)", script)
        self.assertIn("High aspect score (4-5)", script)
        self.assertIn("build_term_comparison", script)
        self.assertIn("low_aspect_positive_text", script)
        self.assertIn("high_aspect_negative_text", script)

    def test_master_workflow_runs_aspect_text_analysis_after_visualization(self):
        script = (PROJECT_ROOT / "Master_TripAdvisor.R").read_text()
        self.assertIn('source("04_visualization.R")', script)
        self.assertIn('source("05_aspect_text_analysis.R")', script)
        self.assertLess(
            script.index('source("04_visualization.R")'),
            script.index('source("05_aspect_text_analysis.R")'),
        )


if __name__ == "__main__":
    unittest.main()
