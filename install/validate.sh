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
jq -e '.schema_version == 1 and (.server_edge | type == "string") and (.components.mihomo.version | type == "string") and (.components.mihomo.image | type == "string") and (.components.busybox.version | type == "string") and (.components.busybox.image | type == "string")' \
  "$ROOT_DIR/manifests/versions.json" >/dev/null \
  || die "invalid manifests/versions.json"
jq -e '.schema_version == 1 and .contract == "proxy-subscription" and .producer == "proxy-hub" and .consumer == "public-edge" and .network == "edge_service_proxy_public" and .upstream == "http://proxy-feed:8080" and .public_origin.optional == true and .public_origin.scheme == "https" and .secret_fields == []' \
  "$ROOT_DIR/manifests/contracts/proxy-subscription.json" >/dev/null \
  || die "invalid proxy subscription contract"

repo_version="$(tr -d '\r\n' < "$ROOT_DIR/VERSION")"
manifest_version="$(jq -r '.server_edge' "$ROOT_DIR/manifests/versions.json")"
[[ "$repo_version" == "$manifest_version" ]] || die "VERSION and manifests/versions.json differ: $repo_version != $manifest_version"

expected='["infra","app-hub","proxy-hub","ai-gateway","ai-workers","public-edge"]'
actual="$(jq -c '[.modules[].name]' "$ROOT_DIR/manifests/modules.json")"
[[ "$actual" == "$expected" ]] || die "top-level module contract changed: $actual"

for module in infra app-hub proxy-hub ai-gateway ai-workers public-edge; do
  [[ -d "$ROOT_DIR/$module" ]] || die "missing module directory: $module"
done

for file in \
  docs/ARCHITECTURE.md \
  docs/GOVERNANCE.md \
  docs/HOST-CONTRACT.md \
  manifests/contracts/proxy-subscription.json \
  proxy-hub/compose.yaml \
  proxy-hub/compose.egress.yaml \
  proxy-hub/compose.local-node.yaml \
  VERSION; do
  [[ -s "$ROOT_DIR/$file" ]] || die "missing or empty: $file"
done

scripts=()
while IFS= read -r -d '' script; do scripts+=("$script"); done < <(find "$ROOT_DIR" -type f -name '*.sh' -not -path '*/.git/*' -print0 | sort -z)
[[ ${#scripts[@]} -gt 0 ]] || die "no shell scripts found"
bash -n "${scripts[@]}"
log "validation passed ($mode)"
