#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
source "$RELEASE_DIR/install/lib/config.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"

mkdir -p "$root"/{config,state,secrets,runtime,backups,shared/assets,releases}
mkdir -p "$root/runtime/contracts" "$root/state/infra" "$root/secrets/infra"
chown root:root "$root/config" "$root/runtime/contracts" "$root/secrets" "$root/secrets/infra"
chmod 755 "$root/config" "$root/runtime/contracts"
chmod 700 "$root/secrets" "$root/secrets/infra"

ensure_platform_config "$RELEASE_DIR" "$root"
ensure_module_config "$RELEASE_DIR" "$root" infra
source "$RELEASE_DIR/infra/scripts/load-settings.sh"

bash "$RELEASE_DIR/infra/network/provision.sh"
SERVER_EDGE_ROOT="$root" bash "$RELEASE_DIR/infra/network/overlay/install.sh"
bash "$RELEASE_DIR/infra/host/detect.sh" > "$root/runtime/host.env"
chown root:root "$root/runtime/host.env"
chmod 600 "$root/runtime/host.env"
log "infra installed: overlay=$SERVER_EDGE_INFRA_OVERLAY"
