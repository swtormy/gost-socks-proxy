#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_OWNER="${SUDO_USER:-$(stat -c '%U' "${ROOT_DIR}")}"
export INSTALL_OWNER

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ${ROOT_DIR}/install.sh" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install: curl -fsSL https://get.docker.com | sh" >&2
  exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq gettext-base curl ca-certificates
fi

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  if [[ -f "${ROOT_DIR}/.env.example" ]]; then
    cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
    chown "${INSTALL_OWNER}:${INSTALL_OWNER}" "${ROOT_DIR}/.env"
    chmod 600 "${ROOT_DIR}/.env"
    echo ""
    echo "Created ${ROOT_DIR}/.env from .env.example"
    echo "Edit LEGO_EMAIL (required), then run install again:"
    echo "  nano ${ROOT_DIR}/.env"
    echo "  sudo ${ROOT_DIR}/install.sh"
    exit 0
  fi
  echo "ERROR: .env.example not found" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib.sh"

if [[ "${LEGO_EMAIL}" == "you@example.com" ]] || [[ -z "${LEGO_EMAIL}" ]]; then
  echo "ERROR: Set a real LEGO_EMAIL in ${ROOT_DIR}/.env" >&2
  exit 1
fi

install_lego() {
  if command -v lego >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing lego ACME client..."
  local version arch url
  version="$(curl -fsSL https://api.github.com/repos/go-acme/lego/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)"
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    i686|i386) arch=386 ;;
    armv7l|armv7) arch=armv7 ;;
    armv6l|armv6) arch=armv6 ;;
    *)
      echo "ERROR: Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
  url="https://github.com/go-acme/lego/releases/download/${version}/lego_${version}_linux_${arch}.tar.gz"
  curl -fsSL "${url}" -o /tmp/lego.tar.gz
  tar -xzf /tmp/lego.tar.gz -C /tmp lego
  install -m 755 /tmp/lego /usr/local/bin/lego
  lego --version
}

chmod +x "${ROOT_DIR}/scripts/"*.sh "${ROOT_DIR}/start-gost.sh" 2>/dev/null || true
install_lego
mkdir -p "${LEGO_PATH}" "${ROOT_DIR}/certs"
chown -R "${INSTALL_OWNER}:${INSTALL_OWNER}" "${ROOT_DIR}/certs" "${ROOT_DIR}/.env"

bash "${ROOT_DIR}/scripts/render-config.sh"
chown "${INSTALL_OWNER}:${INSTALL_OWNER}" "${ROOT_DIR}/gost.yml"

CERT_FILE="${LEGO_PATH}/certificates/${SERVER_IP}.crt"
if [[ ! -f "${CERT_FILE}" ]]; then
  echo "Requesting Let's Encrypt IP certificate for ${SERVER_IP}..."
  lego run -a \
    -m "${LEGO_EMAIL}" \
    -d "${SERVER_IP}" \
    --http \
    --path "${LEGO_PATH}" \
    --profile shortlived \
    --deploy-hook "${SYNC_SCRIPT}"
else
  echo "Certificate already exists: ${CERT_FILE}"
  bash "${SYNC_SCRIPT}"
fi

bash "${ROOT_DIR}/start-gost.sh"

cat > "${CRON_FILE}" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# GOST SOCKS5+TLS — Let's Encrypt IP cert renewal (~6 days lifetime)
${CRON_SCHEDULE} root ${RENEW_SCRIPT}
EOF
chmod 644 "${CRON_FILE}"

# Remove legacy cron from initial manual setup
rm -f /etc/cron.d/gost-cert-renew

bash "${ROOT_DIR}/scripts/write-credentials.sh"
chown -R "${INSTALL_OWNER}:${INSTALL_OWNER}" "${ROOT_DIR}"

echo ""
echo "Done. Proxy is running. Connection details: ${ROOT_DIR}/credentials.txt"
