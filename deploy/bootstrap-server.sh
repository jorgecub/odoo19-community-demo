#!/bin/bash
# Prepare a fresh Ubuntu 24.04 server. Safe to re-run. Run as root:
#   sudo bash bootstrap-server.sh <git-clone-url> '<deploy-public-key>'
set -euo pipefail

repo_url="${1:?usage: bootstrap-server.sh <git-clone-url> <deploy-public-key>}"
deploy_key="${2:?usage: bootstrap-server.sh <git-clone-url> <deploy-public-key>}"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: run as root" >&2
    exit 1
fi
if [[ ! "$deploy_key" =~ ^ssh-(ed25519|rsa)[[:space:]] ]]; then
    echo "ERROR: the second argument must be an SSH public key" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
echo "==> Installing Docker, Compose and git"
apt-get update -q
apt-get install -y -q docker.io docker-compose-v2 docker-buildx git
systemctl enable --now docker

echo "==> Creating deploy user"
id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
usermod -aG docker deploy

mkdir -p /opt/odoo/env /opt/odoo/backups
for target in production staging; do
    [[ -d "/opt/odoo/$target/.git" ]] || git clone --quiet "$repo_url" "/opt/odoo/$target"
done
chown -R deploy:deploy /opt/odoo
chmod 700 /opt/odoo/env /opt/odoo/backups

echo "==> Installing the SSH gate outside the repo"
install -o root -g root -m 755 /opt/odoo/production/deploy/ssh-gate.sh /usr/local/bin/odoo-deploy-gate
install -d -o deploy -g deploy -m 700 /home/deploy/.ssh
printf 'command="/usr/local/bin/odoo-deploy-gate",restrict %s\n' "$deploy_key" >/home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys

echo "==> Scheduling nightly backups (03:00 UTC)"
cat >/etc/cron.d/odoo-backup <<'CRON'
0 3 * * * deploy /opt/odoo/production/deploy/backup.sh production >>/var/log/odoo-backup.log 2>&1
CRON
touch /var/log/odoo-backup.log
chown deploy:deploy /var/log/odoo-backup.log

for name in production staging edge; do
    if [[ ! -f "/opt/odoo/env/$name.env" ]]; then
        install -o deploy -g deploy -m 600 "/opt/odoo/production/deploy/env/$name.env.example" "/opt/odoo/env/$name.env"
    fi
done

cat <<'NEXT'

Server is ready. Next:
  1. Fill in /opt/odoo/env/production.env, staging.env and edge.env
  2. Allow TCP 80 and 443 (and UDP 443) in the Oracle subnet security list
  3. Print this server's host key for the GitHub secret: ssh-keyscan -t ed25519 <server-ip>
NEXT
