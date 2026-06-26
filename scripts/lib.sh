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
