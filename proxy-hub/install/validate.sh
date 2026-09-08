#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
need_cmd docker
need_cmd jq
SERVER_EDGE_ROOT="$root" bash "$RELEASE_DIR/proxy-hub/scripts/validate-inputs.sh"
for network in edge_egress_ai edge_egress_workers; do
  docker network inspect "$network" >/dev/null 2>&1 || die "required network is missing: $network"
done
log "proxy-hub validation passed"
