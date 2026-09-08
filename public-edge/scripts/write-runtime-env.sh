#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
image="$(jq -r '.components.caddy.image // empty' "$RELEASE_DIR/manifests/versions.json")"
[[ -n "$image" ]] || die "Caddy image is missing from manifests/versions.json"
runtime_dir="$root/runtime/public-edge"
state_dir="$root/state/public-edge"
env_file="$runtime_dir/compose.env"
mkdir -p "$runtime_dir" "$state_dir/data" "$state_dir/config"
chown -R root:root "$runtime_dir" "$state_dir"
chmod 700 "$runtime_dir" "$state_dir"
chmod 755 "$state_dir/data" "$state_dir/config"
cat > "$env_file" <<EOF_ENV
SERVER_EDGE_PUBLIC_IMAGE=$image
SERVER_EDGE_PUBLIC_CADDYFILE=$runtime_dir/Caddyfile
SERVER_EDGE_PUBLIC_DATA=$state_dir/data
SERVER_EDGE_PUBLIC_CONFIG=$state_dir/config
EOF_ENV
chown root:root "$env_file"
chmod 600 "$env_file"
log "public-edge runtime env written"
