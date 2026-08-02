library(testthat)
library(data.table)

# Load all R modules from project root
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Run all test files in tests/ directory
test_files <- list.files("tests", pattern = "^test-.*\\.R$", full.names = TRUE)
for (f in test_files) {
  test_file(f, reporter = "progress")
}
