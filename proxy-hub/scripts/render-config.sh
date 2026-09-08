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

cat > "$tmp" <<'YAML'
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
ipv6: true
find-process-mode: off
unified-delay: true
tcp-concurrent: true
external-controller: "0.0.0.0:9090"
YAML
printf "secret: '%s'\n" "$controller_secret" >> "$tmp"
cat >> "$tmp" <<'YAML'
profile:
  store-selected: true
  store-fake-ip: false
YAML

if [[ "$SERVER_EDGE_PROXY_EGRESS" != off ]]; then
  printf 'mixed-port: 7890\n' >> "$tmp"
fi

if [[ "$SERVER_EDGE_PROXY_EGRESS" == local || "$SERVER_EDGE_PROXY_EGRESS" == hybrid ]]; then
  cat >> "$tmp" <<'YAML'
proxies:
  - name: LOCAL
    type: direct
    udp: true
listeners:
  - name: local-node
    type: socks
    port: 7891
    listen: 0.0.0.0
    udp: true
    proxy: LOCAL
YAML
fi

if [[ ${#providers[@]} -gt 0 ]]; then
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
    interval: 21600
    health-check:
      enable: true
      url: 'https://cp.cloudflare.com'
      interval: 600
      timeout: 5000
      lazy: true
    override:
      additional-prefix: '[$name] '
YAML
  done
fi

write_provider_use() {
  local filename
  for filename in "${providers[@]}"; do
    printf "      - '%s'\n" "${filename%.url}" >> "$tmp"
  done
}

case "$SERVER_EDGE_PROXY_EGRESS" in
  off)
    if [[ ${#providers[@]} -gt 0 ]]; then
      cat >> "$tmp" <<'YAML'
proxy-groups:
  - name: PROVIDER-CACHE
    type: select
    hidden: true
    use:
YAML
      write_provider_use
    fi
    cat >> "$tmp" <<'YAML'
rules:
  - MATCH,DIRECT
YAML
    ;;
  local)
    cat >> "$tmp" <<'YAML'
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - LOCAL
YAML
    if [[ ${#providers[@]} -gt 0 ]]; then
      cat >> "$tmp" <<'YAML'
  - name: PROVIDER-CACHE
    type: select
    hidden: true
    use:
YAML
      write_provider_use
    fi
    cat >> "$tmp" <<'YAML'
rules:
  - MATCH,PROXY
YAML
    ;;
  provider|hybrid)
    cat >> "$tmp" <<'YAML'
proxy-groups:
  - name: AUTO
    type: url-test
    use:
YAML
    write_provider_use
    cat >> "$tmp" <<'YAML'
    url: 'https://cp.cloudflare.com'
    interval: 300
    tolerance: 100
    lazy: true
  - name: FALLBACK
    type: fallback
    use:
YAML
    write_provider_use
    cat >> "$tmp" <<'YAML'
    url: 'https://cp.cloudflare.com'
    interval: 300
    lazy: true
  - name: PROXY
    type: select
    proxies:
YAML
    if [[ "$SERVER_EDGE_PROXY_EGRESS" == hybrid ]]; then
      printf '      - LOCAL\n' >> "$tmp"
    fi
    cat >> "$tmp" <<'YAML'
      - AUTO
      - FALLBACK
rules:
  - MATCH,PROXY
YAML
    ;;
esac

chown root:root "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$output"
trap - EXIT
log "proxy config rendered: egress=$SERVER_EDGE_PROXY_EGRESS providers=${#providers[@]}"
