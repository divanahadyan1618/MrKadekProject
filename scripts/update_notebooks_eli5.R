library(jsonlite)

# Helper function to read a file and split it by STEP headers
split_r_script <- function(file_path) {
  content <- readLines(file_path, warn = FALSE)
  
  # Find indices of step boundaries
  step_indices <- grep("^# =====================================================================", content)
  
  blocks <- list()
  if(length(step_indices) < 2) return(blocks)
  
  # Group every two step_indices bounds (the top and bottom of the banner) as the start of a block
  # Actually, the format is:
  # # ========
  # # STEP N: ...
  # # ========
  # Code...
  
  step_starts <- step_indices[seq(1, length(step_indices), by=2)]
  
  for(i in seq_along(step_starts)) {
    start_idx <- step_starts[i]
    end_idx <- ifelse(i < length(step_starts), step_starts[i+1] - 1, length(content))
    block <- content[start_idx:end_idx]
    
    # Clean up empty lines at the end of block
    while(length(block) > 0 && block[length(block)] == "") {
      block <- block[-length(block)]
    }
    
    # Join with newlines and add trailing newline for JSON arrays
    block_str <- paste(block, collapse="\n")
    blocks[[i]] <- block_str
  }
  return(blocks)
}

# jsonlite writes a plain empty R list as [] in JSON. Notebook metadata needs
# {}, so this named empty list is used whenever we mean "empty JSON object".
empty_json_object <- function() {
  structure(list(), names = character(0))
}

# A notebook code cell is a small list in the .ipynb JSON file.
# This helper creates an empty code cell when a script has grown and the
# notebook does not yet have enough cells for every script block.
new_code_cell <- function() {
  list(
    cell_type = "code",
    execution_count = NA,
    metadata = empty_json_object(),
    outputs = list(),
    source = list()
  )
}

# Jupyter stores code as a list of lines. Every line except the last should end
# with \n so the notebook shows the same line breaks as the R script.
block_to_notebook_lines <- function(block) {
  lines <- strsplit(block, "\n")[[1]]
  if (length(lines) > 1) {
    lines[1:(length(lines) - 1)] <- paste0(lines[1:(length(lines) - 1)], "\n")
  }
  as.list(lines)
}

# Read a whole R script as one text block. The Colab master notebook needs this
# when a full script should live inside a single notebook code cell.
read_script_as_block <- function(script_path) {
  paste(readLines(script_path, warn = FALSE), collapse = "\n")
}

# If a script has more blocks than the notebook has code cells, add cells
# instead of losing the extra blocks.
append_missing_code_cells <- function(notebook, required_code_cells) {
  current_code_cells <- sum(vapply(notebook$cells, function(cell) cell$cell_type == "code", logical(1)))
  missing_code_cells <- required_code_cells - current_code_cells

  if (missing_code_cells > 0) {
    for (cell_number in seq_len(missing_code_cells)) {
      notebook$cells[[length(notebook$cells) + 1]] <- new_code_cell()
    }
  }

  notebook
}

# This copies each script block into the matching notebook code cell.
# Existing markdown cells are left alone.
sync_notebook_code_cells <- function(notebook, blocks) {
  notebook <- append_missing_code_cells(notebook, length(blocks))
  code_idx <- 1

  for (i in seq_along(notebook$cells)) {
    if (notebook$cells[[i]]$cell_type == "code" && code_idx <= length(blocks)) {
      notebook$cells[[i]]$execution_count <- NA
      if (length(notebook$cells[[i]]$metadata) == 0) {
        notebook$cells[[i]]$metadata <- empty_json_object()
      }
      notebook$cells[[i]]$outputs <- list()
      notebook$cells[[i]]$source <- block_to_notebook_lines(blocks[[code_idx]])
      code_idx <- code_idx + 1
    }
  }

  notebook
}

# Rewrite a notebook so it has exactly the code cells we expect.
# Regular notebooks keep extra markdown, but the Colab master is generated from
# scripts. Dropping old extra code cells prevents stale workflow code from hiding
# later in the notebook.
sync_notebook_code_cells_exactly <- function(notebook, blocks) {
  code_idx <- 1
  synced_cells <- list()

  for (i in seq_along(notebook$cells)) {
    current_cell <- notebook$cells[[i]]

    # Markdown cells are explanatory text, so keep them exactly as they are.
    if (!isTRUE(current_cell$cell_type == "code")) {
      synced_cells[[length(synced_cells) + 1]] <- current_cell
      next
    }

    # If the old notebook has more code cells than the current script requires,
    # skip the extras instead of copying stale code into the new notebook.
    if (code_idx > length(blocks)) {
      next
    }

    # Replace the old code cell with the matching current script block.
    current_cell$execution_count <- NA
    if (length(current_cell$metadata) == 0) {
      current_cell$metadata <- empty_json_object()
    }
    current_cell$outputs <- list()
    current_cell$source <- block_to_notebook_lines(blocks[[code_idx]])
    synced_cells[[length(synced_cells) + 1]] <- current_cell
    code_idx <- code_idx + 1
  }

  # If the current scripts grew, add new code cells at the end so no section is
  # lost from the generated notebook.
  while (code_idx <= length(blocks)) {
    current_cell <- new_code_cell()
    current_cell$source <- block_to_notebook_lines(blocks[[code_idx]])
    synced_cells[[length(synced_cells) + 1]] <- current_cell
    code_idx <- code_idx + 1
  }

  notebook$cells <- synced_cells
  notebook
}

