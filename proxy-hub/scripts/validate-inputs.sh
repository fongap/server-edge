#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
source "$HERE/load-settings.sh"
provider_dir="$root/secrets/proxy-hub/providers"

[[ -d "$provider_dir" ]] || die "proxy provider directory is missing: $provider_dir"
mapfile -t providers < <(find "$provider_dir" -maxdepth 1 -type f -name '*.url' -printf '%f\n' | LC_ALL=C sort)

if [[ "$SERVER_EDGE_PROXY_EGRESS" == provider || "$SERVER_EDGE_PROXY_EGRESS" == hybrid ]]; then
  [[ ${#providers[@]} -gt 0 ]] || die "egress mode $SERVER_EDGE_PROXY_EGRESS requires at least one provider URL file"
fi

for filename in "${providers[@]}"; do
  name="${filename%.url}"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || die "invalid provider name: $filename"
  path="$provider_dir/$filename"
  [[ ! -L "$path" ]] || die "provider URL file must not be a symlink: $path"
  [[ "$(stat -c '%U' "$path")" == root ]] || die "provider URL file must be owned by root: $path"
  mode="$(stat -c '%a' "$path")"
  [[ "$mode" == 600 || "$mode" == 400 ]] || die "provider URL file must use mode 0600 or 0400: $path (got $mode)"
  [[ "$(grep -c '^' "$path")" -le 1 ]] || die "provider URL file must contain exactly one line: $path"
  url="$(tr -d '\r\n' < "$path")"
  [[ "$url" == https://* ]] || die "provider URL must use HTTPS: $path"
done

log "proxy inputs accepted: egress=$SERVER_EDGE_PROXY_EGRESS providers=${#providers[@]}"
