#!/bin/bash
# Build the image, install every module on an empty database, start Odoo and check it
# responds. Used by CI and works the same on a laptop. Uses its own Compose project,
# and removes only that project's containers and volumes when it finishes.
set -euo pipefail

cd "$(dirname "$0")/.."
project=odoo-installtest
db=odoo_test
port="${TEST_PORT:-18069}"
log="$(mktemp)"

export ENV_NAME=test ODOO_DB="$db" ODOO_PORT="$port" POSTGRES_PASSWORD=test-only ADMIN_PASSWD=test-only

dc() { docker compose -p "$project" -f compose.yaml -f compose.local.yaml "$@"; }
trap 'dc down -v --remove-orphans >/dev/null 2>&1 || true; rm -f "$log"' EXIT

modules="$(grep -Ev '^[[:space:]]*(#|$)' config/modules.txt | paste -sd, -)"

echo "==> Building image"
dc build odoo

echo "==> Installing: $modules"
dc up -d --wait db
if ! dc run --rm --no-deps odoo odoo -d "$db" -i "$modules" --load-language=es_CL \
    --stop-after-init --no-http --workers=0 --max-cron-threads=0 2>&1 | tee "$log"; then
    echo "ERROR: module installation failed" >&2
    exit 1
fi
if grep -E ' (ERROR|CRITICAL) ' "$log"; then
    echo "ERROR: errors were logged during installation" >&2
    exit 1
fi

echo "==> Re-running the update path used by deployments"
dc run --rm --no-deps odoo odoo -d "$db" -u "$modules" --stop-after-init --no-http \
    --workers=0 --max-cron-threads=0 2>&1 | tee "$log"
if grep -E ' (ERROR|CRITICAL) ' "$log"; then
    echo "ERROR: errors were logged during update" >&2
    exit 1
fi

echo "==> Starting Odoo"
dc up -d --wait --wait-timeout 180 odoo
curl -fsS "http://127.0.0.1:$port/web/health" >/dev/null
curl -fsS -o /dev/null "http://127.0.0.1:$port/web/login"

echo "==> PASS: all modules install, update and serve the login page"
