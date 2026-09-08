#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
source "$RELEASE_DIR/install/lib/config.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
defaults_file="$RELEASE_DIR/proxy-hub/config/defaults.env"
ensure_platform_config "$RELEASE_DIR" "$root"
ensure_module_config "$RELEASE_DIR" "$root" proxy-hub
settings_file="$root/config/proxy-hub.env"
[[ -s "$defaults_file" ]] || die "missing Proxy Hub defaults: $defaults_file"
[[ -s "$settings_file" ]] || die "missing Proxy Hub instance config: $settings_file"
# shellcheck disable=SC1090
source "$defaults_file"
# shellcheck disable=SC1090
source "$settings_file"

validate_bool() {
  local name="$1" value="${!1:-}"
  [[ "$value" == true || "$value" == false ]] || die "$name must be true or false"
}
validate_bind() {
  local name="$1" value="${!1:-}"
  [[ "$value" == loopback || "$value" == tailnet ]] || die "$name must be loopback or tailnet"
}
validate_port() {
  local name="$1" value="${!1:-}"
  [[ "$value" =~ ^[0-9]+$ ]] && (( value >= 1 && value <= 65535 )) || die "$name must be a TCP/UDP port from 1 to 65535"
}
validate_uint() {
  local name="$1" value="${!1:-}"
  [[ "$value" =~ ^[0-9]+$ ]] || die "$name must be a non-negative integer"
}

for name in SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED SERVER_EDGE_PROXY_LOCAL_NODE_PUBLISH SERVER_EDGE_PROXY_EGRESS_ENABLED; do
  validate_bool "$name"
done
[[ "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED" == true || "$SERVER_EDGE_PROXY_LOCAL_NODE_PUBLISH" == false ]] || die "LOCAL node cannot be published when SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED=false"

advertise_host="$SERVER_EDGE_PROXY_LOCAL_NODE_ADVERTISE_HOST"
if [[ "$advertise_host" != auto ]]; then
  [[ "$advertise_host" =~ ^[A-Za-z0-9][A-Za-z0-9.:-]*$ ]] || die "SERVER_EDGE_PROXY_LOCAL_NODE_ADVERTISE_HOST must be auto or a host/IP without scheme or path"
fi

for name in SERVER_EDGE_PROXY_FEED_BIND SERVER_EDGE_PROXY_CONTROLLER_BIND SERVER_EDGE_PROXY_LOCAL_NODE_BIND SERVER_EDGE_PROXY_EGRESS_BIND; do
  validate_bind "$name"
done
for name in SERVER_EDGE_PROXY_EGRESS_PORT SERVER_EDGE_PROXY_LOCAL_NODE_PORT SERVER_EDGE_PROXY_FEED_PORT SERVER_EDGE_PROXY_CONTROLLER_PORT; do
  validate_port "$name"
done
for name in SERVER_EDGE_PROXY_PROVIDER_INTERVAL SERVER_EDGE_PROXY_HEALTH_INTERVAL SERVER_EDGE_PROXY_PROBE_INTERVAL SERVER_EDGE_PROXY_HEALTH_TIMEOUT SERVER_EDGE_PROXY_AUTO_TOLERANCE; do
  validate_uint "$name"
done

case "$SERVER_EDGE_PROXY_EGRESS_POLICY" in
  auto|fallback|select) ;;
  *) die "SERVER_EDGE_PROXY_EGRESS_POLICY must be auto, fallback, or select" ;;
esac
[[ "$SERVER_EDGE_PROXY_HEALTH_URL" == https://* ]] || die "SERVER_EDGE_PROXY_HEALTH_URL must use HTTPS"

export SERVER_EDGE_PROXY_SETTINGS_FILE="$settings_file"
