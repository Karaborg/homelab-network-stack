# Homelab Network Stack

A zero-touch, Docker Compose-first network stack for Raspberry Pi 5, ARM64,
and x86_64 hosts.

It starts three services:

- **Pi-hole**: DNS filtering and its web dashboard;
- **Unbound**: Pi-hole's private recursive DNS upstream;
- **WireGuard**: an empty VPN server, ready for peers when you create them.

There is no management-dashboard dependency and no post-install web wizard.
The installer generates the local configuration, Pi-hole password, WireGuard
server key, and an empty WireGuard interface automatically.

## Architecture

```text
LAN clients ── DNS :53 ──> Pi-hole ──> Unbound ──> DNS root servers
                                  ^
                                  │
Remote peers ── UDP 51820 ───> WireGuard
```

Unbound is available only inside Docker. Pi-hole is published on the standard
DNS and web ports. WireGuard starts with no peer configuration; peer profiles
are generated only when explicitly requested with the included scripts.

## Install

On a clean Linux host with Docker Engine and Docker Compose v2:

```bash
git clone https://github.com/<your-account>/homelab-network-stack.git
cd homelab-network-stack
./scripts/install.sh
```

The script detects the primary LAN IP and public IPv4, creates `.env`, starts
the stack, seeds the Pi-hole lists, and prints the generated Pi-hole password.
It makes no browser configuration requests.

If the public address is a DDNS hostname or detection is unavailable, set it
before installation:

```bash
WG_ENDPOINT=vpn.example.com ./scripts/install.sh
```

Open Pi-hole at `http://<host-lan-ip>/admin/` using the password printed by the
installer.

## Router and two network interfaces

- Configure router DHCP DNS as the host's stable **Ethernet** IP.
- Forward only `UDP 51820` to that Ethernet IP.
- Do not expose Pi-hole's dashboard to the internet.
- Wi-Fi and Ethernet can remain connected. Keep Ethernet as the default route
  with the lower route metric; the installer detects that primary route.
- The Docker subnet is `172.30.0.0/24`; change it in `compose.yml` only if it
  overlaps your LAN or another Docker network.

## WireGuard peer management

The server intentionally starts with zero clients.

```bash
./scripts/wireguard-add-peer.sh my_phone
./scripts/wireguard-list-peers.sh
./scripts/wireguard-show-peer.sh my_phone
./scripts/wireguard-remove-peer.sh my_phone
```

Peer names may contain only letters, digits, and `_`. `wireguard-add-peer.sh`
prints the client profile location and displays a QR code when `qrencode` is
installed. Every profile uses Pi-hole through the host LAN IP as its DNS and
routes IPv4 traffic through the VPN.

## Persistent data and backups

`runtime/` is ignored by Git. It contains Pi-hole databases and settings,
WireGuard keys, peer profiles, and the server configuration. `.env` is also
private and ignored.

```bash
./scripts/backup.sh
./scripts/restore.sh backups/homelab-network-YYYYMMDD-HHMMSS.tar.gz
```

The archive contains private keys and passwords. Encrypt it before moving it
off-host; never commit or publish it.

## Operations

```bash
docker compose up -d
docker compose down                 # keeps runtime data
./scripts/healthcheck.sh
./scripts/bootstrap-adlists.sh
./scripts/update.sh                 # backup, pull, recreate, verify
```

## Migrating from native Pi-hole / Unbound / PiVPN

This project is a fresh deployment, not an import tool. It deliberately does
not reuse native Pi-hole databases, PiVPN keys, or old clients. Native services
on the same host own ports `53`, `80`, `443`, and `51820`; stop them only in a
planned maintenance window with local console access and a verified backup.
