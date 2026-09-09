#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
runtime_dir="$root/runtime/proxy-hub"
env_file="$runtime_dir/compose.env"
output="$runtime_dir/compose.yaml"
[[ -s "$env_file" ]] || die "missing proxy runtime env: $env_file"
# shellcheck disable=SC1090
source "$env_file"
need_cmd jq

q() { jq -Rn --arg value "$1" '$value'; }

image="$(q "$SERVER_EDGE_PROXY_IMAGE")"
feed_image="$(q "$SERVER_EDGE_PROXY_FEED_IMAGE")"
config_path="$(q "$SERVER_EDGE_PROXY_CONFIG")"
state_path="$(q "$SERVER_EDGE_PROXY_STATE")"
feed_root="$(q "$SERVER_EDGE_PROXY_FEED_ROOT")"
controller_ip="$(q "$SERVER_EDGE_PROXY_CONTROLLER_BIND_IP")"
feed_ip="$(q "$SERVER_EDGE_PROXY_FEED_BIND_IP")"
node_ip="$(q "$SERVER_EDGE_PROXY_NODE_BIND_IP")"
egress_ip="$(q "$SERVER_EDGE_PROXY_EGRESS_BIND_IP")"

tmp="$(mktemp "$runtime_dir/compose.yaml.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<EOF
name: server-edge-proxy-hub

services:
  proxy:
    image: $image
    restart: unless-stopped
    command: ["-d", "/var/lib/mihomo", "-f", "/etc/mihomo/config.yaml"]
    volumes:
      - type: bind
        source: $config_path
        target: /etc/mihomo/config.yaml
        read_only: true
      - type: bind
        source: $state_path
        target: /var/lib/mihomo
    ports:
      - target: $SERVER_EDGE_PROXY_CONTROLLER_PORT
        published: "$SERVER_EDGE_PROXY_CONTROLLER_PORT"
        host_ip: $controller_ip
        protocol: tcp
EOF

if [[ "$SERVER_EDGE_PROXY_EGRESS_ENABLED" == true ]]; then
  cat >> "$tmp" <<EOF
      - target: $SERVER_EDGE_PROXY_EGRESS_PORT
        published: "$SERVER_EDGE_PROXY_EGRESS_PORT"
        host_ip: $egress_ip
        protocol: tcp
      - target: $SERVER_EDGE_PROXY_EGRESS_PORT
        published: "$SERVER_EDGE_PROXY_EGRESS_PORT"
        host_ip: $egress_ip
        protocol: udp
EOF
fi

if [[ "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED" == true ]]; then
  cat >> "$tmp" <<EOF
      - target: $SERVER_EDGE_PROXY_LOCAL_NODE_PORT
        published: "$SERVER_EDGE_PROXY_LOCAL_NODE_PORT"
        host_ip: $node_ip
        protocol: tcp
      - target: $SERVER_EDGE_PROXY_LOCAL_NODE_PORT
        published: "$SERVER_EDGE_PROXY_LOCAL_NODE_PORT"
        host_ip: $node_ip
        protocol: udp
EOF
fi

cat >> "$tmp" <<EOF
    networks:
      edge_egress_ai:
        aliases: [proxy-hub]
      edge_egress_workers:
        aliases: [proxy-hub]
      outbound: {}
    cap_drop: [ALL]
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:size=16m,mode=1777
    pids_limit: 256
    mem_limit: 512m
    cpus: 1.0
    stop_grace_period: 20s

  feed:
    image: $feed_image
    restart: unless-stopped
    command: ["httpd", "-f", "-p", "8080", "-h", "/www"]
    volumes:
      - type: bind
        source: $feed_root
        target: /www
        read_only: true
    ports:
      - target: 8080
        published: "$SERVER_EDGE_PROXY_FEED_PORT"
        host_ip: $feed_ip
        protocol: tcp
    networks:
      edge_service_proxy_public:
        aliases: [proxy-feed]
    cap_drop: [ALL]
    security_opt:
      - no-new-privileges:true
    read_only: true
    pids_limit: 64
    mem_limit: 64m
    cpus: 0.25

networks:
  edge_egress_ai:
    external: true
  edge_egress_workers:
    external: true
  edge_service_proxy_public:
    external: true
  outbound:
    driver: bridge
EOF

chown root:root "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$output"
trap - EXIT
log "proxy runtime compose rendered: local-node=$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED egress=$SERVER_EDGE_PROXY_EGRESS_ENABLED"
