# Data Engineering R Pipeline

Production-ready data engineering pipeline optimized for **4GB RAM / 20GB SSD** environments.

## Architecture

| Component | Purpose | Memory Strategy |
|-----------|---------|-----------------|
| **DuckDB** | SQL analytics & storage | Out-of-core processing, streams from disk |
| **data.table** | In-memory transforms | Minimal overhead, reference semantics |
| **Arrow** | Parquet I/O | Zero-copy reads, columnar format |
| **targets** | Pipeline orchestration | Incremental builds, skips unchanged steps |
| **renv** | Reproducibility | Isolated package library |

## Quick Start

```bash
# 1. Clone and enter directory
cd data-engineering-r-project

# 2. Install dependencies
make install

# 3. Initialize database
make init-db PROFILE=dev

# 4. Add data
cp your-data.csv data/raw/

# 5. Run pipeline
make pipeline PROFILE=dev

# 6. View results
make vis