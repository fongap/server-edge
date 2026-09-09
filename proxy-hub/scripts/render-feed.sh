#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
runtime_env="$root/runtime/proxy-hub/compose.env"
provider_dir="$root/secrets/proxy-hub/providers"
[[ -s "$runtime_env" ]] || die "missing proxy runtime env: $runtime_env"
# shellcheck disable=SC1090
source "$runtime_env"

mapfile -t providers < <(find "$provider_dir" -maxdepth 1 -type f -name '*.url' -printf '%f\n' | LC_ALL=C sort)
[[ ${#providers[@]} -gt 0 ]] || die "subscription feed requires at least one provider"
feed_root="$root/state/proxy-hub/feed"
feed_dir="$feed_root/$SERVER_EDGE_PROXY_FEED_TOKEN"
output="$feed_dir/mihomo.yaml"
mkdir -p "$feed_dir/providers"
chown -R root:root "$feed_root"
chmod 700 "$feed_root" "$feed_dir"
chmod 755 "$feed_dir/providers"

while IFS= read -r entry; do
  [[ "$entry" =~ ^[A-Fa-f0-9]{48}$ ]] || continue
  [[ "$entry" == "$SERVER_EDGE_PROXY_FEED_TOKEN" ]] && continue
  rm -rf -- "$feed_root/$entry"
  log "revoked stale subscription feed token"
done < <(find "$feed_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)

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

if [[ "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED" == true && "$SERVER_EDGE_PROXY_LOCAL_NODE_PUBLISH" == true ]]; then
  cat >> "$tmp" <<YAML
proxies:
  - name: LOCAL
    type: socks5
    server: '$SERVER_EDGE_PROXY_NODE_HOST'
    port: $SERVER_EDGE_PROXY_LOCAL_NODE_PORT
    udp: true
YAML
fi

cat >> "$tmp" <<'YAML'
proxy-providers:
YAML
for filename in "${providers[@]}"; do
  name="${filename%.url}"
  cat >> "$tmp" <<YAML
  '$name':
    type: http
    url: '$SERVER_EDGE_PROXY_SUBSCRIPTION_ORIGIN/$SERVER_EDGE_PROXY_FEED_TOKEN/providers/$name.yaml'
    path: './providers/$name.yaml'
    interval: $SERVER_EDGE_PROXY_PROVIDER_INTERVAL
    health-check:
      enable: true
      url: '$SERVER_EDGE_PROXY_HEALTH_URL'
      interval: $SERVER_EDGE_PROXY_HEALTH_INTERVAL
      timeout: $SERVER_EDGE_PROXY_HEALTH_TIMEOUT
      lazy: true
YAML
done

write_provider_use() {
  local filename
  for filename in "${providers[@]}"; do
    printf "      - '%s'\n" "${filename%.url}" >> "$tmp"
  done
}

cat >> "$tmp" <<'YAML'
proxy-groups:
  - name: AUTO
    type: url-test
    use:
YAML
write_provider_use
cat >> "$tmp" <<YAML
    url: '$SERVER_EDGE_PROXY_HEALTH_URL'
    interval: $SERVER_EDGE_PROXY_PROBE_INTERVAL
    tolerance: $SERVER_EDGE_PROXY_AUTO_TOLERANCE
    lazy: true
  - name: FALLBACK
    type: fallback
    use:
YAML
write_provider_use
cat >> "$tmp" <<YAML
    url: '$SERVER_EDGE_PROXY_HEALTH_URL'
    interval: $SERVER_EDGE_PROXY_PROBE_INTERVAL
    lazy: true
  - name: PROXY
    type: select
    proxies:
YAML
if [[ "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED" == true && "$SERVER_EDGE_PROXY_LOCAL_NODE_PUBLISH" == true ]]; then
  printf '      - LOCAL\n' >> "$tmp"
fi
cat >> "$tmp" <<'YAML'
      - AUTO
      - FALLBACK
rules:
  - MATCH,PROXY
YAML

chown root:root "$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$output"
trap - EXIT
log "subscription feed rendered: aggregation=required providers=${#providers[@]} local-published=$SERVER_EDGE_PROXY_LOCAL_NODE_PUBLISH"
