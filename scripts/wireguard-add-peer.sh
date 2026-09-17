#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091 # resolved from SCRIPT_DIR at runtime
source "$SCRIPT_DIR/wireguard-lib.sh"

name="${1:-}"
require_installation
validate_name "$name"

peer_file="$PEER_DIR/$name.conf"
[[ ! -e "$peer_file" ]] || { printf 'Peer already exists: %s\n' "$name" >&2; exit 1; }

peer_ip="$(next_peer_ip)"
private_key="$(wg_key genkey)"
public_key="$(printf '%s' "$private_key" | wg_key pubkey)"
preshared_key="$(wg_key genpsk)"
server_public_key="$(cat "$WG_DIR/server-public.key")"
endpoint="$(env_value WG_ENDPOINT)"
port="$(env_value WG_PORT)"
dns="$(env_value HOST_LAN_IP)"
subnet="$(env_value WG_SUBNET)"
prefix="${subnet#*/}"

cat >"$peer_file" <<EOF
[Interface]
PrivateKey = $private_key
Address = $peer_ip/$prefix
DNS = $dns

[Peer]
PublicKey = $server_public_key
PresharedKey = $preshared_key
Endpoint = $endpoint:$port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
chmod 600 "$peer_file"

cat >>"$WG_CONF" <<EOF
# homelab-peer:$name
[Peer]
PublicKey = $public_key
PresharedKey = $preshared_key
AllowedIPs = $peer_ip/32

EOF

if ! printf '%s' "$preshared_key" | docker compose --project-directory "$ROOT_DIR" exec -T -i wireguard \
    wg set wg0 peer "$public_key" preshared-key /dev/stdin allowed-ips "$peer_ip/32"; then
    printf 'Could not apply peer live. The configuration was written; restart WireGuard after checking its logs.\n' >&2
    exit 1
fi


printf 'Peer created: %s (%s)\nConfig: %s\n' "$name" "$peer_ip" "$peer_file"
if command -v qrencode >/dev/null 2>&1; then
    qrencode -t ansiutf8 <"$peer_file"
else
    printf 'Install qrencode to display a terminal QR code, or import the config file directly.\n'
fi
