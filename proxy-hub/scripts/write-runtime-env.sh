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

bind_ip=127.0.0.1
if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  candidate="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
  [[ -n "$candidate" ]] && bind_ip="$candidate"
fi

feed_token_file="$root/secrets/proxy-hub/subscription-token"
[[ -s "$feed_token_file" ]] || die "missing subscription token"
feed_token="$(tr -d '\r\n' < "$feed_token_file")"
[[ "$feed_token" =~ ^[A-Fa-f0-9]{48}$ ]] || die "subscription token must be 48 hexadecimal characters"

subscription_base="$SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL"
if [[ "$subscription_base" == auto ]]; then
  subscription_base="http://$bind_ip:8780"
fi

mkdir -p "$runtime_dir"
cat > "$env_file" <<EOF_ENV
SERVER_EDGE_PROXY_IMAGE=$image
SERVER_EDGE_PROXY_FEED_IMAGE=$feed_image
SERVER_EDGE_PROXY_CONFIG=$runtime_dir/config.yaml
SERVER_EDGE_PROXY_STATE=$root/state/proxy-hub
SERVER_EDGE_PROXY_FEED_ROOT=$root/state/proxy-hub/feed
SERVER_EDGE_PROXY_FEED_TOKEN=$feed_token
SERVER_EDGE_PROXY_FEED_BIND_IP=$bind_ip
SERVER_EDGE_PROXY_CONTROLLER_BIND_IP=$bind_ip
SERVER_EDGE_PROXY_NODE_BIND_IP=$bind_ip
SERVER_EDGE_PROXY_NODE_HOST=$bind_ip
SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL=$subscription_base
SERVER_EDGE_PROXY_EGRESS=$SERVER_EDGE_PROXY_EGRESS
EOF_ENV
chown root:root "$env_file"
chmod 600 "$env_file"
log "proxy runtime env written: egress=$SERVER_EDGE_PROXY_EGRESS bind=$bind_ip"
