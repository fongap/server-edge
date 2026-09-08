#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

[[ $EUID -eq 0 ]] || die "public-edge health check requires root"
root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
runtime_dir="$root/runtime/public-edge"
env_file="$runtime_dir/compose.env"
source "$RELEASE_DIR/public-edge/scripts/load-subscription-contract.sh"

if [[ "$SERVER_EDGE_PUBLIC_ACTIVE" != true ]]; then
  if docker ps -q --filter label=com.docker.compose.project=server-edge-public-edge | grep -q .; then
    die "public-edge should be inactive but a managed container is running"
  fi
  log "public-edge health check passed: inactive"
  exit 0
fi

[[ -s "$env_file" ]] || die "missing public-edge runtime env: $env_file"
# shellcheck disable=SC1090
source "$env_file"
container_id="$(docker compose --env-file "$env_file" -f "$RELEASE_DIR/public-edge/compose.yaml" ps -q caddy)"
[[ -n "$container_id" ]] || die "public-edge Caddy container is not running"
[[ "$(docker inspect -f '{{.State.Running}}' "$container_id")" == true ]] || die "public-edge Caddy container is not running"

docker compose --env-file "$env_file" -f "$RELEASE_DIR/public-edge/compose.yaml" exec -T caddy \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null \
  || die "public-edge Caddy config validation failed"

docker port "$container_id" 80/tcp >/dev/null 2>&1 || die "public-edge port 80 is not published"
docker port "$container_id" 443/tcp >/dev/null 2>&1 || die "public-edge port 443 is not published"

feed_image="$(jq -r '.components.busybox.image // empty' "$RELEASE_DIR/manifests/versions.json")"
[[ -n "$feed_image" ]] || die "BusyBox image missing for public-edge upstream check"
docker run --rm --network edge_service_proxy_public "$feed_image" \
  wget -q -O /dev/null http://proxy-feed:8080/index.html \
  || die "public-edge cannot reach proxy subscription feed"

log "public-edge health check passed: host=$SERVER_EDGE_PUBLIC_HOST"
