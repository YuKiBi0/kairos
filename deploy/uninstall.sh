#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "uninstall.sh must run as root" >&2; exit 1; }
PURGE_DATA=false
case "${1:-}" in
  "") ;;
  --purge-data) PURGE_DATA=true ;;
  *) echo "usage: $0 [--purge-data]" >&2; exit 2 ;;
esac

systemctl disable --now kairos-server.service 2>/dev/null || true
rm -f /etc/systemd/system/kairos-server.service
rm -f /opt/kairos/bin/kairos-server /opt/kairos/bin/kairos-server.previous
systemctl daemon-reload

if [[ $PURGE_DATA == true ]]; then
  rm -rf -- /var/lib/kairos /etc/kairos /opt/kairos
  userdel kairos 2>/dev/null || true
  echo "Kairos server, configuration, and local data removed"
else
  echo "Kairos server removed; /etc/kairos, /var/lib/kairos, and migrations were preserved"
fi
