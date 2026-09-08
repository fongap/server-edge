#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root=/opt/server-edge
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root=$2; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ "$(uname -s)" == Linux ]] || die "Server Edge requires Linux"
[[ $EUID -eq 0 ]] || die "installation requires root; run with sudo"
mkdir -p "$root/runtime" "$root/releases"

if ! command -v jq >/dev/null 2>&1; then
  host_file="$(mktemp)"
  trap 'rm -f "$host_file"' EXIT
  bash "$HERE/detect.sh" > "$host_file"
  source "$host_file"
  if [[ "$SERVER_EDGE_HOST_PACKAGE_MANAGER" == apt-get ]]; then
    bash "$HERE/adapters/package/apt.sh"
  else
    die "jq is missing and no supported package adapter is available; install jq and retry"
  fi
fi

bash "$HERE/validate.sh"
bash "$RELEASE_DIR/infra/runtime/container/install.sh"
bash "$HERE/detect.sh" > "$root/runtime/host.env"
chmod 600 "$root/runtime/host.env"
log "host bootstrap completed"
