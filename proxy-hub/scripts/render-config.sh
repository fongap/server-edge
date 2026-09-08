#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
export SERVER_EDGE_ROOT="$root"
source "$HERE/load-settings.sh"
provider_dir="$root/secrets/proxy-hub/providers"
controller_secret_file="$root/secrets/proxy-hub/controller-secret"
feed_token_file="$root/secrets/proxy-hub/subscription-token"
runtime_dir="$root/runtime/proxy-hub"
output="$runtime_dir/config.yaml"

bash "$HERE/validate-inputs.sh"
[[ -s "$controller_secret_file" ]] || die "missing controller secret: $controller_secret_file"
[[ -s "$feed_token_file" ]] || die "missing subscription token: $feed_token_file"

mapfile -t providers < <(find "$provider_dir" -maxdepth 1 -type f -name '*.url' -printf '%f\n' | LC_ALL=C sort)
controller_secret="$(tr -d '\r\n' < "$controller_secret_file")"
feed_token="$(tr -d '\r\n' < "$feed_token_file")"
[[ "$controller_secret" =~ ^[A-Fa-f0-9]{48}$ ]] || die "controller secret must be 48 hexadecimal characters"
[[ "$feed_token" =~ ^[A-Fa-f0-9]{48}$ ]] || die "subscription token must be 48 hexadecimal characters"

mkdir -p "$runtime_dir"
tmp="$(mktemp "$runtime_dir/config.yaml.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<YAML
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
ipv6: true
find-process-mode: off
unified-delay: true
tcp-concurrent: true
external-controller: "0.0.0.0:$SERVER_EDGE_PROXY_CONTROLLER_PORT"
secret: '$controller_secret'
profile:
  store-selected: true
  store-fake-ip: false
YAML

if [[ "$SERVER_EDGE_PROXY_EGRESS_ENABLED" == true ]]; then
  printf 'mixed-port: %s\n' "$SERVER_EDGE_PROXY_EGRESS_PORT" >> "$tmp"
fi

if [[ "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED" == true ]]; then
  cat >> "$tmp" <<YAML
proxies:
  - name: LOCAL
    type: direct
    udp: true
listeners:
  - name: local-node
    type: socks
    port: $SERVER_EDGE_PROXY_LOCAL_NODE_PORT
    listen: 0.0.0.0
    udp: true
    proxy: LOCAL
YAML
fi

cat >> "$tmp" <<'YAML'
proxy-providers:
YAML
for filename in "${providers[@]}"; do
  name="${filename%.url}"
  url="$(tr -d '\r\n' < "$provider_dir/$filename")"
  url_escaped="${url//\'/\'\'}"
  cat >> "$tmp" <<YAML
  '$name':
    type: http
    url: '$url_escaped'
    path: './feed/$feed_token/providers/$name.yaml'
    interval: $SERVER_EDGE_PROXY_PROVIDER_INTERVAL
    health-check:
      enable: true
      url: '$SERVER_EDGE_PROXY_HEALTH_URL'
      interval: $SERVER_EDGE_PROXY_HEALTH_INTERVAL
      timeout: $SERVER_EDGE_PROXY_HEALTH_TIMEOUT
      lazy: true
    override:
      additional-prefix: '[$name] '
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
if [[ "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED" == true ]]; then
  printf '      - LOCAL\n' >> "$tmp"
fi
cat >> "$tmp" <<'YAML'
      - AUTO
      - FALLBACK
YAML

if [[ "$SERVER_EDGE_PROXY_EGRESS_ENABLED" == true ]]; then
  case "$SERVER_EDGE_PROXY_EGRESS_POLICY" in
    auto) target=AUTO ;;
    fallback) target=FALLBACK ;;
    select) target=PROXY ;;
  esac
  printf 'rules:\n  - MATCH,%s\n' "$target" >> "$tmp"
else
  cat >> "$tmp" <<'YAML'
rules:
  - MATCH,DIRECT
YAML
fi

chown root:root "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$output"
trap - EXIT
log "proxy config rendered: aggregation=required providers=${#providers[@]} local-node=$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED egress=$SERVER_EDGE_PROXY_EGRESS_ENABLED/$SERVER_EDGE_PROXY_EGRESS_POLICY"
