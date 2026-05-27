# Data Files

The prepared raw review CSV and generated analysis outputs are tracked in git so
the project can run, be reviewed, and be graded without regenerating every file
first.

The raw source file is `data/raw/reviews.csv`. Run Step 1 to validate that the
CSV is present and has the expected columns:

```r
source("01_data_import.R")
```

Steps 2 and 3 write cleaned and sentiment-scored CSV files under
`data/cleaned/`. These cleaned CSV files are tracked because they are part of
the reproducible analysis output.

Steps 4 and 5 write charts and report tables under `output/figures/` and
`output/reports/`. Those files are also tracked so readers can inspect the
project results without rerunning the full workflow.
