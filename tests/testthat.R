library(testthat)
library(data.table)

# Load all R modules
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

test_dir("tests", reporter = "progress")