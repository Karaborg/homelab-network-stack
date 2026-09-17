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

public_key="$(awk -F ' = ' '/^\[Peer\]/{peer=1; next} peer && /^PublicKey = /{print $2; exit}' "$peer_file")"
[[ -n "$public_key" ]] || { printf 'Could not read peer public key.\n' >&2; exit 1; }

wg_exec wg set wg0 peer "$public_key" remove
temp_file="$(mktemp "$WG_CONF.XXXXXX")"
awk -v marker="# homelab-peer:$name" '
  $0 == marker { skip = 1; next }
  skip && /^$/ { skip = 0; next }
  !skip { print }
' "$WG_CONF" >"$temp_file"
mv "$temp_file" "$WG_CONF"
mv "$peer_file" "$peer_file.removed-$(date +%Y%m%d-%H%M%S)"
printf 'Peer removed: %s\n' "$name"
