context("ETL Operations")

test_that("transform_clean standardizes names", {
  dt <- data.table(`Bad Name` = 1:3, `Another-Bad` = letters[1:3])
  cfg <- list()
  result <- transform_clean(dt, cfg)
  expect_true(all(grepl("^[a-z_]+$", names(result))))
})

test_that("transform_clean removes empty rows", {
  dt <- data.table(a = c(1, NA, 3), b = c("x", NA, "z"))
  cfg <- list()
  result <- transform_clean(dt, cfg)
  expect_equal(nrow(result), 2)
})

test_that("transform_clean adds audit columns", {
  dt <- data.table(a = 1:3)
  cfg <- list()
  result <- transform_clean(dt, cfg)
  expect_true("_loaded_at" %in% names(result))
  expect_true("_source_file" %in% names(result))
})