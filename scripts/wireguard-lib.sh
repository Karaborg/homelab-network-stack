#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
WG_DIR="$ROOT_DIR/runtime/wireguard"
WG_CONF="$WG_DIR/wg_confs/wg0.conf"
# shellcheck disable=SC2034 # used by scripts sourcing this library
PEER_DIR="$WG_DIR/peers"

require_installation() {
    [[ -f "$ENV_FILE" && -f "$WG_CONF" ]] || {
        printf 'Run ./scripts/install.sh first.\n' >&2
        exit 1
    }
}

env_value() {
    local key="$1"
    sed -n "s/^${key}=//p" "$ENV_FILE" | tail -n 1
}

validate_name() {
    [[ "$1" =~ ^[A-Za-z0-9_]{1,32}$ ]] || {
        printf 'Peer name must be 1-32 letters, numbers, or underscores.\n' >&2
        exit 1
    }
}

next_peer_ip() {
    local subnet base candidate used
    subnet="$(env_value WG_SUBNET)"
    base="${subnet%/*}"
    base="${base%.*}"

    for suffix in $(seq 2 254); do
        candidate="$base.$suffix"
        used="$(awk -F '[ =/]+' '/^AllowedIPs/ {print $3}' "$WG_CONF")"
        if ! grep -qx "$candidate" <<<"$used"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf 'No free WireGuard peer IP remains in %s.\n' "$subnet" >&2
    exit 1
}

wg_exec() {
    docker compose --project-directory "$ROOT_DIR" exec -T wireguard "$@"
}

wg_key() {
    wg_exec wg "$@"
}
