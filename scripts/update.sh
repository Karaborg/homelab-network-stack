#!/usr/bin/env bash

set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/backup.sh"
docker compose --project-directory "$ROOT_DIR" pull
docker compose --project-directory "$ROOT_DIR" up -d
"$ROOT_DIR/scripts/healthcheck.sh"

