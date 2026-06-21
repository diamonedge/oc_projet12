\set ON_ERROR_STOP on

SELECT format(
    'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD %L',
    :'superset_metadata_user',
    :'superset_metadata_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = :'superset_metadata_user'
)
\gexec

SELECT format(
    'ALTER ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD %L',
    :'superset_metadata_user',
    :'superset_metadata_password'
)
\gexec

SELECT format(
    'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD %L',
    :'superset_reader_user',
    :'superset_reader_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = :'superset_reader_user'
)
\gexec

SELECT format(
    'ALTER ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD %L',
    :'superset_reader_user',
    :'superset_reader_password'
)
\gexec

SELECT format(
    'CREATE DATABASE %I OWNER %I',
    :'superset_metadata_db',
    :'superset_metadata_user'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_database
    WHERE datname = :'superset_metadata_db'
)
\gexec

SELECT format(
    'GRANT CONNECT ON DATABASE %I TO %I',
    current_database(),
    :'superset_reader_user'
)
\gexec

REVOKE ALL ON SCHEMA marts, audit FROM :"superset_reader_user";

GRANT USAGE ON SCHEMA marts, audit TO :"superset_reader_user";

GRANT SELECT ON ALL TABLES IN SCHEMA marts, audit
TO :"superset_reader_user";

ALTER DEFAULT PRIVILEGES FOR ROLE :"dbt_user"
IN SCHEMA marts
GRANT SELECT ON TABLES TO :"superset_reader_user";

ALTER DEFAULT PRIVILEGES FOR ROLE :"dbt_user"
IN SCHEMA audit
GRANT SELECT ON TABLES TO :"superset_reader_user";

\connect :superset_metadata_db

GRANT ALL PRIVILEGES ON SCHEMA public
TO :"superset_metadata_user";
