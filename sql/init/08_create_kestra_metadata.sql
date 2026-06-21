\set ON_ERROR_STOP on

SELECT format(
    'CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD %L',
    :'kestra_metadata_user',
    :'kestra_metadata_password'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = :'kestra_metadata_user'
);
\gexec

SELECT format(
    'ALTER ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD %L',
    :'kestra_metadata_user',
    :'kestra_metadata_password'
);
\gexec

SELECT format(
    'CREATE DATABASE %I OWNER %I',
    :'kestra_metadata_db',
    :'kestra_metadata_user'
)
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = :'kestra_metadata_db'
);
\gexec

SELECT format(
    'REVOKE ALL ON DATABASE %I FROM PUBLIC',
    :'kestra_metadata_db'
);
\gexec

SELECT format(
    'GRANT CONNECT, TEMPORARY ON DATABASE %I TO %I',
    :'kestra_metadata_db',
    :'kestra_metadata_user'
);
\gexec
