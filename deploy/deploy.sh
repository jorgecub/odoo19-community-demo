#!/bin/bash
# Build and roll out the checked-out commit. Usage: deploy.sh <staging|production>
set -euo pipefail

target="${1:?usage: deploy.sh <staging|production>}"
checkout="/opt/odoo/$target"
env_file="/opt/odoo/env/$target.env"
cd "$checkout"

dc() {
    docker compose -p "odoo-$target" --env-file "$env_file" \
        -f compose.yaml -f compose.server.yaml "$@"
}

db="$(grep -E '^ODOO_DB=' "$env_file" | cut -d= -f2-)"
modules="$(grep -Ev '^[[:space:]]*(#|$)' config/modules.txt | paste -sd, -)"

echo "==> Deploying $(git rev-parse --short HEAD) to $target"
docker network inspect odoo-edge >/dev/null 2>&1 || docker network create odoo-edge >/dev/null

echo "==> Building image"
dc build --pull odoo

echo "==> Starting database"
dc up -d --wait db

# Back up production before touching its modules. Skipped on the very first deployment.
if [[ "$target" == "production" ]] &&
    dc exec -T db psql -U odoo -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$db'" | grep -q 1; then
    echo "==> Backing up production"
    "$checkout/deploy/backup.sh" production
fi

echo "==> Stopping Odoo for the module update"
dc stop odoo

odoo_once() {
    dc run --rm --no-deps odoo odoo -d "$db" --stop-after-init --no-http \
        --workers=0 --max-cron-threads=0 "$@"
}

# -i installs anything new (first run: the whole list) and skips what is installed.
echo "==> Installing new modules"
odoo_once -i "$modules" --load-language=es_CL
echo "==> Updating modules"
odoo_once -u "$modules"

echo "==> Starting Odoo"
if ! dc up -d --wait --wait-timeout 300 odoo; then
    echo "ERROR: Odoo failed its health check. Recent logs:" >&2
    dc logs --tail 80 odoo >&2
    exit 1
fi

# The proxy serves both environments and always runs from the production checkout.
# Any deployment starts it if needed; only production applies proxy config changes.
echo "==> Ensuring HTTPS proxy is running"
proxy_args=(up -d)
[[ "$target" == "production" ]] && proxy_args+=(--force-recreate)
docker compose -p odoo-edge --env-file /opt/odoo/env/edge.env \
    -f /opt/odoo/production/deploy/caddy/compose.yaml "${proxy_args[@]}"

echo "==> Done: $target is running $(git rev-parse --short HEAD)"
