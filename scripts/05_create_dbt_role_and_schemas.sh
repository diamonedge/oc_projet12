#!/bin/bash

set -a
source .env
set +a

docker compose exec -T postgres \
  psql \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -v ON_ERROR_STOP=1 \
  -v dbt_user="$POSTGRES_DBT_USER" \
  -v dbt_password="$POSTGRES_DBT_PASSWORD" \
  -v db_owner="$POSTGRES_USER" \
  < sql/init/03_create_dbt_role_and_schemas.sql
