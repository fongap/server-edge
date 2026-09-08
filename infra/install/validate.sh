#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
source "$RELEASE_DIR/infra/scripts/load-settings.sh"

bash "$RELEASE_DIR/infra/host/validate.sh"
need_cmd docker
docker info >/dev/null || die "Docker daemon is not available"
docker compose version >/dev/null || die "Docker Compose v2 is not available"
log "infra validation passed: overlay=$SERVER_EDGE_INFRA_OVERLAY"
