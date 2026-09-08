#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
SERVER_EDGE_ROOT="$root" bash "$RELEASE_DIR/public-edge/install/install.sh"
