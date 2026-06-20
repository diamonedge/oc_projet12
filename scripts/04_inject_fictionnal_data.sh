#!/bin/bash

set -a
source .env
set +a

uv run python -m src.sport_data_solution.simulate_sport_activities
