# Project-local R configuration

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Memory management for 4GB systems
options(
  # Reduce garbage collection threshold
  gc.bytes.limit = 500 * 1024 * 1024,  # 500MB
  
  # Limit data.table threads
  datatable.alloccol = 1024,
  
  # Reduce connection buffer
  download.file.method = "libcurl",
  
  # Disable fancy quotes for logs
  useFancyQuotes = FALSE
)

# Initialize renv
source("renv/activate.R")

# Welcome message
message("Data Engineering Pipeline")
message("Profile: ", Sys.getenv("R_CONFIG_PROFILE", "dev"))
message("Working directory: ", getwd())
