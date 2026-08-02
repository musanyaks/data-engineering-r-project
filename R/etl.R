#' ETL Pipeline Functions
#' 
#' Memory-efficient extract, transform, load operations.

library(data.table)
if (requireNamespace("arrow", quietly = TRUE)) library(arrow)

#' Extract data from CSV with memory monitoring
#' @param file_path Path to CSV file
#' @param config Configuration list
#' @param select_cols Columns to load (NULL = all)
#' @param nrows Max rows to read (NULL = all)
#' @return data.table
extract_csv <- function(file_path, config, select_cols = NULL, nrows = NULL) {
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }
  
  flog.info("Extracting CSV: %s", file_path)
  log_memory("before_extract")
  
  file_size <- file.info(file_path)$size
  if (file_size > 500 * 1024 * 1024) {
    flog.warn("Large file detected (%.0f MB). Consider chunked processing.", file_size / (1024*1024))
  }
  
  args <- list(
    file = file_path,
    select = select_cols,
    showProgress = FALSE,
    verbose = FALSE
  )
  if (!is.null(nrows)) {
    args$nrows <- nrows
  }
  
  dt <- do.call(data.table::fread, args)
  
  flog.info("Extracted %d rows, %d columns", nrow(dt), ncol(dt))
  log_memory("after_extract")
  dt
}

#' Extract from Parquet (memory-efficient via Arrow)
#' @param file_path Path to parquet file
#' @param config Configuration list
#' @param columns Columns to select
#' @return Arrow Table or data.table
extract_parquet <- function(file_path, config, columns = NULL) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' is required for Parquet files. Install with: install.packages('arrow')")
  }
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }
  
  flog.info("Extracting Parquet: %s", file_path)
  ds <- arrow::read_parquet(
    file_path,
    col_select = columns,
    as_data_frame = FALSE
  )
  
  flog.info("Extracted Parquet: %s rows, %s columns", ds$num_rows, ds$num_columns)
  ds
}

#' Transform: Clean and standardize data
#' @param dt data.table
#' @param config Configuration list
#' @return data.table
transform_clean <- function(dt, config) {
  flog.info("Starting clean transform on %d rows", nrow(dt))
  log_memory("before_transform")
  
  dt <- dt[rowSums(is.na(dt)) < ncol(dt)]
  
  old_names <- names(dt)
  new_names <- tolower(gsub("[^a-zA-Z0-9]", "_", old_names))
  new_names <- make.names(new_names, unique = TRUE)
  setnames(dt, old_names, new_names)
  
  na_strategy <- get_config(config, "etl.na_strategy", "ignore")
  
  if (na_strategy == "drop") {
    dt <- na.omit(dt)
  } else if (na_strategy == "fill") {
    fill_value <- get_config(config, "etl.na_fill_value", 0)
    for (col in names(dt)) {
      if (is.numeric(dt[[col]])) {
        set(dt, which(is.na(dt[[col]])), col, fill_value)
      }
    }
  }
  
  if (get_config(config, "etl.remove_duplicates", TRUE)) {
    before <- nrow(dt)
    dt <- unique(dt)
    flog.info("Removed %d duplicate rows", before - nrow(dt))
  }
  
  dt[, `_loaded_at` := Sys.time()]
  dt[, `_source_file` := get_config(config, "etl.source_file", NA_character_)]
  
  flog.info("Clean transform complete: %d rows, %d columns", nrow(dt), ncol(dt))
  log_memory("after_transform")
  dt
}

#' Transform: Aggregate with memory efficiency
#' @param dt data.table
#' @param by_cols Grouping columns
#' @param agg_cols Aggregation specification list
#' @return data.table
transform_aggregate <- function(dt, by_cols, agg_cols) {
  flog.info("Aggregating by: %s", paste(by_cols, collapse = ", "))
  
  agg_exprs <- lapply(names(agg_cols), function(name) {
    col <- agg_cols[[name]]
    func <- col$func
    target <- col$column
    
    if (func == "sum") {
      as.call(list(quote(sum), as.name(target), na.rm = TRUE))
    } else if (func == "mean") {
      as.call(list(quote(mean), as.name(target), na.rm = TRUE))
    } else if (func == "count") {
      quote(.N)
    } else if (func == "max") {
      as.call(list(quote(max), as.name(target), na.rm = TRUE))
    } else if (func == "min") {
      as.call(list(quote(min), as.name(target), na.rm = TRUE))
    } else {
      stop("Unknown aggregation function: ", func)
    }
  })
  
  names(agg_exprs) <- names(agg_cols)
  result <- dt[, eval(agg_exprs), by = by_cols]
  
  flog.info("Aggregation complete: %d groups", nrow(result))
  result
}

#' Load data to DuckDB
#' @param conn DB connection
#' @param dt data.table
#' @param table_name Target table
#' @param batch_size Batch size for writes
#' @param overwrite Overwrite existing table
load_to_duckdb <- function(conn, dt, table_name, batch_size = 50000, overwrite = TRUE) {
  flog.info("Loading to DuckDB table: %s", table_name)
  log_memory("before_load")
  
  write_table_batch(conn, table_name, dt, batch_size = batch_size, overwrite = overwrite)
  
  row_count <- table_row_count(conn, table_name)
  flog.info("Load complete: %d rows in %s", row_count, table_name)
  log_memory("after_load")
  invisible(row_count)
}

#' Load data to Parquet (partitioned)
#' @param dt data.table or Arrow Table
#' @param file_path Output path
#' @param partition_cols Columns to partition by
#' @param compression Compression codec
load_to_parquet <- function(dt, file_path, partition_cols = NULL, compression = "zstd") {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' is required for Parquet output. Install with: install.packages('arrow')")
  }
  flog.info("Writing Parquet: %s", file_path)
  
  if (inherits(dt, "data.table")) {
    dt <- arrow::arrow_table(dt)
  }
  
  if (!is.null(partition_cols)) {
    arrow::write_dataset(
      dt,
      path = dirname(file_path),
      format = "parquet",
      partitioning = partition_cols,
      compression = compression
    )
  } else {
    arrow::write_parquet(dt, file_path, compression = compression)
  }
  
  flog.info("Parquet write complete")
  invisible(file_path)
}

#' Full ETL pipeline for a single file
#' @param file_path Input file path
#' @param table_name Output table name
#' @param config Configuration list
#' @param conn DB connection
#' @return Row count
run_file_etl <- function(file_path, table_name, config, conn) {
  flog.info("=== Starting ETL: %s -> %s ===", basename(file_path), table_name)
  
  if (grepl("\\.parquet$", file_path, ignore.case = TRUE)) {
    data <- extract_parquet(file_path, config)
    data <- data$to_data_frame()
    setDT(data)
  } else {
    data <- extract_csv(file_path, config)
  }
  
  data <- transform_clean(data, config)
  
  transforms <- get_config(config, "etl.custom_transforms", NULL)
  if (!is.null(transforms)) {
    for (t in transforms) {
      flog.info("Applying custom transform: %s", t$name)
    }
  }
  
  row_count <- load_to_duckdb(conn, data, table_name)
  
  rm(data)
  gc(verbose = FALSE)
  
  flog.info("=== ETL Complete: %d rows ===", row_count)
  row_count
}
