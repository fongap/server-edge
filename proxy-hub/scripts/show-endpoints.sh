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
  "$SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN" "$SERVER_EDGE_PROXY_FEED_TOKEN"
printf 'controller=http://%s:%s\n' \
  "$SERVER_EDGE_PROXY_CONTROLLER_BIND_IP" "$SERVER_EDGE_PROXY_CONTROLLER_PORT"

if [[ "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED" == true ]]; then
  printf 'local-node=socks5://%s:%s\n' \
    "$SERVER_EDGE_PROXY_NODE_HOST" "$SERVER_EDGE_PROXY_LOCAL_NODE_PORT"
fi

if [[ "$SERVER_EDGE_PROXY_EGRESS_ENABLED" == true ]]; then
  printf 'host-egress=http://%s:%s\n' \
    "$SERVER_EDGE_PROXY_EGRESS_BIND_IP" "$SERVER_EDGE_PROXY_EGRESS_PORT"
  printf 'container-egress=http://proxy-hub:%s\n' "$SERVER_EDGE_PROXY_EGRESS_PORT"
fi

printf 'aggregation=providers-required\n'
printf 'egress-policy=%s\n' "$SERVER_EDGE_PROXY_EGRESS_POLICY"
