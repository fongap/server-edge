#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/common.sh"

need_cmd bash
need_cmd jq
need_cmd docker

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

[[ -s "$ROOT_DIR/infra/host/README.md" ]] || die "missing or empty: infra/host/README.md"

bash -n "$HERE"/*.sh "$HERE"/lib/*.sh "$ROOT_DIR/infra/network/provision.sh"
log "validation passed"
