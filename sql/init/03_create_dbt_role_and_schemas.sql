BEGIN;

SELECT format(
    'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD %L',
    :'dbt_user',
    :'dbt_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = :'dbt_user'
)
\gexec

SELECT format(
    'GRANT CONNECT ON DATABASE %I TO %I',
    current_database(),
    :'dbt_user'
)
\gexec

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS config;

REVOKE ALL ON SCHEMA staging, marts, audit, config FROM PUBLIC;

ALTER SCHEMA staging OWNER TO :"dbt_user";
ALTER SCHEMA marts OWNER TO :"dbt_user";
ALTER SCHEMA audit OWNER TO :"dbt_user";
ALTER SCHEMA config OWNER TO :"dbt_user";

GRANT USAGE ON SCHEMA raw TO :"dbt_user";
GRANT SELECT ON ALL TABLES IN SCHEMA raw TO :"dbt_user";

ALTER DEFAULT PRIVILEGES FOR ROLE :"db_owner"
IN SCHEMA raw
GRANT SELECT ON TABLES TO :"dbt_user";

COMMIT;