update_notebook_from_script <- function(script_path, notebook_path) {
  blocks <- split_r_script(script_path)
  notebook <- fromJSON(notebook_path, simplifyVector = FALSE)
  notebook <- sync_notebook_code_cells(notebook, blocks)
  write_json(notebook, notebook_path, auto_unbox = TRUE, pretty = TRUE, na = "null")
}

# R code can write project files inside Google Colab, but each file line has to
# be represented as a quoted string. This helper turns a local file into a
# writeLines(...) call that can safely recreate that file inside the notebook.
file_to_colab_write_call <- function(file_path) {
  file_lines <- readLines(file_path, warn = FALSE)
  quoted_lines <- vapply(file_lines, encodeString, character(1), quote = "\"")
  indented_lines <- paste0("  ", quoted_lines, collapse = ",\n")

  paste(
    "writeLines(",
    "  c(",
    indented_lines,
    "  ),",
    paste0("  \"", file_path, "\""),
    ")",
    sep = "\n"
  )
}

build_colab_setup_cell <- function() {
  paste(
    "# =====================================================================",
    "# Setup Shared Project Files",
    "# =====================================================================",
    "# Google Colab starts with an empty working folder. This cell installs the",
    "# R packages used by the project, then creates the same folders and helper",
    "# files that the local project uses.",
    "",
    "required_packages <- c(",
    "  \"tidyverse\",",
    "  \"tidytext\",",
    "  \"syuzhet\",",
    "  \"wordcloud\",",
    "  \"RColorBrewer\",",
    "  \"lubridate\",",
    "  \"jsonlite\"",
    ")",
    "",
    "# Use a dated CRAN snapshot so rerunning the notebook uses stable package versions.",
    "# Colab often preinstalls some packages, so install the full required set from",
    "# the snapshot instead of only installing packages that appear to be missing.",
    "cran_snapshot_url <- \"https://packagemanager.posit.co/cran/2026-05-26\"",
    "install.packages(required_packages, repos = cran_snapshot_url)",
    "",
    "dir.create(\"scripts\", recursive = TRUE, showWarnings = FALSE)",
    "dir.create(file.path(\"data\", \"raw\"), recursive = TRUE, showWarnings = FALSE)",
    "dir.create(file.path(\"data\", \"cleaned\"), recursive = TRUE, showWarnings = FALSE)",
    "dir.create(file.path(\"output\", \"figures\"), recursive = TRUE, showWarnings = FALSE)",
    "dir.create(file.path(\"output\", \"reports\"), recursive = TRUE, showWarnings = FALSE)",
    "",
    file_to_colab_write_call("scripts/data_config.R"),
    "",
    file_to_colab_write_call("scripts/helpers.R"),
    "",
    "cat(\"Colab setup complete. Upload reviews.csv before running Step 1, or place the same file at data/raw/reviews.csv.\\n\")",
    sep = "\n"
  )
}

find_code_cell_by_text <- function(notebook, search_text) {
  cell_matches <- vapply(
    notebook$cells,
    function(cell) {
      isTRUE(cell$cell_type == "code") &&
        grepl(search_text, paste(unlist(cell$source), collapse = ""), fixed = TRUE)
    },
    logical(1)
  )

  matching_cells <- which(cell_matches)
  if (length(matching_cells) != 1) {
    stop(
      paste(
        "Expected exactly one Colab code cell containing:",
        search_text
      ),
      call. = FALSE
    )
  }

  matching_cells
}

update_colab_master_notebook <- function(notebook_path) {
  notebook <- fromJSON(notebook_path, simplifyVector = FALSE)
  colab_blocks <- list(build_colab_setup_cell())

  # The master Colab notebook should contain every script section in order:
  # setup first, then Step 1 through Step 5.
  for (script_path in c(
    "01_data_import.R",
    "02_cleaning.R",
    "03_sentiment_analysis.R",
    "04_visualization.R",
    "05_aspect_text_analysis.R"
  )) {
    colab_blocks <- c(colab_blocks, split_r_script(script_path))
  }

  # The master notebook has one code cell per script section. Rewrite those cells
  # from the current scripts and drop any older extra code cells so stale code
  # cannot remain in the Colab workflow.
  notebook <- sync_notebook_code_cells_exactly(notebook, colab_blocks)

  # Some older notebook cells used {} for execution_count, which is not valid
  # Jupyter metadata. Reset all Colab code counts so the notebook opens cleanly.
  for (cell_index in seq_along(notebook$cells)) {
    if (isTRUE(notebook$cells[[cell_index]]$cell_type == "code")) {
      notebook$cells[[cell_index]]$execution_count <- NA
      if (length(notebook$cells[[cell_index]]$metadata) == 0) {
        notebook$cells[[cell_index]]$metadata <- empty_json_object()
      }
    }
  }

  write_json(notebook, notebook_path, auto_unbox = TRUE, pretty = TRUE, na = "null")
}

update_notebook_from_script("01_data_import.R", "01_data_import.ipynb")
update_notebook_from_script("02_cleaning.R", "02_cleaning.ipynb")
update_notebook_from_script("03_sentiment_analysis.R", "03_sentiment_analysis.ipynb")
update_notebook_from_script("04_visualization.R", "04_visualization.ipynb")
update_colab_master_notebook("Colab_Master_TripAdvisor.ipynb")

cat("All notebooks successfully updated with ELI5 commented code blocks!\n")
