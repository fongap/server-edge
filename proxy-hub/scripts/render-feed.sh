#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
source "$HERE/load-settings.sh"
runtime_env="$root/runtime/proxy-hub/compose.env"
provider_dir="$root/secrets/proxy-hub/providers"
[[ -s "$runtime_env" ]] || die "missing proxy runtime env: $runtime_env"
# shellcheck disable=SC1090
source "$runtime_env"

mapfile -t providers < <(find "$provider_dir" -maxdepth 1 -type f -name '*.url' -printf '%f\n' | LC_ALL=C sort)
feed_dir="$root/state/proxy-hub/feed/$SERVER_EDGE_PROXY_FEED_TOKEN"
output="$feed_dir/mihomo.yaml"
mkdir -p "$feed_dir/providers"
chown -R root:root "$root/state/proxy-hub/feed"
chmod 700 "$root/state/proxy-hub/feed" "$feed_dir"
chmod 755 "$feed_dir/providers"

tmp="$(mktemp "$feed_dir/mihomo.yaml.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<'YAML'
mode: rule
log-level: warning
ipv6: true
YAML

has_local=false
if [[ "$SERVER_EDGE_PROXY_EGRESS" == local || "$SERVER_EDGE_PROXY_EGRESS" == hybrid ]]; then
  has_local=true
  cat >> "$tmp" <<YAML
proxies:
  - name: LOCAL
    type: socks5
    server: '$SERVER_EDGE_PROXY_NODE_HOST'
    port: 7891
    udp: true
YAML
fi

if [[ ${#providers[@]} -gt 0 ]]; then
  cat >> "$tmp" <<'YAML'
proxy-providers:
YAML
  for filename in "${providers[@]}"; do
    name="${filename%.url}"
    cat >> "$tmp" <<YAML
  '$name':
    type: http
    url: '$SERVER_EDGE_PROXY_SUBSCRIPTION_BASE_URL/$SERVER_EDGE_PROXY_FEED_TOKEN/providers/$name.yaml'
    path: './providers/$name.yaml'
    interval: 21600
    health-check:
      enable: true
      url: 'https://cp.cloudflare.com'
      interval: 600
      timeout: 5000
      lazy: true
YAML
  done
fi

if [[ "$has_local" == true || ${#providers[@]} -gt 0 ]]; then
  cat >> "$tmp" <<'YAML'
proxy-groups:
  - name: PROXY
    type: select
YAML
  if [[ "$has_local" == true ]]; then
    cat >> "$tmp" <<'YAML'
    proxies:
      - LOCAL
YAML
  fi
  if [[ ${#providers[@]} -gt 0 ]]; then
    cat >> "$tmp" <<'YAML'
    use:
YAML
    for filename in "${providers[@]}"; do printf "      - '%s'\n" "${filename%.url}" >> "$tmp"; done
  fi
  cat >> "$tmp" <<'YAML'
rules:
  - MATCH,PROXY
YAML
else
  cat >> "$tmp" <<'YAML'
proxies: []
rules:
  - MATCH,DIRECT
YAML
fi

chown root:root "$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$output"
trap - EXIT
log "subscription feed rendered: local=$has_local providers=${#providers[@]}"
