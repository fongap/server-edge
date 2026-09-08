#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

host_file="$(mktemp)"
trap 'rm -f "$host_file"' EXIT
bash "$HERE/detect.sh" > "$host_file"
source "$host_file"

[[ "$SERVER_EDGE_HOST_OS" == linux ]] || die "unsupported host OS: $SERVER_EDGE_HOST_OS"
[[ $EUID -eq 0 ]] || die "installation requires root; run with sudo"

case "$SERVER_EDGE_HOST_ARCH" in
  amd64|arm64) ;;
  *)
    if [[ "$SERVER_EDGE_HOST_DOCKER" != true || "$SERVER_EDGE_HOST_COMPOSE" != true ]]; then
      die "architecture $SERVER_EDGE_HOST_ARCH requires a preinstalled compatible Docker Engine + Compose"
    fi
    log "host architecture $SERVER_EDGE_HOST_ARCH accepted as compatible because runtime is already available"
    ;;
esac

if [[ "$SERVER_EDGE_HOST_DOCKER" != true || "$SERVER_EDGE_HOST_COMPOSE" != true ]]; then
  if [[ "$SERVER_EDGE_HOST_PACKAGE_MANAGER" != apt-get ]]; then
    die "Docker runtime is missing and no supported package adapter is available (detected: $SERVER_EDGE_HOST_PACKAGE_MANAGER)"
  fi
  if [[ "$SERVER_EDGE_HOST_SERVICE_MANAGER" != systemd ]]; then
    die "automatic runtime installation currently requires systemd"
  fi
  case "$SERVER_EDGE_HOST_ID" in
    ubuntu|debian) ;;
    *) die "automatic apt runtime installation currently supports Ubuntu and Debian; preinstall Docker + Compose to use this compatible host" ;;
  esac
fi

log "host contract accepted: os=$SERVER_EDGE_HOST_OS arch=$SERVER_EDGE_HOST_ARCH distro=$SERVER_EDGE_HOST_ID package=$SERVER_EDGE_HOST_PACKAGE_MANAGER service=$SERVER_EDGE_HOST_SERVICE_MANAGER"
