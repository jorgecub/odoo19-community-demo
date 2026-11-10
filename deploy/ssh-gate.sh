#!/bin/bash
# Forced command for the deploy SSH key. This key can do only one thing:
#   deploy <staging|production> <40-character commit sha>
# Production also requires the commit to already be on origin/main.
# bootstrap-server.sh installs this outside the repo, so a commit cannot change it.
set -euo pipefail

read -r action target sha extra <<<"${SSH_ORIGINAL_COMMAND:-}"

if [[ "${action:-}" != "deploy" || -n "${extra:-}" ]]; then
    echo "ERROR: expected: deploy <staging|production> <sha>" >&2
    exit 2
fi
if [[ ! "${target:-}" =~ ^(staging|production)$ ]]; then
    echo "ERROR: unknown environment" >&2
    exit 2
fi
if [[ ! "${sha:-}" =~ ^[0-9a-f]{40}$ ]]; then
    echo "ERROR: expected a full commit sha" >&2
    exit 2
fi

checkout="/opt/odoo/$target"
git -C "$checkout" fetch --quiet --tags --force origin
git -C "$checkout" cat-file -e "$sha^{commit}"

if [[ "$target" == "production" ]] && ! git -C "$checkout" merge-base --is-ancestor "$sha" origin/main; then
    echo "ERROR: production only deploys commits that are on main" >&2
    exit 3
fi

git -C "$checkout" -c advice.detachedHead=false checkout --quiet --detach "$sha"
exec "$checkout/deploy/deploy.sh" "$target"
