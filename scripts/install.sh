#!/usr/bin/env bash

# First-run installer. It writes a complete, local-only configuration and
# creates an empty WireGuard server (no client peers).
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

command -v docker >/dev/null || fail 'Docker is not installed.'
docker compose version >/dev/null || fail 'Docker Compose v2 is required.'
command -v curl >/dev/null || fail 'curl is required to detect the public IP address.'
command -v ip >/dev/null || fail 'iproute2 is required to detect the primary LAN address.'

if [[ -f "$ENV_FILE" ]]; then
    fail '.env already exists. Edit it manually or remove it only if this is a new installation.'
fi

timezone="${TZ:-$(timedatectl show --property=Timezone --value 2>/dev/null || printf 'UTC')}"
host_lan_ip="${HOST_LAN_IP:-$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i = 1; i <= NF; i++) if ($i == "src") print $(i + 1); exit}') }"
[[ -n "$host_lan_ip" ]] || fail 'Could not detect a primary LAN IPv4 address. Set HOST_LAN_IP and run again.'

if [[ "${WG_ENDPOINT:-auto}" == "auto" ]]; then
    wg_endpoint="$(curl -4fsS --max-time 10 https://api.ipify.org || true)"
else
    wg_endpoint="$WG_ENDPOINT"
fi
[[ -n "$wg_endpoint" ]] || fail 'Could not detect the public IPv4 address. Set WG_ENDPOINT=your-ddns-name-or-public-ip and run again.'

command -v openssl >/dev/null || fail 'openssl is required to generate the Pi-hole password.'
pihole_password="${PIHOLE_PASSWORD:-$(openssl rand -hex 24)}"
puid="${PUID:-$(id -u)}"
pgid="${PGID:-$(id -g)}"
wg_port="${WG_PORT:-51820}"
wg_subnet="${WG_SUBNET:-10.66.0.0/24}"
[[ "$wg_subnet" =~ ^([0-9]{1,3}\.){3}0/[0-9]{1,2}$ ]] || fail 'WG_SUBNET must look like 10.66.0.0/24.'
wg_server_ip="${wg_subnet%/*}"
wg_server_ip="${wg_server_ip%.*}.1"

umask 077
cat >"$ENV_FILE" <<EOF
TZ=$timezone
HOST_LAN_IP=$host_lan_ip
PIHOLE_PASSWORD=$pihole_password
PIHOLE_WEB_PORT=80
PIHOLE_WEB_HTTPS_PORT=443
DNS_PORT=53
WG_PORT=$wg_port
WG_ENDPOINT=$wg_endpoint
WG_SUBNET=$wg_subnet
PUID=$puid
PGID=$pgid
EOF

mkdir -p "$ROOT_DIR/runtime/pihole" "$ROOT_DIR/runtime/wireguard/wg_confs" "$ROOT_DIR/runtime/wireguard/peers" "$ROOT_DIR/backups"

printf 'Preparing an empty WireGuard server...\n'
server_private_key="$(docker compose --project-directory "$ROOT_DIR" run --rm -T --no-deps --entrypoint wg wireguard genkey)"
server_public_key="$(printf '%s' "$server_private_key" | docker compose --project-directory "$ROOT_DIR" run --rm -T --no-deps --entrypoint wg wireguard pubkey)"
cat >"$ROOT_DIR/runtime/wireguard/wg_confs/wg0.conf" <<EOF
# This file is managed by scripts/wireguard-*.sh. Do not hand-edit peer blocks.
[Interface]
Address = $wg_server_ip/${wg_subnet#*/}
ListenPort = $wg_port
PrivateKey = $server_private_key
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

EOF
printf '%s\n' "$server_public_key" >"$ROOT_DIR/runtime/wireguard/server-public.key"
chmod 600 "$ROOT_DIR/runtime/wireguard/wg_confs/wg0.conf" "$ROOT_DIR/runtime/wireguard/server-public.key"

printf 'Starting containers...\n'
docker compose --project-directory "$ROOT_DIR" up -d

printf 'Waiting for Pi-hole, then applying seed adlists...\n'
"$ROOT_DIR/scripts/bootstrap-adlists.sh"

cat <<EOF

Installed successfully.

Pi-hole:       http://${host_lan_ip}/admin/
Pi-hole password: ${pihole_password}

WireGuard is running with zero clients. Add one when needed:
  ./scripts/wireguard-add-peer.sh iphone

Router: forward UDP ${wg_port} to ${host_lan_ip}.
Detected WireGuard endpoint: ${wg_endpoint}
EOF
