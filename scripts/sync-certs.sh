#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

LEGO_CERTS="${LEGO_PATH}/certificates"

if [[ ! -f "${LEGO_CERTS}/${SERVER_IP}.crt" ]]; then
  echo "ERROR: certificate not found: ${LEGO_CERTS}/${SERVER_IP}.crt" >&2
  exit 1
fi

install -d -m 755 "${GOST_CERTS}"
cp "${LEGO_CERTS}/${SERVER_IP}.crt" "${GOST_CERTS}/fullchain.pem"
cp "${LEGO_CERTS}/${SERVER_IP}.key" "${GOST_CERTS}/privkey.pem"
chmod 644 "${GOST_CERTS}/fullchain.pem"
chmod 600 "${GOST_CERTS}/privkey.pem"

if [[ -n "${SUDO_USER:-}" ]]; then
  chown -R "${SUDO_USER}:${SUDO_USER}" "${GOST_CERTS}"
elif [[ -n "${INSTALL_OWNER:-}" ]]; then
  chown -R "${INSTALL_OWNER}:${INSTALL_OWNER}" "${GOST_CERTS}"
fi

if docker ps --format '{{.Names}}' | grep -qx "${GOST_CONTAINER}"; then
  docker restart "${GOST_CONTAINER}"
fi
