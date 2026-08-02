# Project-local R configuration

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Memory management for 4GB systems
options(
  gc.bytes.limit = 500 * 1024 * 1024,
  datatable.alloccol = 1024,
  download.file.method = "libcurl",
  useFancyQuotes = FALSE
)

# Initialize renv only if it exists
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# Welcome message
message("Data Engineering Pipeline")
message("Profile: ", Sys.getenv("R_CONFIG_PROFILE", "dev"))
message("Working directory: ", getwd())
