#!/usr/bin/env bash
# Assertion-test runner for the Nordkart database.
#
# Convention: every tests/test_*.sql file SELECTs rows that VIOLATE an
# invariant. Zero rows returned = PASS. Any row returned = FAIL, and the
# violating rows are printed so the failure is immediately diagnosable.
#
# Usage (from the course root):
#     bash tests/run_tests.sh            # runs against shop.db
#     bash tests/run_tests.sh other.db   # runs against another database
# Exits 0 when every test passes, 1 otherwise.

set -u
db="${1:-shop.db}"
fail=0

for f in tests/test_*.sql; do
    rows=$(sqlite3 "$db" < "$f" | wc -l)
    if [ "$rows" -eq 0 ]; then
        printf 'PASS  %s\n' "$f"
    else
        printf 'FAIL  %s  (%d violating rows)\n' "$f" "$rows"
        sqlite3 -box "$db" < "$f" | head -15
        fail=1
    fi
done

exit "$fail"
