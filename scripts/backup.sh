#!/usr/bin/env bash

# The archive contains WireGuard private keys and Pi-hole data.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$ROOT_DIR/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DIR/homelab-network-$STAMP.tar.gz"

mkdir -p "$BACKUP_DIR"
tar -C "$ROOT_DIR" -czf "$ARCHIVE" runtime .env
chmod 600 "$ARCHIVE"
printf 'Backup created: %s\n' "$ARCHIVE"
printf 'Encrypt this archive before storing it outside the host.\n'
