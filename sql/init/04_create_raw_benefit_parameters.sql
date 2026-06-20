BEGIN;

CREATE TABLE IF NOT EXISTS raw.benefit_parameters_txt (
    source_file TEXT NOT NULL,
    source_row_number TEXT NOT NULL,
    parameter_name TEXT,
    parameter_value TEXT,
    valid_from TEXT,
    valid_to TEXT,
    parameter_comment TEXT
);

SELECT format(
    'GRANT SELECT, INSERT, TRUNCATE ON TABLE raw.benefit_parameters_txt TO %I',
    :'app_user'
)
\gexec

COMMIT;
