#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"
source "$RELEASE_DIR/install/lib/config.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
contract="$root/runtime/contracts/proxy-subscription.json"

SERVER_EDGE_PUBLIC_ACTIVE=false
SERVER_EDGE_PUBLIC_ORIGIN=""
SERVER_EDGE_PUBLIC_HOST=""

ensure_platform_config "$RELEASE_DIR" "$root"

if [[ -s "$contract" ]]; then
  jq -e '.schema_version == 1 and .producer == "proxy-hub" and .service == "subscription-feed" and .publication_key == "proxy-subscription" and .network == "edge_service_proxy_public" and .upstream == "http://proxy-feed:8080"' "$contract" >/dev/null \
    || die "invalid runtime proxy subscription contract"
  publication_key="$(jq -r '.publication_key' "$contract")"
  origin="$(resolve_publication_origin "$root" "$publication_key")"
  if [[ -n "$origin" ]]; then
    [[ "$origin" =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] \
      || die "publication $publication_key origin must be a canonical HTTPS origin"
    SERVER_EDGE_PUBLIC_ACTIVE=true
    SERVER_EDGE_PUBLIC_ORIGIN="$origin"
    SERVER_EDGE_PUBLIC_HOST="${origin#https://}"
  fi
fi

export SERVER_EDGE_PUBLIC_ACTIVE SERVER_EDGE_PUBLIC_ORIGIN SERVER_EDGE_PUBLIC_HOST
