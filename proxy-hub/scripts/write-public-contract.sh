#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
contract_dir="$root/runtime/contracts"
contract_file="$contract_dir/proxy-subscription.json"

mkdir -p "$contract_dir"
jq -n \
  --arg producer proxy-hub \
  --arg service subscription-feed \
  --arg publication_key proxy-subscription \
  --arg network edge_service_proxy_public \
  --arg upstream 'http://proxy-feed:8080' \
  '{schema_version:1,producer:$producer,service:$service,publication_key:$publication_key,network:$network,upstream:$upstream}' \
  > "$contract_file"
chown root:root "$contract_file"
chmod 644 "$contract_file"
log "proxy subscription service contract written"
