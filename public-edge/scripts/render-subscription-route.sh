#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
source "$HERE/load-subscription-contract.sh"
runtime_dir="$root/runtime/public-edge"
caddyfile="$runtime_dir/Caddyfile"
mkdir -p "$runtime_dir"
chown root:root "$runtime_dir"
chmod 700 "$runtime_dir"

if [[ "$SERVER_EDGE_PUBLIC_ACTIVE" != true ]]; then
  rm -f "$caddyfile"
  log "public subscription route inactive"
  exit 0
fi

cat > "$caddyfile" <<EOF_CADDY
$SERVER_EDGE_PUBLIC_ORIGIN {
    reverse_proxy proxy-feed:8080
}
EOF_CADDY
chown root:root "$caddyfile"
chmod 644 "$caddyfile"
log "public subscription route rendered: host=$SERVER_EDGE_PUBLIC_HOST"
