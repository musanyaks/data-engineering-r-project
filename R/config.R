#' Configuration Loader
#' 
#' Loads YAML configuration with profile-specific overrides.
#' Designed for resource-constrained environments (4GB RAM, 20GB SSD).

library(yaml)

#' Get project root directory
get_project_root <- function() {
  dirs <- c(".", "..", "../..", "../../..")
  for (d in dirs) {
    if (file.exists(file.path(d, "config", "config.yml"))) {
      return(normalizePath(d))
    }
  }
  return(".")
}

#' Load configuration
#' @param profile Character. Environment profile: "dev", "prod", "test"
#' @return List. Merged configuration
load_config <- function(profile = Sys.getenv("R_CONFIG_PROFILE", "dev")) {
  root <- get_project_root()
  base_config <- yaml::read_yaml(file.path(root, "config", "config.yml"))
  
  profile_file <- file.path(root, "config", "profiles.yml")
  if (file.exists(profile_file)) {
    profiles <- yaml::read_yaml(profile_file)
    if (!is.null(profiles[[profile]])) {
      base_config <- merge_configs(base_config, profiles[[profile]])
    }
  }
  
  validate_resource_limits(base_config$resources)
  
  if (.Platform$OS.type == "unix" && !is.null(base_config$resources$memory_limit_mb)) {
    tryCatch({
      utils::memory.limit(size = base_config$resources$memory_limit_mb)
    }, error = function(e) NULL)
  }
  
  Sys.setenv(R_CONFIG_PROFILE = profile)
  invisible(base_config)
}

#' Deep merge two config lists
merge_configs <- function(base, override) {
  if (!is.list(override)) return(override)
  for (name in names(override)) {
    if (name %in% names(base) && is.list(base[[name]]) && is.list(override[[name]])) {
      base[[name]] <- merge_configs(base[[name]], override[[name]])
    } else {
      base[[name]] <- override[[name]]
    }
  }
  base
}

#' Validate resource limits against hardware constraints
validate_resource_limits <- function(resources) {
  if (is.null(resources)) return(invisible(NULL))
  if (!is.null(resources$memory_limit_mb)) {
    max_safe_mb <- 3072
    if (resources$memory_limit_mb > max_safe_mb) {
      warning(sprintf(
        "Configured memory limit (%d MB) exceeds safe threshold (%d MB) for 4GB system",
        resources$memory_limit_mb, max_safe_mb
      ))
    }
  }
  if (.Platform$OS.type == "unix" && !is.null(resources$min_disk_free_gb)) {
    df_out <- system("df -BG . | tail -1 | awk '{print $4}' | sed 's/G//'", intern = TRUE)
    if (length(df_out) > 0) {
      free_gb <- as.numeric(df_out)
      if (free_gb < resources$min_disk_free_gb) {
        stop(sprintf("Insufficient disk space: %d GB free, %d GB required", free_gb, resources$min_disk_free_gb))
      }
    }
  }
  invisible(NULL)
}

#' Get config value with default
get_config <- function(config, path, default = NULL) {
  parts <- strsplit(path, "\\.")[[1]]
  current <- config
  for (part in parts) {
    if (!is.list(current) || is.null(current[[part]])) return(default)
    current <- current[[part]]
  }
  current
}
