library(targets)
source("R/config.R")
source("R/logger.R")
source("R/database.R")
source("R/etl.R")

tar_option_set(
  packages = c("data.table", "DBI", "duckdb", "yaml", "futile.logger")
)

list(
  tar_target(config, load_config("dev")),
  tar_target(logger, { init_logger(config); TRUE }),
  tar_target(db_conn, { init_logger(config); get_db_connection(config) }),
  tar_target(raw_files, list.files("data/raw", pattern = "*.csv", full.names = TRUE)),
  tar_target(
    etl_results,
    {
      init_logger(config)
      conn <- get_db_connection(config)
      table_name <- paste0("staging_", tools::file_path_sans_ext(basename(raw_files)))
      run_file_etl(raw_files, table_name, config, conn)
    },
    pattern = map(raw_files),
    iteration = "list"
  )
)
