#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/common.sh"

mode=host
while [[ $# -gt 0 ]]; do
  case "$1" in
    --static) mode=static; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

need_cmd bash
need_cmd jq
if [[ "$mode" == host ]]; then
  need_cmd docker
  docker compose version >/dev/null || die "Docker Compose v2 is required"
fi

jq -e '.schema_version == 1 and (.modules | type == "array")' "$ROOT_DIR/manifests/modules.json" >/dev/null \
  || die "invalid manifests/modules.json"
jq -e '.schema_version == 1 and (.networks | type == "array")' "$ROOT_DIR/manifests/networks.json" >/dev/null \
  || die "invalid manifests/networks.json"
jq -e '.schema_version == 1 and .host_contract.os.allowed == ["linux"] and .host_contract.runtime.engine == "docker" and .host_contract.runtime.compose == "v2"' \
  "$ROOT_DIR/manifests/host-contract.json" >/dev/null \
  || die "invalid manifests/host-contract.json"
jq -e '.schema_version == 1' "$ROOT_DIR/profiles/default.json" >/dev/null \
  || die "invalid default profile"

expected='["infra","app-hub","proxy-hub","ai-gateway","ai-workers","public-edge"]'
actual="$(jq -c '[.modules[].name]' "$ROOT_DIR/manifests/modules.json")"
[[ "$actual" == "$expected" ]] || die "top-level module contract changed: $actual"

for module in infra app-hub proxy-hub ai-gateway ai-workers public-edge; do
  [[ -d "$ROOT_DIR/$module" ]] || die "missing module directory: $module"
done

for file in docs/ARCHITECTURE.md docs/GOVERNANCE.md docs/HOST-CONTRACT.md VERSION; do
  [[ -s "$ROOT_DIR/$file" ]] || die "missing or empty: $file"
done

scripts=(
  "$HERE"/*.sh
  "$HERE"/lib/*.sh
  "$ROOT_DIR"/infra/host/*.sh
  "$ROOT_DIR"/infra/host/adapters/package/*.sh
  "$ROOT_DIR"/infra/runtime/container/*.sh
  "$ROOT_DIR"/infra/network/*.sh
  "$ROOT_DIR"/infra/network/overlay/*.sh
  "$ROOT_DIR"/infra/install/*.sh
)
bash -n "${scripts[@]}"
log "validation passed ($mode)"
