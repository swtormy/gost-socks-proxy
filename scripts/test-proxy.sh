#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

ORIGINAL_MODE="$(read_proxy_mode)"
LOCAL_PORT=10899

restore_mode() {
  if [[ "${ORIGINAL_MODE}" == "chain" ]]; then
    bash "${ROOT_DIR}/scripts/chain-on.sh" >/dev/null 2>&1 || true
  else
    bash "${ROOT_DIR}/scripts/chain-off.sh" >/dev/null 2>&1 || true
  fi
  docker rm -f gost-selftest >/dev/null 2>&1 || true
}
trap restore_mode EXIT

probe_exit_ip() {
  docker rm -f gost-selftest >/dev/null 2>&1 || true
  docker run -d --name gost-selftest --network host "${GOST_IMAGE}" \
    -L "socks5://:${LOCAL_PORT}" \
    -F "socks5+tls://${GOST_USER}:${GOST_PASSWORD}@127.0.0.1:${GOST_PORT}?notls=true" >/dev/null
  sleep 1
  docker run --rm --network host curlimages/curl:8.5.0 -s --max-time 15 \
    --socks5-hostname "127.0.0.1:${LOCAL_PORT}" http://ifconfig.me || true
}

echo "=== Testing DIRECT mode ==="
bash "${ROOT_DIR}/scripts/chain-off.sh"
DIRECT_IP="$(probe_exit_ip)"
if [[ "${DIRECT_IP}" != "${SERVER_IP}" ]]; then
  echo "FAIL: direct expected ${SERVER_IP}, got ${DIRECT_IP:-<empty>}"
  exit 1
fi
echo "OK: direct exit IP = ${DIRECT_IP}"

echo "=== Testing CHAIN mode ==="
require_hop_env
bash "${ROOT_DIR}/scripts/chain-on.sh"
CHAIN_IP="$(probe_exit_ip)"
if [[ "${CHAIN_IP}" != "${HOP_SERVER_IP}" ]]; then
  echo "FAIL: chain expected ${HOP_SERVER_IP}, got ${CHAIN_IP:-<empty>}"
  exit 1
fi
echo "OK: chain exit IP = ${CHAIN_IP}"

echo "SUCCESS: both modes are working."
