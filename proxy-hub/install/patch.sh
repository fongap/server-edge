#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
SERVER_EDGE_ROOT="$root" bash "$RELEASE_DIR/proxy-hub/install/install.sh"
