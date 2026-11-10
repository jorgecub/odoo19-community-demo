#!/bin/bash
# Render the config, then hand over to the official Odoo entrypoint.
set -euo pipefail
/usr/local/bin/render_conf.py
exec /entrypoint.sh "$@"
