#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
mkdir -p "$root"/{state,secrets,runtime,backups,shared/assets,releases}
mkdir -p "$root/state/infra" "$root/secrets/infra"
chown root:root "$root/secrets" "$root/secrets/infra"
chmod 700 "$root/secrets" "$root/secrets/infra"

bash "$RELEASE_DIR/infra/network/provision.sh"
SERVER_EDGE_ROOT="$root" bash "$RELEASE_DIR/infra/network/overlay/install.sh"
bash "$RELEASE_DIR/infra/host/detect.sh" > "$root/runtime/host.env"
chown root:root "$root/runtime/host.env"
chmod 600 "$root/runtime/host.env"
log "infra installed"
