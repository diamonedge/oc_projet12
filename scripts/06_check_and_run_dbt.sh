#!/bin/bash

set -a
source .env
set +a

uv run dbt --version
uv run dbt debug --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt parse --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt ls --resource-type source --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt run --select stg_hr_employees --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt run --select stg_employee_sport_profile --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt run --select stg_sport_activities --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt test --select tag:quality --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt run --select config_benefit_parameters --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt run --select fct_sport_activities mart_wellbeing_eligibility --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
uv run dbt run --select stg_google_routes_responses --project-dir dbt/sport_benefits --profiles-dir dbt/sport_benefits
