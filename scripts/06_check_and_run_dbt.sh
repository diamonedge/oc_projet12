#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
source "${PROJECT_ROOT}/.env"
set +a

export POSTGRES_HOST="${POSTGRES_HOST_OVERRIDE:-${POSTGRES_HOST}}"
export POSTGRES_HOST_PORT="${POSTGRES_HOST_PORT_OVERRIDE:-${POSTGRES_HOST_PORT}}"
export UV_LINK_MODE="${UV_LINK_MODE:-copy}"

cd "${PROJECT_ROOT}"

uv run dbt --version
uv run dbt run --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt test --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
