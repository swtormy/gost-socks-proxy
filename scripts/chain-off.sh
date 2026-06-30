#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

set_proxy_mode direct
bash "${SCRIPT_DIR}/render-config.sh"
reload_gost

echo "Mode switched to DIRECT. Exit IP should be ${SERVER_IP}."
