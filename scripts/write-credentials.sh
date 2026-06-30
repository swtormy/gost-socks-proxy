#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
MODE="$(read_proxy_mode)"

cat > "${ROOT_DIR}/credentials.txt" <<EOF
GOST SOCKS5+TLS
===============
Server:   ${SERVER_IP}
Port:     ${GOST_PORT}
Username: ${GOST_USER}
Password: ${GOST_PASSWORD}

URI (sing-box / GOST / Surge):
socks5+tls://${GOST_USER}:${GOST_PASSWORD}@${SERVER_IP}:${GOST_PORT}?notls=true

Mode: ${MODE}
Switch mode:
  ./scripts/chain-on.sh
  ./scripts/chain-off.sh
  ./scripts/chain-status.sh

Chain hop:
  ${HOP_SERVER_IP:-<unset>}:${HOP_GOST_PORT}
  ${HOP_GOST_USER:-<unset>}:${HOP_GOST_PASSWORD:-<unset>}

TLS: Let's Encrypt IP certificate (short-lived ~6 days, auto-renew via cron)
Renew log: ${RENEW_LOG}
EOF

chmod 600 "${ROOT_DIR}/credentials.txt"
if [[ -n "${SUDO_USER:-}" ]]; then
  chown "${SUDO_USER}:${SUDO_USER}" "${ROOT_DIR}/credentials.txt"
elif [[ -n "${INSTALL_OWNER:-}" ]]; then
  chown "${INSTALL_OWNER}:${INSTALL_OWNER}" "${ROOT_DIR}/credentials.txt"
fi

cat "${ROOT_DIR}/credentials.txt"
