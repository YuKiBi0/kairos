#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 --binary PATH [--migrations DIR] [--sha256 HEX]" >&2
  exit 2
}

[[ $EUID -eq 0 ]] || { echo "update.sh must run as root" >&2; exit 1; }

BINARY=""
MIGRATIONS=""
EXPECTED_SHA=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --binary) BINARY=${2:-}; shift 2 ;;
    --migrations) MIGRATIONS=${2:-}; shift 2 ;;
    --sha256) EXPECTED_SHA=${2:-}; shift 2 ;;
    *) usage ;;
  esac
done

[[ -f $BINARY ]] || usage
BINARY=$(realpath "$BINARY")
if [[ -n $MIGRATIONS ]]; then
  [[ -d $MIGRATIONS ]] || usage
  MIGRATIONS=$(realpath "$MIGRATIONS")
fi
if [[ -n $EXPECTED_SHA ]]; then
  ACTUAL_SHA=$(sha256sum "$BINARY" | awk '{print $1}')
  [[ $ACTUAL_SHA == "$EXPECTED_SHA" ]] || {
    echo "binary SHA-256 does not match" >&2
    exit 1
  }
fi
[[ -x /opt/kairos/bin/kairos-server && -f /etc/kairos/kairos.env ]] || {
  echo "Kairos is not installed" >&2
  exit 1
}

BACKUP=/opt/kairos/bin/kairos-server.previous
install -m 0755 -o root -g root /opt/kairos/bin/kairos-server "$BACKUP"
rollback() {
  echo "update failed; restoring previous binary" >&2
  install -m 0755 -o root -g root "$BACKUP" /opt/kairos/bin/kairos-server
  systemctl start kairos-server.service || true
}
trap rollback ERR

systemctl stop kairos-server.service
install -m 0755 -o root -g root "$BINARY" /opt/kairos/bin/kairos-server
if [[ -n $MIGRATIONS ]]; then
  find "$MIGRATIONS" -maxdepth 1 -type f -name '*.sql' -exec \
    install -m 0644 -o root -g root {} /opt/kairos/migrations/ \;
fi
(
  cd /opt/kairos
  runuser -u kairos -- bin/kairos-server --env-file /etc/kairos/kairos.env migrate
)
systemctl start kairos-server.service
systemctl --quiet is-active kairos-server.service
trap - ERR
echo "Kairos server updated"
