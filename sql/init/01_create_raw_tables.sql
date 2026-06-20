BEGIN;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE SCHEMA IF NOT EXISTS raw;
REVOKE ALL ON SCHEMA raw FROM PUBLIC;

CREATE TABLE IF NOT EXISTS raw.hr_employees_txt (
    source_file TEXT NOT NULL,
    source_row_number TEXT NOT NULL,
    employee_id TEXT,
    last_name TEXT,
    first_name TEXT,
    birth_date TEXT,
    business_unit TEXT,
    hire_date TEXT,
    gross_salary TEXT,
    contract_type TEXT,
    paid_leave_days TEXT,
    home_address TEXT,
    commute_mode TEXT
);

CREATE TABLE IF NOT EXISTS raw.employee_sport_profile_txt (
    source_file TEXT NOT NULL,
    source_row_number TEXT NOT NULL,
    employee_id TEXT,
    declared_sport TEXT
);

SELECT format(
    'GRANT USAGE ON SCHEMA raw TO %I',
    :'app_user'
)
\gexec

SELECT format(
    'GRANT SELECT, INSERT, TRUNCATE ON TABLE raw.hr_employees_txt TO %I',
    :'app_user'
)
\gexec

SELECT format(
    'GRANT SELECT, INSERT, TRUNCATE ON TABLE raw.employee_sport_profile_txt TO %I',
    :'app_user'
)
\gexec

COMMIT;
