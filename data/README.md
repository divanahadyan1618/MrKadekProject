# Data Files

The prepared raw review CSV is tracked in git so the project can run without
collecting new data. Generated cleaned data files are intentionally not tracked.

The raw source file is `data/raw/reviews.csv`. Run Step 1 to validate that the
CSV is present and has the expected columns:

```r
source("01_data_import.R")
```

Steps 2 and 3 write cleaned and sentiment-scored CSV files under
`data/cleaned/`.
