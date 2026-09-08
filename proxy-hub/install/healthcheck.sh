#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

[[ $EUID -eq 0 ]] || die "proxy-hub health check requires root"
root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
runtime_dir="$root/runtime/proxy-hub"
env_file="$runtime_dir/compose.env"
secret_file="$root/secrets/proxy-hub/controller-secret"
[[ -s "$env_file" ]] || die "missing proxy runtime env: $env_file"
[[ -s "$secret_file" ]] || die "missing proxy controller secret"
# shellcheck disable=SC1090
source "$env_file"
secret="$(tr -d '\r\n' < "$secret_file")"

container_id="$(docker compose --env-file "$env_file" -f "$RELEASE_DIR/proxy-hub/compose.yaml" ps -q proxy)"
[[ -n "$container_id" ]] || die "proxy-hub container is not running"
[[ "$(docker inspect -f '{{.State.Running}}' "$container_id")" == true ]] || die "proxy-hub container is not running"

curl -fsS --max-time 5 \
  -H "Authorization: Bearer $secret" \
  "http://${SERVER_EDGE_PROXY_CONTROLLER_BIND_IP}:9090/version" >/dev/null \
  || die "proxy controller health check failed"

curl -fsS --max-time 20 \
  --proxy "http://${SERVER_EDGE_PROXY_BIND_IP}:7890" \
  https://cp.cloudflare.com >/dev/null \
  || die "proxy egress health check failed"

log "proxy-hub health check passed: LOCAL node reachable at ${SERVER_EDGE_PROXY_BIND_IP}:7890"
