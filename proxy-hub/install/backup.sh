#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
backup_root="$root/backups/proxy-hub"
state_dir="$root/state/proxy-hub"
[[ -d "$state_dir" ]] || exit 0
mkdir -p "$backup_root"
archive="$backup_root/state-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
tar -C "$root/state" -czf "$archive" proxy-hub
chmod 600 "$archive"
log "proxy-hub state backup created: $archive"
