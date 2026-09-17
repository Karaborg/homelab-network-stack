#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091 # resolved from SCRIPT_DIR at runtime
source "$SCRIPT_DIR/wireguard-lib.sh"

name="${1:-}"
require_installation
validate_name "$name"
peer_file="$PEER_DIR/$name.conf"
[[ -f "$peer_file" ]] || { printf 'Peer not found: %s\n' "$name" >&2; exit 1; }

cat "$peer_file"
if command -v qrencode >/dev/null 2>&1; then
    qrencode -t ansiutf8 <"$peer_file"
fi
