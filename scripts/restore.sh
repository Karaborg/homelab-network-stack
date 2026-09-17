#!/usr/bin/env bash

# Restores an archive created by backup.sh. Existing runtime data is moved aside
# instead of deleted, so a failed restore can be rolled back manually.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="${1:-}"

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

[[ -n "$ARCHIVE" ]] || fail "Usage: $(basename "$0") <backup.tar.gz>"
[[ -f "$ARCHIVE" ]] || fail "Archive not found: $ARCHIVE"

invalid_entries="$(tar -tzf "$ARCHIVE" | awk '$0 != ".env" && $0 !~ /^runtime\// { print }')"
[[ -z "$invalid_entries" ]] || fail 'Archive contains unexpected paths; refusing to extract it.'

printf 'This stops the homelab containers and replaces .env and runtime/.\n'
read -r -p 'Continue? [y/N]: ' answer
[[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]] || { printf 'Cancelled.\n'; exit 0; }

STAMP="$(date +%Y%m%d-%H%M%S)"
docker compose --project-directory "$ROOT_DIR" down || true

if [[ -e "$ROOT_DIR/runtime" ]]; then
    mv "$ROOT_DIR/runtime" "$ROOT_DIR/runtime.before-restore-$STAMP"
fi
if [[ -e "$ROOT_DIR/.env" ]]; then
    mv "$ROOT_DIR/.env" "$ROOT_DIR/.env.before-restore-$STAMP"
fi

tar -C "$ROOT_DIR" -xzf "$ARCHIVE"
chmod 600 "$ROOT_DIR/.env"
docker compose --project-directory "$ROOT_DIR" up -d
"$ROOT_DIR/scripts/healthcheck.sh"

printf 'Restore complete. Previous data, if any, is retained with suffix %s.\n' "$STAMP"

