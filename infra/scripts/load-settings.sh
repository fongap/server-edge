#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
source "$RELEASE_DIR/install/lib/config.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
ensure_platform_config "$RELEASE_DIR" "$root"
ensure_module_config "$RELEASE_DIR" "$root" infra

defaults_file="$RELEASE_DIR/infra/config/defaults.env"
settings_file="$root/config/infra.env"
[[ -s "$defaults_file" ]] || die "missing Infra defaults: $defaults_file"
[[ -s "$settings_file" ]] || die "missing Infra instance config: $settings_file"

# Release defaults first, instance config second. New defaults survive upgrades;
# existing instance overrides are never overwritten.
# shellcheck disable=SC1090
source "$defaults_file"
# shellcheck disable=SC1090
source "$settings_file"

case "$SERVER_EDGE_INFRA_OVERLAY" in
  auto|off|required) ;;
  *) die "SERVER_EDGE_INFRA_OVERLAY must be auto, off, or required" ;;
esac

case "$SERVER_EDGE_INFRA_TAILSCALE_ACCEPT_DNS" in
  true|false) ;;
  *) die "SERVER_EDGE_INFRA_TAILSCALE_ACCEPT_DNS must be true or false" ;;
esac

if [[ "$SERVER_EDGE_INFRA_TAILSCALE_HOSTNAME" != auto ]]; then
  [[ "$SERVER_EDGE_INFRA_TAILSCALE_HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] \
    || die "SERVER_EDGE_INFRA_TAILSCALE_HOSTNAME must be auto or a DNS-safe machine name up to 63 characters"
fi

export SERVER_EDGE_INFRA_OVERLAY
export SERVER_EDGE_INFRA_TAILSCALE_HOSTNAME
export SERVER_EDGE_INFRA_TAILSCALE_ACCEPT_DNS
export SERVER_EDGE_INFRA_SETTINGS_FILE="$settings_file"
