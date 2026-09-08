#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

[[ $EUID -eq 0 ]] || die "endpoint discovery requires root"
root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
env_file="$root/runtime/proxy-hub/compose.env"
[[ -s "$env_file" ]] || die "missing proxy runtime env: $env_file"
# shellcheck disable=SC1090
source "$env_file"

printf 'subscription=%s/%s/mihomo.yaml\n' \
  "$SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL" "$SERVER_EDGE_PROXY_FEED_TOKEN"
printf 'controller=http://%s:9090\n' "$SERVER_EDGE_PROXY_CONTROLLER_BIND_IP"

case "$SERVER_EDGE_PROXY_EGRESS" in
  local|hybrid)
    printf 'local-node=socks5://%s:7891\n' "$SERVER_EDGE_PROXY_NODE_HOST"
    ;;
esac

if [[ "$SERVER_EDGE_PROXY_EGRESS" != off ]]; then
  printf 'host-egress=http://127.0.0.1:7890\n'
  printf 'container-egress=http://proxy-hub:7890\n'
fi
