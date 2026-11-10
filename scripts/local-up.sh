#!/bin/bash
# Start Odoo on this machine with every module from config/modules.txt installed.
# Safe to re-run: it installs only what is missing and updates the rest.
# Stop with:  docker compose -f compose.yaml -f compose.local.yaml down
# Wipe data:  docker compose -f compose.yaml -f compose.local.yaml down -v
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ ! -f .env ]]; then
    cp .env.example .env
    echo "==> Created .env from .env.example"
fi
# shellcheck disable=SC1091 # .env is created above from the committed example
source .env

dc() { docker compose -f compose.yaml -f compose.local.yaml "$@"; }
modules="$(grep -Ev '^[[:space:]]*(#|$)' config/modules.txt | paste -sd, -)"

echo "==> Building image (the first build downloads about 1 GB)"
dc build odoo
dc up -d --wait db

echo "==> Installing and updating modules"
dc stop odoo >/dev/null 2>&1 || true
dc run --rm --no-deps odoo odoo -d "$ODOO_DB" -i "$modules" --load-language=es_CL \
    --stop-after-init --no-http --workers=0 --max-cron-threads=0
dc run --rm --no-deps odoo odoo -d "$ODOO_DB" -u "$modules" \
    --stop-after-init --no-http --workers=0 --max-cron-threads=0

dc up -d --wait --wait-timeout 180 odoo
echo
echo "Odoo is running at http://localhost:${ODOO_PORT:-8069}"
echo "On a new database, sign in as admin / admin, then change that password."
