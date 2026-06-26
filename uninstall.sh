#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ${ROOT_DIR}/uninstall.sh" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh" 2>/dev/null || true

docker rm -f "${GOST_CONTAINER:-gost-socks5}" 2>/dev/null || true
rm -f /etc/cron.d/gost-socks-proxy-renew /etc/cron.d/gost-cert-renew

echo "Removed container and cron job."
echo "Certificates in ${LEGO_PATH:-/etc/lego/gost-socks-proxy} and ${ROOT_DIR}/certs were kept."
echo "Delete them manually if you no longer need this VPS setup."
