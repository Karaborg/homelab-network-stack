#!/usr/bin/env bash

# Idempotently applies repository seed lists once Pi-hole is healthy.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST_FILE="$ROOT_DIR/config/pihole/adlists.txt"

[[ -f "$LIST_FILE" ]] || { printf 'No adlist seed found; skipping.\n'; exit 0; }

for attempt in $(seq 1 30); do
    if docker compose --project-directory "$ROOT_DIR" exec -T pihole pihole status >/dev/null 2>&1; then
        break
    fi
    [[ "$attempt" -eq 30 ]] && { printf 'Pi-hole did not become ready.\n' >&2; exit 1; }
    sleep 2
done

while IFS= read -r url || [[ -n "$url" ]]; do
    [[ -z "$url" || "$url" == \#* ]] && continue
    docker compose --project-directory "$ROOT_DIR" exec -T pihole pihole -a adlist add "$url" || true
done <"$LIST_FILE"

docker compose --project-directory "$ROOT_DIR" exec -T pihole pihole -g

