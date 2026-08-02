# Data Engineering Pipeline Makefile
# Optimized for resource-constrained environments

.PHONY: all install test pipeline clean archive docker-build docker-run

PROFILE ?= dev
WORKERS ?= 1

all: install pipeline

# Install dependencies using renv
install:
	@echo "Installing dependencies..."
	Rscript -e "if (!require('renv')) install.packages('renv'); renv::restore()"

# Run tests
test:
	@echo "Running tests..."
	Rscript tests/testthat.R

# Initialize database schema
init-db:
	@echo "Initializing database..."
	Rscript -e "source('R/database.R'); source('R/config.R'); cfg <- load_config('$(PROFILE)'); conn <- get_db_connection(cfg); execute_sql_file(conn, 'sql/schema.sql'); close_db_connection()"

# Run full pipeline
pipeline: init-db
	@echo "Running pipeline with profile: $(PROFILE)"
	Rscript -e "source('R/pipeline.R'); run_pipeline(workers = $(WORKERS))"

# Visualize pipeline
vis:
	Rscript -e "source('R/pipeline.R'); vis_pipeline()"

# Clean processed data (keep raw)
clean:
	@echo "Cleaning processed data..."
	rm -rf data/processed/*
	rm -rf logs/*.log
	rm -rf reports/*.txt

# Archive old raw files
archive:
	@echo "Archiving old files..."
	Rscript -e "source('R/config.R'); source('R/etl.R'); cfg <- load_config('$(PROFILE)'); archive_old_files(cfg)"

# Full reset (dangerous)
reset: clean
	rm -rf data/archive/*
	rm -rf renv/library

# Docker
docker-build:
	docker build -t data-engineering-r .

docker-run:
	docker run --rm -v $(PWD)/data:/app/data -m 3g --memory-swap 3g data-engineering-r

# Health check
health:
	@echo "Checking system resources..."
	@df -h . | tail -1
	@free -h 2>/dev/null || vm_stat 2>/dev/null || echo "Memory check not available"