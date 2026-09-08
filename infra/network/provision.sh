#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
need_cmd docker
need_cmd jq

manifest="$RELEASE_DIR/manifests/networks.json"
while IFS=$'\t' read -r name driver internal; do
  if docker network inspect "$name" >/dev/null 2>&1; then
    log "network exists: $name"
    continue
  fi

  args=(network create --driver "$driver" --label com.server-edge.managed=true)
  [[ "$internal" == "true" ]] && args+=(--internal)
  args+=("$name")
  docker "${args[@]}" >/dev/null
  log "network created: $name"
done < <(jq -r '.networks[] | [.name, .driver, (.internal|tostring)] | @tsv' "$manifest")
