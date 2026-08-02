#' Data Validation Framework
#' 
#' Schema validation, data quality checks, and constraint enforcement.

library(data.table)

#' Validation result structure
#' @param passed Logical
#' @param checks List of individual check results
#' @param summary Character summary
validation_result <- function(passed, checks, summary = "") {
  structure(
    list(
      passed = passed,
      checks = checks,
      summary = summary,
      timestamp = Sys.time()
    ),
    class = "validation_result"
  )
}

#' Validate data against schema
#' @param dt data.table
#' @param schema List with column specifications
#' @return validation_result
validate_schema <- function(dt, schema) {
  checks <- list()
  all_passed <- TRUE
  
  required_cols <- names(schema)
  missing_cols <- setdiff(required_cols, names(dt))
  
  if (length(missing_cols) > 0) {
    checks[["schema_columns"]] <- list(
      passed = FALSE,
      message = paste("Missing columns:", paste(missing_cols, collapse = ", "))
    )
    all_passed <- FALSE
  } else {
    checks[["schema_columns"]] <- list(
      passed = TRUE,
      message = paste("All", length(required_cols), "required columns present")
    )
  }
  
  type_errors <- list()
  for (col in required_cols) {
    if (col %in% names(dt)) {
      expected_type <- schema[[col]]$type
      actual_type <- class(dt[[col]])[1]
      
      type_ok <- switch(expected_type,
                        "integer" = is.integer(dt[[col]]) || is.numeric(dt[[col]]),
                        "numeric" = is.numeric(dt[[col]]),
                        "character" = is.character(dt[[col]]),
                        "factor" = is.factor(dt[[col]]) || is.character(dt[[col]]),
                        "Date" = inherits(dt[[col]], "Date"),
                        "POSIXct" = inherits(dt[[col]], "POSIXct"),
                        TRUE
      )
      
      if (!type_ok) {
        type_errors[[col]] <- sprintf("Expected %s, got %s", expected_type, actual_type)
      }
    }
  }
  
  if (length(type_errors) > 0) {
    checks[["schema_types"]] <- list(
      passed = FALSE,
      message = paste(unlist(type_errors), collapse = "; ")
    )
    all_passed <- FALSE
  } else {
    checks[["schema_types"]] <- list(
      passed = TRUE,
      message = "All column types match schema"
    )
  }
  
  validation_result(
    passed = all_passed,
    checks = checks,
    summary = ifelse(all_passed, "Schema validation passed", "Schema validation failed")
  )
}

#' Validate data quality constraints
#' @param dt data.table
#' @param constraints List of constraint specifications
#' @return validation_result
validate_constraints <- function(dt, constraints) {
  checks <- list()
  all_passed <- TRUE
  
  if (!is.null(constraints$not_null)) {
    for (col in constraints$not_null) {
      if (col %in% names(dt)) {
        null_count <- sum(is.na(dt[[col]]) | dt[[col]] == "")
        null_pct <- null_count / nrow(dt) * 100
        
        if (null_pct > 0) {
          checks[[paste0("not_null_", col)]] <- list(
            passed = FALSE,
            message = sprintf("%s: %.2f%% null values", col, null_pct)
          )
          all_passed <- FALSE
        } else {
          checks[[paste0("not_null_", col)]] <- list(
            passed = TRUE,
            message = sprintf("%s: no null values", col)
          )
        }
      }
    }
  }
  
  if (!is.null(constraints$range)) {
    for (col in names(constraints$range)) {
      if (col %in% names(dt) && is.numeric(dt[[col]])) {
        range <- constraints$range[[col]]
        min_val <- range$min
        max_val <- range$max
        out_of_range <- sum(dt[[col]] < min_val | dt[[col]] > max_val, na.rm = TRUE)
        
        if (out_of_range > 0) {
          checks[[paste0("range_", col)]] <- list(
            passed = FALSE,
            message = sprintf("%s: %d values out of range [%.2f, %.2f]", col, out_of_range, min_val, max_val)
          )
          all_passed <- FALSE
        } else {
          checks[[paste0("range_", col)]] <- list(
            passed = TRUE,
            message = sprintf("%s: all values in range", col)
          )
        }
      }
    }
  }
  
  if (!is.null(constraints$unique)) {
    for (col in constraints$unique) {
      if (col %in% names(dt)) {
        dupes <- nrow(dt) - uniqueN(dt[[col]])
        if (dupes > 0) {
          checks[[paste0("unique_", col)]] <- list(
            passed = FALSE,
            message = sprintf("%s: %d duplicate values", col, dupes)
          )
          all_passed <- FALSE
        } else {
          checks[[paste0("unique_", col)]] <- list(
            passed = TRUE,
            message = sprintf("%s: all values unique", col)
          )
        }
      }
    }
  }
  
  if (!is.null(constraints$min_rows)) {
    if (nrow(dt) < constraints$min_rows) {
      checks[["min_rows"]] <- list(
        passed = FALSE,
        message = sprintf("Row count %d below minimum %d", nrow(dt), constraints$min_rows)
      )
      all_passed <- FALSE
    } else {
      checks[["min_rows"]] <- list(
        passed = TRUE,
        message = sprintf("Row count %d meets minimum %d", nrow(dt), constraints$min_rows)
      )
    }
  }
  
  validation_result(
    passed = all_passed,
    checks = checks,
    summary = ifelse(all_passed, "Constraint validation passed", "Constraint validation failed")
  )
}

#' Print validation result
#' @param x validation_result
#' @param ... Additional arguments
print.validation_result <- function(x, ...) {
  cat("Validation Result:", x$summary, "\n")
  cat("Timestamp:", format(x$timestamp), "\n")
  cat("Checks:\n")
  for (name in names(x$checks)) {
    check <- x$checks[[name]]
    status <- ifelse(check$passed, "[PASS]", "[FAIL]")
    cat("  ", status, name, "-", check$message, "\n")
  }
  invisible(x)
}

#' Assert validation passed
#' @param result validation_result
#' @param stop_on_error If TRUE, stop execution on failure
assert_validation <- function(result, stop_on_error = TRUE) {
  if (!result$passed && stop_on_error) {
    stop("Validation failed: ", result$summary)
  }
  invisible(result$passed)
}