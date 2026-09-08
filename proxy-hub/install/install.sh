#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
secret_dir="$root/secrets/proxy-hub"
state_dir="$root/state/proxy-hub"
runtime_dir="$root/runtime/proxy-hub"
controller_secret="$secret_dir/controller-secret"

mkdir -p "$secret_dir/providers" "$state_dir/providers" "$runtime_dir"
chown -R root:root "$secret_dir" "$state_dir" "$runtime_dir"
chmod 700 "$secret_dir" "$secret_dir/providers" "$state_dir" "$state_dir/providers" "$runtime_dir"

if [[ ! -s "$controller_secret" ]]; then
  umask 077
  od -An -N24 -tx1 /dev/urandom | tr -d ' \n' > "$controller_secret"
  chown root:root "$controller_secret"
  chmod 600 "$controller_secret"
  log "proxy controller secret generated"
fi

SERVER_EDGE_ROOT="$root" bash "$RELEASE_DIR/proxy-hub/scripts/render-config.sh"
SERVER_EDGE_ROOT="$root" bash "$RELEASE_DIR/proxy-hub/scripts/write-runtime-env.sh"
env_file="$runtime_dir/compose.env"

docker compose --env-file "$env_file" -f "$RELEASE_DIR/proxy-hub/compose.yaml" config >/dev/null
image="$(grep '^SERVER_EDGE_PROXY_IMAGE=' "$env_file" | cut -d= -f2-)"
docker pull "$image" >/dev/null

docker run --rm \
  -v "$runtime_dir/config.yaml:/etc/mihomo/config.yaml:ro" \
  -v "$state_dir:/var/lib/mihomo" \
  "$image" -t -d /var/lib/mihomo -f /etc/mihomo/config.yaml >/dev/null

docker compose --env-file "$env_file" -f "$RELEASE_DIR/proxy-hub/compose.yaml" up -d --remove-orphans
log "proxy-hub installed"
