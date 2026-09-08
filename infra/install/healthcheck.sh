#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
docker info >/dev/null || die "Docker health check failed"
docker compose version >/dev/null || die "Compose health check failed"

while IFS= read -r network; do
  docker network inspect "$network" >/dev/null 2>&1 || die "missing managed network: $network"
done < <(jq -r '.networks[].name' "$RELEASE_DIR/manifests/networks.json")

[[ "$(stat -c '%a' "$root/secrets")" == 700 ]] || die "invalid permissions on $root/secrets"
SERVER_EDGE_ROOT="$root" bash "$RELEASE_DIR/infra/network/overlay/healthcheck.sh"
log "infra health check passed"
