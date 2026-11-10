# Odoo 19 Community, Enterprise-style demo for Chile

Odoo 19 Community with an Enterprise-like interface, using OCA and custom modules to close
the functional gap. It runs on free infrastructure and is managed entirely through GitHub.
The data is fictional: this is a demo, not a production ERP.

## How changes reach each environment

| Step | What happens |
|---|---|
| Open a pull request | CI installs and updates every module on an empty database |
| Merge to `main` | Deploys to **staging** |
| Push a `v*` tag on a commit from `main` | Backs up production, then deploys to **production** |

Both environments run on one server, each with its own database, files and secrets. Caddy
provides HTTPS for both.

```
GitHub Actions --SSH, restricted key--> server
                                        |-- Caddy (HTTPS)
                                        |-- odoo-production: Odoo + PostgreSQL
                                        `-- odoo-staging:    Odoo + PostgreSQL
```

The deploy key can run only `deploy <staging|production> <sha>`, and production accepts only
commits already on `main`.

## Repository layout

| Path | Purpose |
|---|---|
| `addons/` | Our own modules |
| `deps/vendor.lock` | Third-party modules, pinned to exact commits |
| `config/modules.txt` | Modules installed and updated on each deployment |
| `docker/` | Image build and Odoo config rendering |
| `deploy/` | Server bootstrap, deployment, backup and staging refresh |
| `scripts/` | Repo checks and the install test |
| `docs/` | [Server setup](docs/SERVER_SETUP.md) and [gap matrix and roadmap](docs/GAP_MATRIX.md) |

## Run locally

You need Docker running and about 5 GB of free disk space. This builds the image, installs
every module from `config/modules.txt`, and starts Odoo:

```bash
bash scripts/local-up.sh
```

Then open <http://localhost:8069>. On a new database, the login is `admin` with password
`admin`. To run the same install test as CI, which uses a throwaway database:

```bash
bash scripts/install-test.sh
```

## Common changes

- **Add a third-party module:** add it and any dependencies to `deps/vendor.lock`, then to
  `config/modules.txt`.
- **Update third-party modules or Odoo:** change the commit in `deps/vendor.lock` or the
  digest in `docker/Dockerfile`. The official image is pinned, so Odoo fixes arrive only
  through this PR.
- **Add a custom module:** put it in `addons/` with a `19.0.x.y.z` version and an LGPL-3 or
  AGPL-3 licence, then add it to `config/modules.txt`.

## Rules

- Never copy Odoo Enterprise code, assets or data, even if you have access through a partner
  account. Match behaviour and look with original work or open-source modules.
  `scripts/check_repo.py` blocks Enterprise dependencies and non-open licences in `addons/`,
  but it cannot detect copied code, so reviewers must check for that.
- Never commit secrets. They belong in `/opt/odoo/env/` on the server and in GitHub secrets.
