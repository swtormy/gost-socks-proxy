#!/bin/bash
# Shared config for install / renew / sync scripts.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  echo "ERROR: ${ROOT_DIR}/.env not found. Copy .env.example to .env and edit it." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/.env"

GOST_USER="${GOST_USER:-proxy}"
GOST_PORT="${GOST_PORT:-1443}"
GOST_CONTAINER="${GOST_CONTAINER:-gost-socks5}"
GOST_IMAGE="${GOST_IMAGE:-gogost/gost:latest}"
LEGO_PATH="${LEGO_PATH:-/etc/lego/gost-socks-proxy}"
CRON_SCHEDULE="${CRON_SCHEDULE:-0 3,15 * * *}"

if [[ -z "${LEGO_EMAIL:-}" ]]; then
  echo "ERROR: LEGO_EMAIL is required in .env" >&2
  exit 1
fi

if [[ -z "${SERVER_IP:-}" ]]; then
  SERVER_IP="$(curl -fsS --max-time 10 ifconfig.me 2>/dev/null || curl -fsS --max-time 10 api.ipify.org 2>/dev/null || true)"
fi

if [[ -z "${SERVER_IP:-}" ]]; then
  echo "ERROR: SERVER_IP is empty and auto-detection failed. Set SERVER_IP in .env" >&2
  exit 1
fi

GOST_CERTS="${ROOT_DIR}/certs"
SYNC_SCRIPT="${ROOT_DIR}/scripts/sync-certs.sh"
RENEW_SCRIPT="${ROOT_DIR}/scripts/renew-certs.sh"
CRON_FILE="/etc/cron.d/gost-socks-proxy-renew"
RENEW_LOG="/var/log/gost-socks-proxy-renew.log"

HOP_SERVER_IP="${HOP_SERVER_IP:-}"
HOP_GOST_PORT="${HOP_GOST_PORT:-1443}"
HOP_GOST_USER="${HOP_GOST_USER:-}"
HOP_GOST_PASSWORD="${HOP_GOST_PASSWORD:-}"
CHAIN_MODE_FILE="${CHAIN_MODE_FILE:-${ROOT_DIR}/state/mode}"
GOST_RELOAD_MODE="${GOST_RELOAD_MODE:-sighup}"
CHAIN_NAME="${CHAIN_NAME:-chain-hop}"

if [[ "${CHAIN_MODE_FILE}" != /* ]]; then
  CHAIN_MODE_FILE="${ROOT_DIR}/${CHAIN_MODE_FILE}"
fi

ensure_mode_file() {
  install -d -m 755 "$(dirname "${CHAIN_MODE_FILE}")"
  if [[ ! -f "${CHAIN_MODE_FILE}" ]]; then
    echo "direct" > "${CHAIN_MODE_FILE}"
    chmod 644 "${CHAIN_MODE_FILE}"
  fi
}

read_proxy_mode() {
  ensure_mode_file

  local mode
  mode="$(tr -d '[:space:]' < "${CHAIN_MODE_FILE}")"
  case "${mode}" in
    direct|chain) echo "${mode}" ;;
    *)
      echo "direct" > "${CHAIN_MODE_FILE}"
      echo "direct"
      ;;
  esac
}

set_proxy_mode() {
  local mode="${1:-}"
  if [[ "${mode}" != "direct" && "${mode}" != "chain" ]]; then
    echo "ERROR: invalid mode '${mode}', expected direct|chain" >&2
    return 1
  fi
  ensure_mode_file
  echo "${mode}" > "${CHAIN_MODE_FILE}"
}

require_hop_env() {
  if [[ -z "${HOP_SERVER_IP}" || -z "${HOP_GOST_USER}" || -z "${HOP_GOST_PASSWORD}" ]]; then
    echo "ERROR: HOP_SERVER_IP, HOP_GOST_USER and HOP_GOST_PASSWORD must be set in .env" >&2
    return 1
  fi
}

reload_gost() {
  if ! docker ps --format '{{.Names}}' | grep -qx "${GOST_CONTAINER}"; then
    echo "ERROR: container ${GOST_CONTAINER} is not running" >&2
    return 1
  fi

  case "${GOST_RELOAD_MODE}" in
    sighup)
      docker kill -s HUP "${GOST_CONTAINER}" >/dev/null
      ;;
    restart)
      docker restart "${GOST_CONTAINER}" >/dev/null
      ;;
    *)
      echo "ERROR: unsupported GOST_RELOAD_MODE='${GOST_RELOAD_MODE}', use sighup|restart" >&2
      return 1
      ;;
  esac
}
