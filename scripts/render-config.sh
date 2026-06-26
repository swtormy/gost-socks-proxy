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

export GOST_USER GOST_PASSWORD GOST_PORT
envsubst '${GOST_USER} ${GOST_PASSWORD} ${GOST_PORT}' \
  < "${ROOT_DIR}/gost.yml.template" \
  > "${ROOT_DIR}/gost.yml"
chmod 600 "${ROOT_DIR}/gost.yml"
