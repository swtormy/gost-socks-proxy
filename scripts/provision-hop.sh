#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_hop_env

HOP_REMOTE_DIR="${HOP_REMOTE_DIR:-/opt/gost-hop}"
HOP_CONTAINER_NAME="${HOP_CONTAINER_NAME:-gost-hop-socks5}"

echo "Provisioning hop on ${HOP_SERVER_IP}..."
ssh -o StrictHostKeyChecking=no "root@${HOP_SERVER_IP}" \
  HOP_GOST_PORT="${HOP_GOST_PORT}" \
  HOP_GOST_USER="${HOP_GOST_USER}" \
  HOP_GOST_PASSWORD="${HOP_GOST_PASSWORD}" \
  HOP_SERVER_IP="${HOP_SERVER_IP}" \
  HOP_REMOTE_DIR="${HOP_REMOTE_DIR}" \
  HOP_CONTAINER_NAME="${HOP_CONTAINER_NAME}" \
  'bash -s' <<'EOF'
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required on hop server" >&2
  exit 1
fi

install -d -m 700 "${HOP_REMOTE_DIR}/certs"

if [[ ! -f "${HOP_REMOTE_DIR}/certs/fullchain.pem" || ! -f "${HOP_REMOTE_DIR}/certs/privkey.pem" ]]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/CN=${HOP_SERVER_IP}" \
    -keyout "${HOP_REMOTE_DIR}/certs/privkey.pem" \
    -out "${HOP_REMOTE_DIR}/certs/fullchain.pem" >/dev/null 2>&1
  chmod 600 "${HOP_REMOTE_DIR}/certs/privkey.pem"
  chmod 644 "${HOP_REMOTE_DIR}/certs/fullchain.pem"
fi

cat > "${HOP_REMOTE_DIR}/gost.yml" <<YAML
services:
  - name: hop-socks5-tls
    addr: ":${HOP_GOST_PORT}"
    handler:
      type: socks5
      auth:
        username: ${HOP_GOST_USER}
        password: ${HOP_GOST_PASSWORD}
      metadata:
        notls: true
        udp: true
    listener:
      type: tls
      tls:
        certFile: /certs/fullchain.pem
        keyFile: /certs/privkey.pem
        options:
          minVersion: VersionTLS12
          maxVersion: VersionTLS13
YAML
chmod 600 "${HOP_REMOTE_DIR}/gost.yml"

docker rm -f "${HOP_CONTAINER_NAME}" >/dev/null 2>&1 || true
docker run -d \
  --name "${HOP_CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${HOP_GOST_PORT}:${HOP_GOST_PORT}" \
  -v "${HOP_REMOTE_DIR}/certs:/certs:ro" \
  -v "${HOP_REMOTE_DIR}/gost.yml:/etc/gost/gost.yml:ro" \
  gogost/gost:latest \
  -C /etc/gost/gost.yml >/dev/null

if command -v iptables >/dev/null 2>&1; then
  iptables -C INPUT -p tcp --dport "${HOP_GOST_PORT}" -j ACCEPT >/dev/null 2>&1 || \
    iptables -I INPUT -p tcp --dport "${HOP_GOST_PORT}" -j ACCEPT >/dev/null 2>&1 || true
fi

echo "HOP_READY:${HOP_GOST_PORT}"
EOF

echo "Hop provisioned on ${HOP_SERVER_IP}:${HOP_GOST_PORT}"
