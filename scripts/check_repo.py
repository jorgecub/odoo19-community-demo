#!/usr/bin/env python3
"""Fast repo checks that need neither Docker nor Odoo. Manifests are parsed, never run.

Blocks Enterprise dependencies and non-open licences in our own modules, because this
project must stay free of Odoo's proprietary code.
"""
import ast
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ALLOWED_LICENSES = {"LGPL-3", "AGPL-3"}
# Enterprise-only modules. A hit means a module would not install on Community.
ENTERPRISE_ONLY = {
    "web_enterprise", "web_studio", "account_accountant", "account_reports",
    "documents", "sign", "planning", "helpdesk", "hr_payroll", "sale_subscription",
    "l10n_cl_edi", "l10n_cl_reports",
}
errors = []


def lock_entries():
    for line in (ROOT / "deps/vendor.lock").read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 4:
            errors.append(f"vendor.lock: expected 4 fields: {line}")
            continue
        yield parts


vendor_modules = set()
for name, url, sha, modules in lock_entries():
    if not url.startswith("https://github.com/"):
        errors.append(f"vendor.lock: {name}: url must be https://github.com/...")
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        errors.append(f"vendor.lock: {name}: sha must be a full commit")
    for module in modules.split(","):
        if module in vendor_modules:
            errors.append(f"vendor.lock: {module} is listed twice")
        vendor_modules.add(module)

custom_modules = set()
for manifest_path in sorted((ROOT / "addons").glob("*/__manifest__.py")):
    module = manifest_path.parent.name
    custom_modules.add(module)
    try:
        manifest = ast.literal_eval(manifest_path.read_text())
    except (SyntaxError, ValueError) as exc:
        errors.append(f"{module}: manifest does not parse: {exc}")
        continue
    if manifest.get("license") not in ALLOWED_LICENSES:
        errors.append(f"{module}: license must be one of {sorted(ALLOWED_LICENSES)}")
    if not str(manifest.get("version", "")).startswith("19.0."):
        errors.append(f"{module}: version must start with 19.0.")
    for dep in set(manifest.get("depends", [])) & ENTERPRISE_ONLY:
        errors.append(f"{module}: depends on Enterprise-only module {dep}")

for line in (ROOT / "config/modules.txt").read_text().splitlines():
    module = line.strip()
    if module and not module.startswith("#") and module in ENTERPRISE_ONLY:
        errors.append(f"modules.txt: {module} is Enterprise-only")

if errors:
    print("\n".join(f"ERROR: {error}" for error in errors))
    sys.exit(1)
print(f"OK: {len(vendor_modules)} vendored and {len(custom_modules)} custom modules checked")
