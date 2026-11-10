#!/bin/sh
# Copy only the modules listed in the lock file, each at its pinned commit.
# Usage: fetch_addons.sh <lock-file> <output-dir>
set -eu

lock="$1"
out="$2"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$out"

grep -Ev '^[[:space:]]*(#|$)' "$lock" | while read -r name url sha modules; do
    repo="$work/$name"
    git init -q "$repo"
    git -C "$repo" fetch -q --depth 1 "$url" "$sha"
    git -C "$repo" -c advice.detachedHead=false checkout -q FETCH_HEAD
    actual="$(git -C "$repo" rev-parse HEAD)"
    if [ "$actual" != "$sha" ]; then
        echo "ERROR: $name resolved to $actual, expected $sha" >&2
        exit 1
    fi
    for module in $(printf '%s' "$modules" | tr ',' ' '); do
        if [ ! -f "$repo/$module/__manifest__.py" ]; then
            echo "ERROR: $module not found in $name at $sha" >&2
            exit 1
        fi
        if [ -e "$out/$module" ]; then
            echo "ERROR: $module is listed more than once" >&2
            exit 1
        fi
        cp -R "$repo/$module" "$out/$module"
    done
    echo "OK $name: $modules"
done
