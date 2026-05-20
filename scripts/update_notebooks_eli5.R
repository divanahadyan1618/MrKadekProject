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

# 1. Update 01_data_import.ipynb
blocks_01 <- split_r_script("01_data_import.R")
nb_01 <- fromJSON("01_data_import.ipynb", simplifyVector = FALSE)
code_idx <- 1
for (i in seq_along(nb_01$cells)) {
  if (nb_01$cells[[i]]$cell_type == "code") {
    if (code_idx <= length(blocks_01)) {
      # Add \n to all lines except last for jupyter format
      lines <- strsplit(blocks_01[[code_idx]], "\n")[[1]]
      if (length(lines) > 0) {
        if(length(lines) > 1) {
          lines[1:(length(lines)-1)] <- paste0(lines[1:(length(lines)-1)], "\n")
        }
        nb_01$cells[[i]]$source <- as.list(lines)
      }
      code_idx <- code_idx + 1
    }
  }
}
write_json(nb_01, "01_data_import.ipynb", auto_unbox = TRUE, pretty = TRUE)

# 2. Update 02_cleaning.ipynb
blocks_02 <- split_r_script("02_cleaning.R")
nb_02 <- fromJSON("02_cleaning.ipynb", simplifyVector = FALSE)
code_idx <- 1
for (i in seq_along(nb_02$cells)) {
  if (nb_02$cells[[i]]$cell_type == "code") {
    if (code_idx <= length(blocks_02)) {
      lines <- strsplit(blocks_02[[code_idx]], "\n")[[1]]
      if (length(lines) > 0) {
        if(length(lines) > 1) {
          lines[1:(length(lines)-1)] <- paste0(lines[1:(length(lines)-1)], "\n")
        }
        nb_02$cells[[i]]$source <- as.list(lines)
      }
      code_idx <- code_idx + 1
    }
  }
}
write_json(nb_02, "02_cleaning.ipynb", auto_unbox = TRUE, pretty = TRUE)

# 3. Update 03_sentiment_analysis.ipynb
blocks_03 <- split_r_script("03_sentiment_analysis.R")
nb_03 <- fromJSON("03_sentiment_analysis.ipynb", simplifyVector = FALSE)
code_idx <- 1
for (i in seq_along(nb_03$cells)) {
  if (nb_03$cells[[i]]$cell_type == "code") {
    if (code_idx <= length(blocks_03)) {
      lines <- strsplit(blocks_03[[code_idx]], "\n")[[1]]
      if (length(lines) > 0) {
        if(length(lines) > 1) {
          lines[1:(length(lines)-1)] <- paste0(lines[1:(length(lines)-1)], "\n")
        }
        nb_03$cells[[i]]$source <- as.list(lines)
      }
      code_idx <- code_idx + 1
    }
  }
}
write_json(nb_03, "03_sentiment_analysis.ipynb", auto_unbox = TRUE, pretty = TRUE)

# 4. Update 04_visualization.ipynb
blocks_04 <- split_r_script("04_visualization.R")
nb_04 <- fromJSON("04_visualization.ipynb", simplifyVector = FALSE)
code_idx <- 1
for (i in seq_along(nb_04$cells)) {
  if (nb_04$cells[[i]]$cell_type == "code") {
    if (code_idx <= length(blocks_04)) {
      lines <- strsplit(blocks_04[[code_idx]], "\n")[[1]]
      if (length(lines) > 0) {
        if(length(lines) > 1) {
          lines[1:(length(lines)-1)] <- paste0(lines[1:(length(lines)-1)], "\n")
        }
        nb_04$cells[[i]]$source <- as.list(lines)
      }
      code_idx <- code_idx + 1
    }
  }
}
write_json(nb_04, "04_visualization.ipynb", auto_unbox = TRUE, pretty = TRUE)

cat("All notebooks successfully updated with ELI5 commented code blocks!\n")
