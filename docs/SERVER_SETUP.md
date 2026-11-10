# Server setup

This setup has not yet been run on a real Oracle server, so expect to adjust it on first use.

## Oracle's free limits

From [Oracle's Always Free documentation](https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm):

- **Arm compute:** 2 OCPUs and 12 GB of memory
- **Block storage:** 200 GB total, including boot volumes
- **Outbound data:** 10 TB per month

The Compose memory limits add up to about 10.75 GB, leaving the rest for the operating system.

**Idle reclaim risk:** Oracle can reclaim an instance if, over 7 days, CPU (95th percentile),
network and memory use are all below 20%. A quiet demo could approach this. Backups live on
the same server, so a reclaimed server loses them too. Keep the demo data reproducible from
seed scripts, and don't store anything there that you can't recreate.

## 1. Create the server (you do this)

1. Create an Oracle Cloud account. You create the account and enter any card details yourself.
2. Choose your home region carefully, because Always Free resources are tied to it.
3. Create an instance with these settings:
   - **Image:** Ubuntu 24.04
   - **Shape:** `VM.Standard.A1.Flex`
   - **Size:** 2 OCPUs and 12 GB
   - **Boot volume:** about 100 GB
4. In the subnet's security list, allow TCP 80 and 443 and UDP 443 from anywhere.

Arm capacity is often limited in popular regions. If creation fails with an out-of-capacity
error, try another availability domain or retry later.

## 2. Create the deploy key (on your Mac)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/odoo_deploy -N "" -C "github-actions-deploy"
```

## 3. Prepare the server

Connect with the SSH key you gave Oracle, copy `deploy/bootstrap-server.sh` to the server, and run:

```bash
sudo bash bootstrap-server.sh https://github.com/<owner>/<repo>.git "$(cat odoo_deploy.pub)"
```

Copy `~/.ssh/odoo_deploy.pub` to the server first. A public repo clones as-is. A private repo
also needs a read-only GitHub deploy key on the server.

Then fill in `/opt/odoo/env/production.env`, `staging.env` and `edge.env`. Use different
secrets for each environment. Generate them with:

```bash
openssl rand -hex 32
```

## 4. Add GitHub secrets

Add these as repository secrets:

| Secret | Value |
|---|---|
| `DEPLOY_HOST` | The server's public IP address |
| `DEPLOY_SSH_KEY` | The contents of `~/.ssh/odoo_deploy` (the private key) |
| `DEPLOY_KNOWN_HOSTS` | The output of `ssh-keyscan -t ed25519 <server-ip>` |

Then turn deployments on by adding the repository variable `DEPLOY_ENABLED` with the value
`true`. Until then, merges and tags skip the deploy job.

## 5. First deployment

- **Staging:** merge to `main`.
- **Production:** push a tag on a `main` commit, for example `v0.1.0`.

## Operations

These run on the server as the `deploy` user, using your own login rather than the deploy key.

| Task | Command |
|---|---|
| Back up production (also runs nightly at 03:00 UTC) | `/opt/odoo/production/deploy/backup.sh production` |
| Replace staging's data with production's latest backup | `/opt/odoo/staging/deploy/refresh-staging.sh --yes` |

If `deploy/ssh-gate.sh` changes, re-run the bootstrap script, because the server keeps its own
copy outside the repo.
