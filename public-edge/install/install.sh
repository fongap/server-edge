#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
runtime_dir="$root/runtime/public-edge"
env_file="$runtime_dir/compose.env"
source "$RELEASE_DIR/public-edge/scripts/load-subscription-contract.sh"

if [[ "$SERVER_EDGE_PUBLIC_ACTIVE" != true ]]; then
  if [[ -s "$env_file" ]]; then
    docker compose --env-file "$env_file" -f "$RELEASE_DIR/public-edge/compose.yaml" down --remove-orphans >/dev/null 2>&1 || true
  fi
  mkdir -p "$runtime_dir"
  printf 'inactive\n' > "$runtime_dir/status"
  chown root:root "$runtime_dir/status"
  chmod 644 "$runtime_dir/status"
  log "public-edge inactive: no custom subscription origin"
  exit 0
fi

bash "$RELEASE_DIR/public-edge/scripts/render-subscription-route.sh"
bash "$RELEASE_DIR/public-edge/scripts/write-runtime-env.sh"
# shellcheck disable=SC1090
source "$env_file"

docker compose --env-file "$env_file" -f "$RELEASE_DIR/public-edge/compose.yaml" config >/dev/null
docker pull "$SERVER_EDGE_PUBLIC_IMAGE" >/dev/null
docker run --rm \
  -v "$runtime_dir/Caddyfile:/etc/caddy/Caddyfile:ro" \
  "$SERVER_EDGE_PUBLIC_IMAGE" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

docker compose --env-file "$env_file" -f "$RELEASE_DIR/public-edge/compose.yaml" up -d --remove-orphans
printf 'active\n' > "$runtime_dir/status"
chown root:root "$runtime_dir/status"
chmod 644 "$runtime_dir/status"
log "public-edge subscription route installed: host=$SERVER_EDGE_PUBLIC_HOST"
