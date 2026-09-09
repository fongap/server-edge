#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
need_cmd docker
need_cmd jq
need_cmd ss
source "$RELEASE_DIR/public-edge/scripts/load-settings.sh"
source "$RELEASE_DIR/public-edge/scripts/load-subscription-contract.sh"
if [[ "$SERVER_EDGE_PUBLIC_ACTIVE" == true ]]; then
  docker network inspect edge_service_proxy_public >/dev/null 2>&1 \
    || die "required network is missing: edge_service_proxy_public"
fi
log "public-edge validation passed: active=$SERVER_EDGE_PUBLIC_ACTIVE bind=$SERVER_EDGE_PUBLIC_BIND_IP"
