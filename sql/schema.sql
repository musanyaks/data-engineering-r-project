-- Core schema definitions
-- Run once during initialization

CREATE TABLE IF NOT EXISTS _pipeline_metadata (
    run_id INTEGER PRIMARY KEY,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    profile VARCHAR,
    status VARCHAR,
    rows_processed BIGINT,
    error_message VARCHAR
);

CREATE SEQUENCE IF NOT EXISTS seq_run_id START 1;

CREATE TABLE IF NOT EXISTS _file_tracking (
    file_path VARCHAR PRIMARY KEY,
    file_hash VARCHAR,
    processed_at TIMESTAMP,
    row_count BIGINT,
    table_name VARCHAR
);

CREATE INDEX IF NOT EXISTS idx_file_tracking_hash ON _file_tracking(file_hash);
