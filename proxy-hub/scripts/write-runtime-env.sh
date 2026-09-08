#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
source "$HERE/load-settings.sh"
runtime_dir="$root/runtime/proxy-hub"
env_file="$runtime_dir/compose.env"
image="$(jq -r '.components.mihomo.image // empty' "$RELEASE_DIR/manifests/versions.json")"
feed_image="$(jq -r '.components.busybox.image // empty' "$RELEASE_DIR/manifests/versions.json")"
[[ -n "$image" ]] || die "Mihomo image is missing from manifests/versions.json"
[[ -n "$feed_image" ]] || die "subscription feed image is missing from manifests/versions.json"

resolve_bind_ip() {
  local mode="$1"
  case "$mode" in
    loopback) printf '%s\n' '127.0.0.1' ;;
    tailnet)
      command -v tailscale >/dev/null 2>&1 || die "Tailnet bind requested but tailscale is unavailable"
      tailscale status >/dev/null 2>&1 || die "Tailnet bind requested but Tailscale is not connected"
      local ip
      ip="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
      [[ -n "$ip" ]] || die "Tailnet bind requested but no Tailscale IPv4 is available"
      printf '%s\n' "$ip"
      ;;
  esac
}

feed_bind_ip="$(resolve_bind_ip "$SERVER_EDGE_PROXY_FEED_BIND")"
controller_bind_ip="$(resolve_bind_ip "$SERVER_EDGE_PROXY_CONTROLLER_BIND")"
node_bind_ip="$(resolve_bind_ip "$SERVER_EDGE_PROXY_LOCAL_NODE_BIND")"
egress_bind_ip="$(resolve_bind_ip "$SERVER_EDGE_PROXY_EGRESS_BIND")"

feed_token_file="$root/secrets/proxy-hub/subscription-token"
[[ -s "$feed_token_file" ]] || die "missing subscription token"
feed_token="$(tr -d '\r\n' < "$feed_token_file")"
[[ "$feed_token" =~ ^[A-Fa-f0-9]{48}$ ]] || die "subscription token must be 48 hexadecimal characters"

subscription_origin="$SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN"
if [[ "$subscription_origin" == auto ]]; then
  subscription_origin="http://$feed_bind_ip:$SERVER_EDGE_PROXY_FEED_PORT"
fi

mkdir -p "$runtime_dir"
cat > "$env_file" <<EOF_ENV
SERVER_EDGE_PROXY_IMAGE=$image
SERVER_EDGE_PROXY_FEED_IMAGE=$feed_image
SERVER_EDGE_PROXY_CONFIG=$runtime_dir/config.yaml
SERVER_EDGE_PROXY_STATE=$root/state/proxy-hub
SERVER_EDGE_PROXY_FEED_ROOT=$root/state/proxy-hub/feed
SERVER_EDGE_PROXY_FEED_TOKEN=$feed_token
SERVER_EDGE_PROXY_FEED_BIND_IP=$feed_bind_ip
SERVER_EDGE_PROXY_CONTROLLER_BIND_IP=$controller_bind_ip
SERVER_EDGE_PROXY_NODE_BIND_IP=$node_bind_ip
SERVER_EDGE_PROXY_EGRESS_BIND_IP=$egress_bind_ip
SERVER_EDGE_PROXY_NODE_HOST=$node_bind_ip
SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN=$subscription_origin
SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED=$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED
SERVER_EDGE_PROXY_EGRESS_ENABLED=$SERVER_EDGE_PROXY_EGRESS_ENABLED
SERVER_EDGE_PROXY_EGRESS_POLICY=$SERVER_EDGE_PROXY_EGRESS_POLICY
SERVER_EDGE_PROXY_EGRESS_PORT=$SERVER_EDGE_PROXY_EGRESS_PORT
SERVER_EDGE_PROXY_LOCAL_NODE_PORT=$SERVER_EDGE_PROXY_LOCAL_NODE_PORT
SERVER_EDGE_PROXY_FEED_PORT=$SERVER_EDGE_PROXY_FEED_PORT
SERVER_EDGE_PROXY_CONTROLLER_PORT=$SERVER_EDGE_PROXY_CONTROLLER_PORT
SERVER_EDGE_PROXY_PROVIDER_INTERVAL=$SERVER_EDGE_PROXY_PROVIDER_INTERVAL
SERVER_EDGE_PROXY_HEALTH_URL=$SERVER_EDGE_PROXY_HEALTH_URL
SERVER_EDGE_PROXY_HEALTH_INTERVAL=$SERVER_EDGE_PROXY_HEALTH_INTERVAL
SERVER_EDGE_PROXY_PROBE_INTERVAL=$SERVER_EDGE_PROXY_PROBE_INTERVAL
SERVER_EDGE_PROXY_HEALTH_TIMEOUT=$SERVER_EDGE_PROXY_HEALTH_TIMEOUT
SERVER_EDGE_PROXY_AUTO_TOLERANCE=$SERVER_EDGE_PROXY_AUTO_TOLERANCE
EOF_ENV
chown root:root "$env_file"
chmod 600 "$env_file"
log "proxy runtime env written: providers=required local-node=$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED egress=$SERVER_EDGE_PROXY_EGRESS_ENABLED/$SERVER_EDGE_PROXY_EGRESS_POLICY"
