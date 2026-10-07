#!/usr/bin/env bash
# Lokale API-stack: Postgres (al draaiend) + PostgREST + gateway.
# Vereist: postgrest-binary in $PGRST_BIN en een database met migraties + seed.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
: "${PGRST_BIN:=postgrest}"
: "${DB_URI:=postgres://authenticator@/we_dev?host=/var/tmp/pgwe&port=54329}"
export LOCAL_JWT_SECRET="${LOCAL_JWT_SECRET:-local-only-secret-at-least-32-characters!!}"
cat > "$DIR/.postgrest.conf" <<CONF
db-uri = "$DB_URI"
db-schemas = "public"
db-anon-role = "anon"
jwt-secret = "$LOCAL_JWT_SECRET"
server-port = 3002
CONF
"$PGRST_BIN" "$DIR/.postgrest.conf" > "$DIR/.postgrest.log" 2>&1 &
node "$DIR/proxy.mjs" > "$DIR/.proxy.log" 2>&1 &
sleep 1
echo "NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321"
echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=$(node "$DIR/jwt.mjs" '{"role":"anon"}')"
