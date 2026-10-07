#!/usr/bin/env bash
# Lokale testrun: verse database → stub → migraties → seed → tests
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${DB:-we_test}
psql -q -c "drop database if exists $DB" -c "create database $DB" >/dev/null 2>&1
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f sqltests/_supabase_stub.sql >/dev/null
for f in migrations/*.sql; do psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f" >/dev/null; done
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f seed.sql >/dev/null
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f sqltests/flow_test.sql 2>&1 | grep -E "^(NOTICE|psql|ERROR|==|ALLE|FAIL)|ok -|FAIL" | sed 's/^psql:[^ ]* NOTICE:  /  /;s/^NOTICE:  /  /'
