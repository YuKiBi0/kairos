#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 --binary PATH --env-file PATH --migrations DIR" >&2
  exit 2
}

[[ $EUID -eq 0 ]] || { echo "install.sh must run as root" >&2; exit 1; }

BINARY=""
ENV_FILE=""
MIGRATIONS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --binary) BINARY=${2:-}; shift 2 ;;
    --env-file) ENV_FILE=${2:-}; shift 2 ;;
    --migrations) MIGRATIONS=${2:-}; shift 2 ;;
    *) usage ;;
  esac
done

[[ -f $BINARY && -f $ENV_FILE && -d $MIGRATIONS ]] || usage
BINARY=$(realpath "$BINARY")
ENV_FILE=$(realpath "$ENV_FILE")
MIGRATIONS=$(realpath "$MIGRATIONS")
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if ! id -u kairos >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/kairos --shell /usr/sbin/nologin kairos
fi
install -d -m 0755 -o root -g root /opt/kairos/bin /opt/kairos/migrations
install -d -m 0750 -o kairos -g kairos /var/lib/kairos
install -d -m 0750 -o root -g kairos /etc/kairos
install -m 0755 -o root -g root "$BINARY" /opt/kairos/bin/kairos-server
find "$MIGRATIONS" -maxdepth 1 -type f -name '*.sql' -exec \
  install -m 0644 -o root -g root {} /opt/kairos/migrations/ \;
install -m 0640 -o root -g kairos "$ENV_FILE" /etc/kairos/kairos.env
install -m 0644 -o root -g root \
  "$SCRIPT_DIR/kairos-server.service" /etc/systemd/system/kairos-server.service

set -a
# shellcheck disable=SC1091
source /etc/kairos/kairos.env
set +a
: "${KAIROS_DATABASE_URL:?KAIROS_DATABASE_URL is required}"
: "${KAIROS_SESSION_SECRET:?KAIROS_SESSION_SECRET is required}"
(
  cd /opt/kairos
  runuser -u kairos --preserve-environment -- bin/kairos-server migrate
)

systemctl daemon-reload
systemctl enable --now kairos-server.service
systemctl --quiet is-active kairos-server.service
echo "Kairos server installed. Verify with: curl http://127.0.0.1:8080/readyz"
