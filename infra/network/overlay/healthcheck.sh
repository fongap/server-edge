#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

mode="${SERVER_EDGE_OVERLAY:-auto}"
[[ "$mode" == off ]] && exit 0

if ! command -v tailscale >/dev/null 2>&1 || ! command -v tailscaled >/dev/null 2>&1; then
  [[ "$mode" == required ]] && die "Tailscale is required but not installed"
  log "overlay health: not installed (optional)"
  exit 0
fi

if tailscale status >/dev/null 2>&1; then
  log "overlay health: connected"
  exit 0
fi

[[ "$mode" == required ]] && die "Tailscale is required but not connected"
log "overlay health: installed but not connected"
