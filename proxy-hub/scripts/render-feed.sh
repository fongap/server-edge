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

providers=()
if [[ -d "$provider_dir" ]]; then
  mapfile -t providers < <(find "$provider_dir" -maxdepth 1 -type f -name '*.url' -printf '%f\n' | LC_ALL=C sort)
fi
feed_root="$root/state/proxy-hub/feed"
feed_dir="$feed_root/$SERVER_EDGE_PROXY_FEED_TOKEN"
output="$feed_dir/mihomo.yaml"
mkdir -p "$feed_dir/providers"
chown -R root:root "$feed_root"
chmod 700 "$feed_root" "$feed_dir"
chmod 755 "$feed_dir/providers"
printf '%s\n' 'Not Found' > "$feed_root/index.html"
printf '%s\n' 'Not Found' > "$feed_dir/index.html"
chmod 644 "$feed_root/index.html" "$feed_dir/index.html"

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

  cat >> "$tmp" <<'YAML'
proxy-groups:
  - name: AUTO
    type: url-test
    use:
YAML
  for filename in "${providers[@]}"; do printf "      - '%s'\n" "${filename%.url}" >> "$tmp"; done
  cat >> "$tmp" <<'YAML'
    url: 'https://cp.cloudflare.com'
    interval: 300
    tolerance: 100
    lazy: true
  - name: FALLBACK
    type: fallback
    use:
YAML
  for filename in "${providers[@]}"; do printf "      - '%s'\n" "${filename%.url}" >> "$tmp"; done
  cat >> "$tmp" <<'YAML'
    url: 'https://cp.cloudflare.com'
    interval: 300
    lazy: true
  - name: PROXY
    type: select
    proxies:
YAML
  if [[ "$has_local" == true ]]; then printf '      - LOCAL\n' >> "$tmp"; fi
  cat >> "$tmp" <<'YAML'
      - AUTO
      - FALLBACK
rules:
  - MATCH,PROXY
YAML
elif [[ "$has_local" == true ]]; then
  cat >> "$tmp" <<'YAML'
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - LOCAL
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
