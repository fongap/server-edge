#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
source "$RELEASE_DIR/proxy-hub/scripts/compose-files.sh"

[[ $EUID -eq 0 ]] || die "proxy-hub health check requires root"
root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
runtime_dir="$root/runtime/proxy-hub"
env_file="$runtime_dir/compose.env"
controller_secret_file="$root/secrets/proxy-hub/controller-secret"
provider_dir="$root/secrets/proxy-hub/providers"
[[ -s "$env_file" ]] || die "missing proxy runtime env: $env_file"
[[ -s "$controller_secret_file" ]] || die "missing proxy controller secret"
# shellcheck disable=SC1090
source "$env_file"
controller_secret="$(tr -d '\r\n' < "$controller_secret_file")"
proxy_compose_files "$RELEASE_DIR" "$SERVER_EDGE_PROXY_EGRESS"

for service in proxy feed; do
  container_id="$(docker compose --env-file "$env_file" "${PROXY_COMPOSE_ARGS[@]}" ps -q "$service")"
  [[ -n "$container_id" ]] || die "proxy-hub $service container is not running"
  [[ "$(docker inspect -f '{{.State.Running}}' "$container_id")" == true ]] || die "proxy-hub $service container is not running"
done

curl -fsS --max-time 5 \
  -H "Authorization: Bearer $controller_secret" \
  "http://${SERVER_EDGE_PROXY_CONTROLLER_BIND_IP}:9090/version" >/dev/null \
  || die "proxy controller health check failed"

feed_url="http://${SERVER_EDGE_PROXY_FEED_BIND_IP}:8780/${SERVER_EDGE_PROXY_FEED_TOKEN}/mihomo.yaml"
curl -fsS --max-time 5 "$feed_url" >/dev/null \
  || die "proxy subscription feed health check failed"

mapfile -t providers < <(find "$provider_dir" -maxdepth 1 -type f -name '*.url' -printf '%f\n' | LC_ALL=C sort)
for filename in "${providers[@]}"; do
  name="${filename%.url}"
  cache="$root/state/proxy-hub/feed/$SERVER_EDGE_PROXY_FEED_TOKEN/providers/$name.yaml"
  ready=false
  for _ in {1..15}; do
    if [[ -s "$cache" ]]; then ready=true; break; fi
    sleep 2
  done
  [[ "$ready" == true ]] || die "proxy provider cache is not ready: $name"
  curl -fsS --max-time 5 \
    "http://${SERVER_EDGE_PROXY_FEED_BIND_IP}:8780/${SERVER_EDGE_PROXY_FEED_TOKEN}/providers/$name.yaml" >/dev/null \
    || die "proxy provider feed health check failed: $name"
done

if [[ "$SERVER_EDGE_PROXY_EGRESS" != off ]]; then
  curl -fsS --max-time 20 \
    --proxy http://127.0.0.1:7890 \
    https://cp.cloudflare.com >/dev/null \
    || die "proxy unified egress health check failed"
fi

if [[ "$SERVER_EDGE_PROXY_EGRESS" == local || "$SERVER_EDGE_PROXY_EGRESS" == hybrid ]]; then
  curl -fsS --max-time 20 \
    --socks5-hostname "${SERVER_EDGE_PROXY_NODE_HOST}:7891" \
    https://cp.cloudflare.com >/dev/null \
    || die "LOCAL node health check failed"
fi

log "proxy-hub health check passed: egress=$SERVER_EDGE_PROXY_EGRESS feed=ok"
