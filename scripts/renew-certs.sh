#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

exec >>"${RENEW_LOG}" 2>&1
echo "=== $(date -Is) renew start (ip=${SERVER_IP}) ==="

lego run -a \
  -m "${LEGO_EMAIL}" \
  -d "${SERVER_IP}" \
  --http \
  --path "${LEGO_PATH}" \
  --profile shortlived \
  --renew-days 2 \
  --deploy-hook "${SYNC_SCRIPT}"

echo "=== $(date -Is) renew done ==="
