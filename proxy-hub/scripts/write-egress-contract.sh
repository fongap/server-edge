#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
env_file="$root/runtime/proxy-hub/compose.env"
contract_dir="$root/runtime/contracts"
contract_file="$contract_dir/proxy-egress.json"
[[ -s "$env_file" ]] || die "missing proxy runtime env: $env_file"
# shellcheck disable=SC1090
source "$env_file"

mkdir -p "$contract_dir"
if [[ "$SERVER_EDGE_PROXY_EGRESS_ENABLED" == true ]]; then
  jq -n \
    --arg endpoint "http://proxy-hub:$SERVER_EDGE_PROXY_EGRESS_PORT" \
    --arg policy "$SERVER_EDGE_PROXY_EGRESS_POLICY" \
    '{schema_version:1,producer:"proxy-hub",service:"egress",enabled:true,protocol:"mixed-http-socks5",endpoint:$endpoint,policy:$policy}' \
    > "$contract_file"
else
  jq -n \
    '{schema_version:1,producer:"proxy-hub",service:"egress",enabled:false,protocol:"mixed-http-socks5",endpoint:null,policy:null}' \
    > "$contract_file"
fi
chown root:root "$contract_file"
chmod 644 "$contract_file"
log "proxy egress contract written: enabled=$SERVER_EDGE_PROXY_EGRESS_ENABLED"
