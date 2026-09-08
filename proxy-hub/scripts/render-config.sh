#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
provider_dir="$root/secrets/proxy-hub/providers"
secret_file="$root/secrets/proxy-hub/controller-secret"
runtime_dir="$root/runtime/proxy-hub"
output="$runtime_dir/config.yaml"

SERVER_EDGE_ROOT="$root" bash "$HERE/validate-inputs.sh"
[[ -s "$secret_file" ]] || die "missing controller secret: $secret_file"

mapfile -t providers < <(find "$provider_dir" -maxdepth 1 -type f -name '*.url' -printf '%f\n' | LC_ALL=C sort)
controller_secret="$(tr -d '\r\n' < "$secret_file")"
[[ "$controller_secret" =~ ^[A-Fa-f0-9]{48}$ ]] || die "controller secret must be 48 hexadecimal characters"

mkdir -p "$runtime_dir"
tmp="$(mktemp "$runtime_dir/config.yaml.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<'YAML'
mixed-port: 7890
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
    path: './providers/$name.yaml'
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
      - AUTO
      - FALLBACK
      - DIRECT
rules:
  - MATCH,PROXY
YAML

chown root:root "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$output"
trap - EXIT
log "proxy config rendered: ${#providers[@]} provider(s)"
