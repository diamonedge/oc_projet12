#!/bin/bash
set -a
source .env
set +a

docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -v app_user="$POSTGRES_APP_USER" < sql/data/01_inject_benefit_parameters.sql
