#' Structured Logger
#' 
#' Lightweight logging with rotation to prevent disk overflow on 20GB SSD.

library(futile.logger)

.LOGGER_INITIALIZED <- FALSE

#' Initialize logger
#' @param config Configuration list
init_logger <- function(config) {
  if (.LOGGER_INITIALIZED) return(invisible(NULL))
  
  log_level <- get_config(config, "logging.level", "INFO")
  log_dir <- get_config(config, "logging.directory", "logs")
  max_files <- get_config(config, "logging.max_files", 10)
  max_size_mb <- get_config(config, "logging.max_size_mb", 50)
  
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
  clean_old_logs(log_dir, max_files, max_size_mb)
  
  log_file <- file.path(log_dir, paste0("pipeline_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
  flog.threshold(log_level)
  flog.appender(appender.tee(log_file))
  
  .LOGGER_INITIALIZED <<- TRUE
  flog.info("Logger initialized. Level: %s, File: %s", log_level, log_file)
  invisible(NULL)
}

#' Clean old log files to manage disk space
clean_old_logs <- function(log_dir, max_files = 10, max_size_mb = 50) {
  if (!dir.exists(log_dir)) return(invisible(NULL))
  log_files <- list.files(log_dir, pattern = "\\.log$", full.names = TRUE)
  if (length(log_files) == 0) return(invisible(NULL))
  
  info <- file.info(log_files)
  log_files <- log_files[order(info$mtime)]
  
  if (length(log_files) > max_files) {
    to_remove <- log_files[1:(length(log_files) - max_files)]
    file.remove(to_remove)
    flog.debug("Removed %d old log files", length(to_remove))
  }
  
  total_size <- sum(file.info(log_files)$size) / (1024 * 1024)
  while (total_size > max_size_mb && length(log_files) > 1) {
    file.remove(log_files[1])
    total_size <- sum(file.info(log_files[-1])$size) / (1024 * 1024)
    log_files <- log_files[-1]
  }
  invisible(NULL)
}

#' Log memory usage
log_memory <- function(context = "current") {
  mem <- gc(verbose = FALSE)
  used_mb <- sum(mem[, 2])
  max_mb <- sum(mem[, 6])
  flog.info("Memory [%s] - Used: %.0f MB, Max: %.0f MB", context, used_mb, max_mb)
  invisible(list(used_mb = used_mb, max_mb = max_mb))
}