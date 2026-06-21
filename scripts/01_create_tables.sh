#!/bin/bash
set -a
source .env
set +a



docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v app_user="$POSTGRES_APP_USER" < sql/init/01_create_raw_tables.sql
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v app_user="$POSTGRES_APP_USER" < sql/init/02_create_raw_sport_activities.sql
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v app_user="$POSTGRES_APP_USER" < sql/init/04_create_raw_benefit_parameters.sql
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v app_user="$POSTGRES_APP_USER" < sql/data/01_inject_benefit_parameters.sql
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v app_user="$POSTGRES_APP_USER" < sql/init/05_create_raw_google_routes_responses.sql
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v dbt_user="$POSTGRES_DBT_USER" -v dbt_password="$POSTGRES_DBT_PASSWORD" -v db_owner="$POSTGRES_USER" < sql/init/03_create_dbt_role_and_schemas.sql
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v superset_metadata_user="$SUPERSET_METADATA_USER" -v superset_metadata_password="$SUPERSET_METADATA_PASSWORD" -v superset_reader_user="$SUPERSET_READER_USER" -v superset_reader_password="$SUPERSET_READER_PASSWORD" -v superset_metadata_db="$SUPERSET_METADATA_DB" -v dbt_user="$POSTGRES_DBT_USER" < sql/init/06_create_superset_roles_and_metadata.sql
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v app_user="$POSTGRES_APP_USER" < sql/init/07_create_ops_slack_publication_queue.sql
