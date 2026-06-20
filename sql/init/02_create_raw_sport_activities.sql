BEGIN;

CREATE TABLE IF NOT EXISTS raw.sport_activities_txt (
    source_file TEXT NOT NULL,
    source_row_number TEXT NOT NULL,
    activity_id TEXT,
    employee_id TEXT,
    activity_start_datetime TEXT,
    sport_type TEXT,
    distance_meters TEXT,
    activity_end_datetime TEXT,
    elapsed_seconds TEXT,
    activity_comment TEXT,
    source_system TEXT
);

SELECT format(
    'GRANT USAGE ON SCHEMA raw TO %I',
    :'app_user'
)
\gexec

SELECT format(
    'GRANT SELECT, INSERT, TRUNCATE ON TABLE raw.sport_activities_txt TO %I',
    :'app_user'
)
\gexec

COMMIT;
