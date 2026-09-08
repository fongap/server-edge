#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
source "$RELEASE_DIR/install/lib/config.sh"
source "$RELEASE_DIR/proxy-hub/scripts/compose-files.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
secret_dir="$root/secrets/proxy-hub"
state_dir="$root/state/proxy-hub"
runtime_dir="$root/runtime/proxy-hub"
controller_secret="$secret_dir/controller-secret"
subscription_token="$secret_dir/subscription-token"

ensure_platform_config "$RELEASE_DIR" "$root"
ensure_module_config "$RELEASE_DIR" "$root" proxy-hub
mkdir -p "$secret_dir/providers" "$state_dir/feed" "$runtime_dir"
chown -R root:root "$secret_dir" "$state_dir" "$runtime_dir"
chmod 700 "$secret_dir" "$secret_dir/providers" "$state_dir" "$state_dir/feed" "$runtime_dir"
source "$RELEASE_DIR/proxy-hub/scripts/load-settings.sh"

if [[ ! -s "$controller_secret" ]]; then
  umask 077
  od -An -N24 -tx1 /dev/urandom | tr -d ' \n' > "$controller_secret"
  chown root:root "$controller_secret"
  chmod 600 "$controller_secret"
  log "proxy controller secret generated"
fi

if [[ ! -s "$subscription_token" ]]; then
  umask 077
  od -An -N24 -tx1 /dev/urandom | tr -d ' \n' > "$subscription_token"
  chown root:root "$subscription_token"
  chmod 600 "$subscription_token"
  log "proxy subscription token generated"
fi

bash "$RELEASE_DIR/proxy-hub/scripts/validate-inputs.sh"
bash "$RELEASE_DIR/proxy-hub/scripts/write-runtime-env.sh"
bash "$RELEASE_DIR/proxy-hub/scripts/render-config.sh"
bash "$RELEASE_DIR/proxy-hub/scripts/render-feed.sh"
bash "$RELEASE_DIR/proxy-hub/scripts/write-public-contract.sh"
bash "$RELEASE_DIR/proxy-hub/scripts/write-egress-contract.sh"
env_file="$runtime_dir/compose.env"
# shellcheck disable=SC1090
source "$env_file"
proxy_compose_files "$RELEASE_DIR" "$SERVER_EDGE_PROXY_EGRESS_ENABLED" "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED"

docker compose --env-file "$env_file" "${PROXY_COMPOSE_ARGS[@]}" config >/dev/null
docker compose --env-file "$env_file" "${PROXY_COMPOSE_ARGS[@]}" pull >/dev/null

docker run --rm \
  -v "$runtime_dir/config.yaml:/etc/mihomo/config.yaml:ro" \
  -v "$state_dir:/var/lib/mihomo" \
  "$SERVER_EDGE_PROXY_IMAGE" -t -d /var/lib/mihomo -f /etc/mihomo/config.yaml >/dev/null

docker compose --env-file "$env_file" "${PROXY_COMPOSE_ARGS[@]}" up -d --remove-orphans
log "proxy-hub installed: aggregation=required local-node=$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED egress=$SERVER_EDGE_PROXY_EGRESS_ENABLED/$SERVER_EDGE_PROXY_EGRESS_POLICY"
