#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

bash "$RELEASE_DIR/infra/host/validate.sh"
need_cmd docker
docker info >/dev/null || die "Docker daemon is not available"
docker compose version >/dev/null || die "Docker Compose v2 is not available"
