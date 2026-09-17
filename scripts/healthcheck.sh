#!/usr/bin/env bash

set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker compose --project-directory "$ROOT_DIR" ps
docker compose --project-directory "$ROOT_DIR" exec -T pihole pihole status
docker compose --project-directory "$ROOT_DIR" exec -T wireguard wg show wg0
