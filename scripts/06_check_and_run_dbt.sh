#!/bin/bash

set -a
source .env
set +a

uv run dbt --version
uv run dbt run --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt test --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
