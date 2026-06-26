#!/bin/bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${ROOT_DIR}/scripts/lib.sh" ]] && [[ -f "${ROOT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/scripts/lib.sh"
else
  GOST_CONTAINER="${GOST_CONTAINER:-gost-socks5}"
  GOST_IMAGE="${GOST_IMAGE:-gogost/gost:latest}"
  GOST_PORT="${GOST_PORT:-1443}"
fi

if [[ ! -f "${ROOT_DIR}/gost.yml" ]]; then
  echo "ERROR: ${ROOT_DIR}/gost.yml missing. Run: sudo ${ROOT_DIR}/install.sh" >&2
  exit 1
fi

docker rm -f "${GOST_CONTAINER}" 2>/dev/null || true

docker run -d \
  --name "${GOST_CONTAINER}" \
  --restart unless-stopped \
  -p "${GOST_PORT}:${GOST_PORT}" \
  -v "${ROOT_DIR}/certs:/certs:ro" \
  -v "${ROOT_DIR}/gost.yml:/etc/gost/gost.yml:ro" \
  "${GOST_IMAGE}" \
  -C /etc/gost/gost.yml

echo "GOST started on port ${GOST_PORT}"
