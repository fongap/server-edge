#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../../../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

[[ $EUID -eq 0 ]] || die "apt adapter requires root"
need_cmd apt-get

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl jq gnupg tar
