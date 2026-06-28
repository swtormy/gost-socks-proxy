#!/bin/bash
# Quick end-to-end test from the VPS itself.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

LOCAL_PORT=10899

echo "Testing SOCKS5+TLS via 127.0.0.1:${GOST_PORT}..."
docker rm -f gost-selftest 2>/dev/null || true
docker run -d --name gost-selftest --network host "${GOST_IMAGE}" \
  -L "socks5://:${LOCAL_PORT}" \
  -F "socks5+tls://${GOST_USER}:${GOST_PASSWORD}@127.0.0.1:${GOST_PORT}?notls=true"

sleep 1
RESULT="$(docker run --rm --network host curlimages/curl:8.5.0 -s --max-time 15 \
  --socks5-hostname "${GOST_USER}:${GOST_PASSWORD}@127.0.0.1:${LOCAL_PORT}" http://ifconfig.me || true)"
docker rm -f gost-selftest >/dev/null

if [[ "${RESULT}" == "${SERVER_IP}" ]]; then
  echo "OK: proxy works, exit IP = ${RESULT}"
  exit 0
fi

echo "FAIL: expected ${SERVER_IP}, got: ${RESULT:-<empty>}"
exit 1
