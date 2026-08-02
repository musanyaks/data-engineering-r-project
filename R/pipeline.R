#' targets Pipeline Definition
#' 
#' Reproducible, incremental pipeline execution.
#' Memory-optimized for 4GB RAM systems.

library(targets)

#' Define the pipeline
#' @return targets pipeline object
define_pipeline <- function() {
  list(
    tar_target(
      name = config,
      command = load_config(Sys.getenv("R_CONFIG_PROFILE", "dev"))
    ),
    
    tar_target(
      name = logger,
      command = {
        init_logger(config)
        TRUE
      }
    ),
    
    tar_target(
      name = db_conn,
      command = {
        init_logger(config)
        get_db_connection(config)
      }
    ),
    
    tar_target(
      name = raw_files,
      command = {
        pattern <- get_config(config, "etl.input_pattern", "*.csv")
        files <- list.files("data/raw", pattern = pattern, full.names = TRUE)
        flog.info("Discovered %d raw files", length(files))
        files
      }
    ),
    
    tar_target(
      name = etl_results,
      command = {
        init_logger(config)
        conn <- get_db_connection(config)
        table_prefix <- get_config(config, "etl.table_prefix", "staging_")
        table_name <- paste0(table_prefix, tools::file_path_sans_ext(basename(raw_files)))
        run_file_etl(raw_files, table_name, config, conn)
      },
      pattern = map(raw_files),
      iteration = "list"
    ),
    
    tar_target(
      name = views_created,
      command = {
        init_logger(config)
        conn <- get_db_connection(config)
        execute_sql_file(conn, "sql/views.sql")
        TRUE
      }
    ),
    
    tar_target(
      name = summary_report,
      command = {
        init_logger(config)
        conn <- get_db_connection(config)
        
        tables <- DBI::dbGetQuery(conn, "
          SELECT table_name, 
                 estimated_size 
          FROM information_schema.tables 
          WHERE table_schema = 'main'
        ")
        
        report_file <- file.path("reports", paste0("summary_", format(Sys.time(), "%Y%m%d"), ".txt"))
        if (!dir.exists("reports")) dir.create("reports")
        
        writeLines(c(
          "Pipeline Summary Report",
          paste("Generated:", Sys.time()),
          paste("Profile:", Sys.getenv("R_CONFIG_PROFILE", "dev")),
          "",
          "Tables:",
          capture.output(print(tables))
        ), report_file)
        
        report_file
      }
    ),
    
    tar_target(
      name = db_optimized,
      command = {
        init_logger(config)
        conn <- get_db_connection(config)
        optimize_database(conn)
        TRUE
      }
    ),
    
    tar_target(
      name = pipeline_complete,
      command = {
        close_db_connection()
        flog.info("Pipeline completed successfully")
        TRUE
      }
    )
  )
}

#' Run the full pipeline
#' @param workers Number of parallel workers (default 1 for memory constraint)
run_pipeline <- function(workers = 1) {
  targets::tar_make(
    script = "R/pipeline.R",
    store = "data/processed/_targets",
    workers = workers
  )
}

#' Visualize pipeline
vis_pipeline <- function() {
  targets::tar_visnetwork(
    script = "R/pipeline.R",
    store = "data/processed/_targets"
  )
}