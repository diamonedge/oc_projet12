
BEGIN;

CREATE TABLE IF NOT EXISTS raw.google_routes_responses_txt (
    source_file TEXT NOT NULL,
    source_row_number TEXT NOT NULL,
    request_key TEXT,
    employee_id TEXT,
    home_address TEXT,
    office_address TEXT,
    declared_commute_mode TEXT,
    google_travel_mode TEXT,
    request_payload_json TEXT,
    response_http_status TEXT,
    response_payload_json TEXT,
    requested_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_google_routes_responses_request_key
    ON raw.google_routes_responses_txt (request_key)
    WHERE request_key IS NOT NULL;

SELECT format(
    'GRANT SELECT, INSERT, TRUNCATE ON TABLE raw.google_routes_responses_txt TO %I',
    :'app_user'
)
\gexec

COMMIT;
