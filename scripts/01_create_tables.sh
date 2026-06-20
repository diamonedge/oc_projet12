#!/bin/bash
set -a
source .env
set +a

docker compose exec -T postgres \
  psql \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -v ON_ERROR_STOP=1 \
  -v app_user="$POSTGRES_APP_USER" \
  < sql/init/01_create_raw_tables.sql
