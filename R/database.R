#' DuckDB Database Utilities
#' 
#' Out-of-core SQL processing for datasets larger than RAM.

library(DBI)
library(duckdb)

.DB_CONN <- NULL

#' Get database connection (singleton pattern)
#' @param config Configuration list
#' @return DuckDB connection object
get_db_connection <- function(config) {
  if (!is.null(.DB_CONN) && DBI::dbIsValid(.DB_CONN)) {
    return(.DB_CONN)
  }
  
  db_path <- get_config(config, "database.path", "data/processed/pipeline.duckdb")
  db_dir <- dirname(db_path)
  if (!dir.exists(db_dir)) dir.create(db_dir, recursive = TRUE)
  
  memory_limit <- get_config(config, "database.memory_limit", "2GB")
  threads <- get_config(config, "database.threads", 2)
  
  .DB_CONN <<- DBI::dbConnect(
    duckdb::duckdb(),
    dbdir = db_path,
    config = list(
      memory_limit = memory_limit,
      threads = threads,
      enable_progress_bar = "false",
      max_temp_directory_size = "5GB"
    )
  )
  
  flog.info("DuckDB connected: %s (memory_limit=%s, threads=%d)", db_path, memory_limit, threads)
  .DB_CONN
}

#' Close database connection
close_db_connection <- function() {
  if (!is.null(.DB_CONN) && DBI::dbIsValid(.DB_CONN)) {
    DBI::dbDisconnect(.DB_CONN, shutdown = TRUE)
    .DB_CONN <<- NULL
    flog.info("DuckDB disconnected")
  }
  invisible(NULL)
}

#' Execute SQL file
#' @param conn DB connection
#' @param sql_file Path to SQL file
execute_sql_file <- function(conn, sql_file) {
  if (!file.exists(sql_file)) {
    stop("SQL file not found: ", sql_file)
  }
  sql <- paste(readLines(sql_file), collapse = "\n")
  statements <- strsplit(sql, ";")[[1]]
  for (stmt in statements) {
    stmt <- trimws(stmt)
    if (nchar(stmt) > 0) {
      DBI::dbExecute(conn, stmt)
    }
  }
  flog.info("Executed SQL file: %s", sql_file)
  invisible(NULL)
}

#' Write data.frame to DuckDB in batches
#' @param conn DB connection
#' @param table_name Target table name
#' @param data data.frame or data.table
#' @param batch_size Rows per batch
#' @param overwrite Overwrite existing table
write_table_batch <- function(conn, table_name, data, batch_size = 10000, overwrite = TRUE) {
  if (overwrite) {
    DBI::dbExecute(conn, paste0("DROP TABLE IF EXISTS ", table_name))
  }
  
  total_rows <- nrow(data)
  batches <- ceiling(total_rows / batch_size)
  
  for (i in seq_len(batches)) {
    start_idx <- (i - 1) * batch_size + 1
    end_idx <- min(i * batch_size, total_rows)
    batch <- data[start_idx:end_idx, ]
    
    if (i == 1 && overwrite) {
      DBI::dbWriteTable(conn, table_name, batch)
    } else {
      DBI::dbWriteTable(conn, table_name, batch, append = TRUE)
    }
    
    if (i %% 10 == 0 || i == batches) {
      flog.info("Written batch %d/%d (%d rows) to %s", i, batches, nrow(batch), table_name)
    }
  }
  invisible(NULL)
}

#' Read large table in chunks using DuckDB
#' @param conn DB connection
#' @param table_name Table name or SQL query
#' @param is_query If TRUE, table_name is treated as SQL query
#' @return Arrow stream
read_table_chunked <- function(conn, table_name, is_query = FALSE) {
  query <- if (is_query) table_name else paste0("SELECT * FROM ", table_name)
  result <- DBI::dbSendQuery(conn, query)
  arrow_stream <- duckdb::duckdb_fetch_arrow(result)
  flog.info("Created Arrow stream for query")
  arrow_stream
}

#' Get table row count
#' @param conn DB connection
#' @param table_name Table name
table_row_count <- function(conn, table_name) {
  query <- paste0("SELECT COUNT(*) as n FROM ", table_name)
  res <- DBI::dbGetQuery(conn, query)
  as.integer(res$n)
}

#' Vacuum and optimize database
#' @param conn DB connection
optimize_database <- function(conn) {
  flog.info("Optimizing database...")
  DBI::dbExecute(conn, "CHECKPOINT")
  DBI::dbExecute(conn, "VACUUM")
  flog.info("Database optimized")
  invisible(NULL)
}