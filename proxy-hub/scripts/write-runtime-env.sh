#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
runtime_dir="$root/runtime/proxy-hub"
env_file="$runtime_dir/compose.env"
image="$(jq -r '.components.mihomo.image // empty' "$RELEASE_DIR/manifests/versions.json")"
[[ -n "$image" ]] || die "Mihomo image is missing from manifests/versions.json"

bind_ip=127.0.0.1
if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  candidate="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
  [[ -n "$candidate" ]] && bind_ip="$candidate"
fi

mkdir -p "$runtime_dir"
cat > "$env_file" <<EOF_ENV
SERVER_EDGE_PROXY_IMAGE=$image
SERVER_EDGE_PROXY_CONFIG=$runtime_dir/config.yaml
SERVER_EDGE_PROXY_STATE=$root/state/proxy-hub
SERVER_EDGE_PROXY_BIND_IP=$bind_ip
SERVER_EDGE_PROXY_CONTROLLER_BIND_IP=$bind_ip
EOF_ENV
chown root:root "$env_file"
chmod 600 "$env_file"
log "proxy runtime env written: proxy=$bind_ip controller=$bind_ip"
