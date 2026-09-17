#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091 # resolved from SCRIPT_DIR at runtime
source "$SCRIPT_DIR/wireguard-lib.sh"

require_installation
find "$PEER_DIR" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' 2>/dev/null | sed 's/\.conf$//' | sort
