#!/usr/bin/env python3
"""Write the Odoo config from environment variables at container start.

The config holds the master password, so it lives only inside the container and
is readable only by the odoo user.
"""
import os
import pathlib
import re
import sys

CUSTOM = pathlib.Path("/mnt/addons/custom")
VENDOR = pathlib.Path("/mnt/addons/vendor")


def required(name):
    value = os.environ.get(name, "")
    if not value:
        sys.exit(f"ERROR: environment variable {name} is required")
    if "\n" in value:
        sys.exit(f"ERROR: environment variable {name} must be a single line")
    return value


db_name = required("ODOO_DB")
if not re.fullmatch(r"[A-Za-z0-9_-]+", db_name):
    sys.exit("ERROR: ODOO_DB may only contain letters, digits, '_' and '-'")

# Odoo rejects an addons path entry with no modules in it, and addons/ starts empty.
paths = [str(VENDOR)]
if any(CUSTOM.glob("*/__manifest__.py")):
    paths.insert(0, str(CUSTOM))

env = os.environ.get
lines = [
    "[options]",
    f"addons_path = {','.join(paths)}",
    "data_dir = /var/lib/odoo",
    f"admin_passwd = {required('ADMIN_PASSWD')}",
    f"db_name = {db_name}",
    f"dbfilter = ^{db_name}$",
    "list_db = False",
    f"proxy_mode = {env('ODOO_PROXY_MODE', 'False')}",
    f"workers = {env('ODOO_WORKERS', '0')}",
    f"max_cron_threads = {env('ODOO_CRON_THREADS', '1')}",
    f"limit_memory_soft = {env('ODOO_LIMIT_MEMORY_SOFT', '1288490188')}",
    f"limit_memory_hard = {env('ODOO_LIMIT_MEMORY_HARD', '1610612736')}",
    "limit_time_cpu = 120",
    "limit_time_real = 240",
    f"log_level = {env('ODOO_LOG_LEVEL', 'info')}",
]

target = pathlib.Path(env("ODOO_RC", "/tmp/odoo.conf"))
target.touch(mode=0o600, exist_ok=True)
target.chmod(0o600)
target.write_text("\n".join(lines) + "\n")
