#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
defaults_file="$RELEASE_DIR/proxy-hub/config/defaults.env"
settings_file="$root/config/proxy-hub.env"
[[ -s "$defaults_file" ]] || die "missing Proxy Hub defaults: $defaults_file"
# shellcheck disable=SC1090
source "$defaults_file"

if [[ -e "$settings_file" ]]; then
  [[ ! -L "$settings_file" ]] || die "proxy settings file must not be a symlink: $settings_file"
  [[ "$(stat -c '%U' "$settings_file")" == root ]] || die "proxy settings file must be owned by root: $settings_file"
  # shellcheck disable=SC1090
  source "$settings_file"
fi

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

validate_bool SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED
validate_bool SERVER_EDGE_PROXY_EGRESS_ENABLED
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

origin="$SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN"
if [[ "$origin" != auto ]]; then
  [[ "$origin" =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] \
    || die "SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN must be auto or an HTTPS origin without path or port"
fi
[[ "$SERVER_EDGE_PROXY_HEALTH_URL" == https://* ]] || die "SERVER_EDGE_PROXY_HEALTH_URL must use HTTPS"

export SERVER_EDGE_PROXY_SETTINGS_FILE="$settings_file"
