#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

LOCAL_PORT=10998
MODE="$(read_proxy_mode)"

if [[ "${MODE}" == "chain" ]]; then
  require_hop_env
  EXPECTED_IP="${HOP_SERVER_IP}"
else
  EXPECTED_IP="${SERVER_IP}"
fi

echo "Mode: ${MODE}"
echo "Expected exit IP: ${EXPECTED_IP}"

docker rm -f gost-status-check >/dev/null 2>&1 || true
docker run -d --name gost-status-check --network host "${GOST_IMAGE}" \
  -L "socks5://:${LOCAL_PORT}" \
  -F "socks5+tls://${GOST_USER}:${GOST_PASSWORD}@127.0.0.1:${GOST_PORT}?notls=true" >/dev/null

sleep 1
ACTUAL_IP="$(docker run --rm --network host curlimages/curl:8.5.0 -s --max-time 15 \
  --socks5-hostname "127.0.0.1:${LOCAL_PORT}" http://ifconfig.me || true)"
docker rm -f gost-status-check >/dev/null 2>&1 || true

echo "Actual exit IP: ${ACTUAL_IP:-<empty>}"
if [[ "${ACTUAL_IP}" == "${EXPECTED_IP}" ]]; then
  echo "Status: OK"
  exit 0
fi

echo "Status: MISMATCH"
exit 1
