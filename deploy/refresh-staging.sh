#!/bin/bash
# Replace staging's data with the latest production backup, then neutralize it so
# staging cannot send mail or run outgoing integrations. Destroys staging's data.
# Usage: refresh-staging.sh --yes
set -euo pipefail

if [[ "${1:-}" != "--yes" ]]; then
    echo "This overwrites all staging data. Re-run with --yes to continue." >&2
    exit 2
fi

checkout=/opt/odoo/staging
env_file=/opt/odoo/env/staging.env
prod_db="$(grep -E '^ODOO_DB=' /opt/odoo/env/production.env | cut -d= -f2-)"
db="$(grep -E '^ODOO_DB=' "$env_file" | cut -d= -f2-)"
backups=/opt/odoo/backups/production
cd "$checkout"

dc() {
    docker compose -p odoo-staging --env-file "$env_file" \
        -f compose.yaml -f compose.server.yaml "$@"
}

dump="$(ls -1t "$backups"/*.dump 2>/dev/null | head -1 || true)"
if [[ -z "$dump" ]]; then
    echo "ERROR: no production backup in $backups" >&2
    exit 1
fi
filestore="${dump%.dump}.filestore.tar.gz"
if [[ ! -f "$filestore" ]]; then
    echo "ERROR: missing $filestore" >&2
    exit 1
fi

echo "==> Restoring $(basename "$dump") into staging"
dc stop odoo
dc up -d --wait db
dc exec -T db dropdb -U odoo --if-exists --force "$db"
dc exec -T db createdb -U odoo "$db"
dc exec -T db pg_restore -U odoo -d "$db" --no-owner <"$dump"

echo "==> Restoring filestore"
dc run --rm --no-deps -T --entrypoint bash odoo -c \
    "rm -rf /var/lib/odoo/filestore/$db && mkdir -p /var/lib/odoo/filestore/$db && tar -xz -C /var/lib/odoo/filestore/$db --strip-components=1" \
    <"$filestore"

echo "==> Neutralizing"
dc run --rm --no-deps odoo odoo neutralize -d "$db"

dc up -d --wait --wait-timeout 300 odoo
echo "==> Staging refreshed from $prod_db"
