#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

LOCAL_PORT=10997

require_hop_env

echo "Checking hop reachability ${HOP_SERVER_IP}:${HOP_GOST_PORT}..."
if ! timeout 5 bash -c "</dev/tcp/${HOP_SERVER_IP}/${HOP_GOST_PORT}" 2>/dev/null; then
  echo "ERROR: hop port is unreachable: ${HOP_SERVER_IP}:${HOP_GOST_PORT}" >&2
  exit 1
fi

echo "Validating hop authentication and egress IP..."
docker rm -f gost-chain-check >/dev/null 2>&1 || true
docker run -d --name gost-chain-check --network host "${GOST_IMAGE}" \
  -L "socks5://:${LOCAL_PORT}" \
  -F "socks5+tls://${HOP_GOST_USER}:${HOP_GOST_PASSWORD}@${HOP_SERVER_IP}:${HOP_GOST_PORT}?notls=true" >/dev/null

sleep 1
CHAIN_IP="$(docker run --rm --network host curlimages/curl:8.5.0 -s --max-time 15 \
  --socks5-hostname "127.0.0.1:${LOCAL_PORT}" http://ifconfig.me || true)"
docker rm -f gost-chain-check >/dev/null 2>&1 || true

if [[ "${CHAIN_IP}" != "${HOP_SERVER_IP}" ]]; then
  echo "ERROR: hop validation failed, expected ${HOP_SERVER_IP}, got ${CHAIN_IP:-<empty>}" >&2
  exit 1
fi

set_proxy_mode chain
bash "${SCRIPT_DIR}/render-config.sh"
reload_gost

echo "Mode switched to CHAIN. Exit IP should be ${HOP_SERVER_IP}."
