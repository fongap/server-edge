#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
env_file="$root/runtime/proxy-hub/compose.env"
contract_dir="$root/runtime/contracts"
contract_file="$contract_dir/proxy-subscription.json"
[[ -s "$env_file" ]] || die "missing proxy runtime env: $env_file"
# shellcheck disable=SC1090
source "$env_file"

public_origin=null
if [[ "$SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN" == https://* ]]; then
  public_origin="$SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN"
fi

mkdir -p "$contract_dir"
if [[ "$public_origin" == null ]]; then
  jq -n \
    --arg producer proxy-hub \
    --arg network edge_service_proxy_public \
    --arg upstream 'http://proxy-feed:8080' \
    '{schema_version:1,producer:$producer,service:"subscription-feed",network:$network,upstream:$upstream,public_origin:null}' \
    > "$contract_file"
else
  jq -n \
    --arg producer proxy-hub \
    --arg network edge_service_proxy_public \
    --arg upstream 'http://proxy-feed:8080' \
    --arg public_origin "$public_origin" \
    '{schema_version:1,producer:$producer,service:"subscription-feed",network:$network,upstream:$upstream,public_origin:$public_origin}' \
    > "$contract_file"
fi
chown root:root "$contract_file"
chmod 644 "$contract_file"
log "proxy subscription ingress contract written"
