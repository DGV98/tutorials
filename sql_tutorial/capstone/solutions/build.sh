#!/usr/bin/env bash
# Rebuilds capstone/solutions/citywheels.db from scratch:
# regenerates the raw CSVs (deterministic), creates the schema, loads and
# cleans the data, prints the data-quality report.
set -euo pipefail
cd "$(dirname "$0")"

python3 ../data/generate_capstone_data.py
rm -f citywheels.db
sqlite3 citywheels.db ".read schema.sql"
sqlite3 citywheels.db ".read load.sql"
sqlite3 -box citywheels.db ".read quality_report.sql"
echo "OK: citywheels.db rebuilt."
