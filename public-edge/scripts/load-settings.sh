#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
source "$RELEASE_DIR/install/lib/config.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
defaults="$RELEASE_DIR/public-edge/config/defaults.env"
instance="$root/config/public-edge.env"

ensure_module_config "$RELEASE_DIR" "$root" public-edge
# shellcheck disable=SC1090
source "$defaults"
if [[ -s "$instance" ]]; then
  # shellcheck disable=SC1090
  source "$instance"
fi

valid_ipv4() {
  local value="$1" octet
  local -a parts
  [[ "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  IFS=. read -r -a parts <<<"$value"
  [[ ${#parts[@]} -eq 4 ]] || return 1
  for octet in "${parts[@]}"; do
    [[ "$octet" =~ ^[0-9]+$ ]] || return 1
    (( 10#$octet >= 0 && 10#$octet <= 255 )) || return 1
  done
}

valid_ipv4 "$SERVER_EDGE_PUBLIC_BIND_IP" \
  || die "SERVER_EDGE_PUBLIC_BIND_IP must be an IPv4 address"

export SERVER_EDGE_PUBLIC_BIND_IP
