context("Validation")

test_that("validate_schema checks columns", {
  dt <- data.table(a = 1:3, b = letters[1:3])
  schema <- list(a = list(type = "integer"), b = list(type = "character"), c = list(type = "numeric"))
  
  result <- validate_schema(dt, schema)
  expect_false(result$passed)
  expect_false(result$checks$schema_columns$passed)
})

test_that("validate_schema checks types", {
  dt <- data.table(a = 1:3, b = letters[1:3])
  schema <- list(a = list(type = "integer"), b = list(type = "character"))
  
  result <- validate_schema(dt, schema)
  expect_true(result$passed)
})

test_that("validate_constraints checks nulls", {
  dt <- data.table(a = c(1, NA, 3), b = letters[1:3])
  constraints <- list(not_null = "a")
  
  result <- validate_constraints(dt, constraints)
  expect_false(result$passed)
})

test_that("validate_constraints checks range", {
  dt <- data.table(a = c(1, 50, 100))
  constraints <- list(range = list(a = list(min = 0, max = 10)))
  
  result <- validate_constraints(dt, constraints)
  expect_false(result$passed)
})