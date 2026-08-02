-- Analytical views

CREATE OR REPLACE VIEW v_load_summary AS
SELECT 
    table_name,
    estimated_size,
    column_count,
    row_count
FROM information_schema.tables
WHERE table_schema = 'main'
  AND table_name NOT LIKE '\_%';

CREATE OR REPLACE VIEW v_pipeline_runs AS
SELECT * FROM _pipeline_metadata ORDER BY run_id DESC;

CREATE OR REPLACE VIEW v_recent_files AS
SELECT * FROM _file_tracking 
WHERE processed_at > CURRENT_DATE - INTERVAL '7 days'
ORDER BY processed_at DESC;