#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
settings_file="$root/config/proxy-hub.env"

if [[ -e "$settings_file" ]]; then
  [[ ! -L "$settings_file" ]] || die "proxy settings file must not be a symlink: $settings_file"
  [[ "$(stat -c '%U' "$settings_file")" == root ]] || die "proxy settings file must be owned by root: $settings_file"
  # shellcheck disable=SC1090
  source "$settings_file"
else
  SERVER_EDGE_PROXY_EGRESS=local
  SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL=auto
fi

case "${SERVER_EDGE_PROXY_EGRESS:-}" in
  off|local|provider|hybrid) ;;
  *) die "SERVER_EDGE_PROXY_EGRESS must be off, local, provider, or hybrid" ;;
esac

base_url="${SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL:-auto}"
if [[ "$base_url" != auto ]]; then
  [[ "$base_url" =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] \
    || die "SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL must be auto or an HTTPS origin without a path or port"
fi

export SERVER_EDGE_PROXY_EGRESS
export SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL="$base_url"
export SERVER_EDGE_PROXY_SETTINGS_FILE="$settings_file"
