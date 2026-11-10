#!/bin/bash
# Dump one environment's database and filestore, keeping the newest 7 backups.
# These stay on the server, so they do not survive losing the server itself.
set -euo pipefail

target="${1:?usage: backup.sh <staging|production>}"
checkout="/opt/odoo/$target"
env_file="/opt/odoo/env/$target.env"
dir="/opt/odoo/backups/$target"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
umask 077
mkdir -p "$dir"
cd "$checkout"

dc() {
    docker compose -p "odoo-$target" --env-file "$env_file" \
        -f compose.yaml -f compose.server.yaml "$@"
}

db="$(grep -E '^ODOO_DB=' "$env_file" | cut -d= -f2-)"

dc exec -T db pg_dump -U odoo -Fc "$db" >"$dir/$stamp.dump.tmp"
mv "$dir/$stamp.dump.tmp" "$dir/$stamp.dump"

dc run --rm --no-deps -T --entrypoint tar odoo \
    -C /var/lib/odoo/filestore -cz "$db" >"$dir/$stamp.filestore.tar.gz.tmp"
mv "$dir/$stamp.filestore.tar.gz.tmp" "$dir/$stamp.filestore.tar.gz"

# shellcheck disable=SC2012 # names are timestamps we generated
ls -1t "$dir"/*.dump | tail -n +8 | while read -r old; do
    rm -f "$old" "${old%.dump}.filestore.tar.gz"
done

echo "Backup written: $dir/$stamp.*"
