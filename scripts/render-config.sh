#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [[ -z "${GOST_PASSWORD:-}" ]]; then
  GOST_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
  if grep -q '^GOST_PASSWORD=$' "${ROOT_DIR}/.env"; then
    sed -i "s/^GOST_PASSWORD=$/GOST_PASSWORD=${GOST_PASSWORD}/" "${ROOT_DIR}/.env"
  elif ! grep -q '^GOST_PASSWORD=' "${ROOT_DIR}/.env"; then
    echo "GOST_PASSWORD=${GOST_PASSWORD}" >> "${ROOT_DIR}/.env"
  fi
fi

MODE="$(read_proxy_mode)"
GOST_HANDLER_CHAIN_BLOCK=""
GOST_CHAINS_BLOCK=""

if [[ "${MODE}" == "chain" ]]; then
  require_hop_env
  GOST_HANDLER_CHAIN_BLOCK="      chain: ${CHAIN_NAME}"
  GOST_CHAINS_BLOCK="$(cat <<EOF
chains:
  - name: ${CHAIN_NAME}
    hops:
      - name: hop-0
        nodes:
          - name: node-0
            addr: ${HOP_SERVER_IP}:${HOP_GOST_PORT}
            connector:
              type: socks5
              auth:
                username: ${HOP_GOST_USER}
                password: ${HOP_GOST_PASSWORD}
              metadata:
                notls: true
            dialer:
              type: tls
EOF
)"
fi

export GOST_USER GOST_PASSWORD GOST_PORT GOST_HANDLER_CHAIN_BLOCK GOST_CHAINS_BLOCK
envsubst '${GOST_USER} ${GOST_PASSWORD} ${GOST_PORT} ${GOST_HANDLER_CHAIN_BLOCK} ${GOST_CHAINS_BLOCK}' \
  < "${ROOT_DIR}/gost.yml.template" \
  > "${ROOT_DIR}/gost.yml"
chmod 600 "${ROOT_DIR}/gost.yml"
