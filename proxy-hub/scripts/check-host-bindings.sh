#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
env_file="$root/runtime/proxy-hub/compose.env"
[[ -s "$env_file" ]] || die "missing proxy runtime env: $env_file"
# shellcheck disable=SC1090
source "$env_file"

need_cmd docker
need_cmd jq
need_cmd ss

project="server-edge-proxy-hub"

owned_by_project() {
  local ip="$1" port="$2"
  local id
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if docker inspect "$id" | jq -e \
      --arg ip "$ip" \
      --arg port "$port" \
      '.[0].NetworkSettings.Ports // {} | to_entries | any((.value // [])[]?; .HostIp == $ip and .HostPort == $port)' \
      >/dev/null 2>&1; then
      return 0
    fi
  done < <(docker ps --filter "label=com.docker.compose.project=$project" -q)
  return 1
}

binding_in_use() {
  local proto="$1" ip="$2" port="$3"
  local flags output escaped_ip
  case "$proto" in
    tcp) flags='-ltnp' ;;
    udp) flags='-lunp' ;;
    *) die "unsupported binding protocol: $proto" ;;
  esac
  output="$(ss -H $flags "sport = :$port" 2>/dev/null || true)"
  [[ -n "$output" ]] || return 1
  escaped_ip="${ip//./\\.}"
  grep -Eq "[[:space:]](${escaped_ip}|0\\.0\\.0\\.0|\\*):${port}[[:space:]]" <<<"$output"
}

check_binding() {
  local label="$1" proto="$2" ip="$3" port="$4"
  if ! binding_in_use "$proto" "$ip" "$port"; then
    return 0
  fi
  if owned_by_project "$ip" "$port"; then
    log "host binding already owned by current Proxy Hub: $label $proto://$ip:$port"
    return 0
  fi

  local details
  if [[ "$proto" == tcp ]]; then
    details="$(ss -H -ltnp "sport = :$port" 2>/dev/null || true)"
  else
    details="$(ss -H -lunp "sport = :$port" 2>/dev/null || true)"
  fi
  printf '%s\n' "$details" >&2
  die "host binding conflict: $label requires $proto://$ip:$port; change the corresponding /opt/server-edge/config/proxy-hub.env port or remove the conflicting legacy service"
}

check_binding controller tcp "$SERVER_EDGE_PROXY_CONTROLLER_BIND_IP" "$SERVER_EDGE_PROXY_CONTROLLER_PORT"
check_binding feed tcp "$SERVER_EDGE_PROXY_FEED_BIND_IP" "$SERVER_EDGE_PROXY_FEED_PORT"

if [[ "$SERVER_EDGE_PROXY_LOCAL_NODE_ENABLED" == true ]]; then
  check_binding local-node tcp "$SERVER_EDGE_PROXY_NODE_BIND_IP" "$SERVER_EDGE_PROXY_LOCAL_NODE_PORT"
  check_binding local-node udp "$SERVER_EDGE_PROXY_NODE_BIND_IP" "$SERVER_EDGE_PROXY_LOCAL_NODE_PORT"
fi

if [[ "$SERVER_EDGE_PROXY_EGRESS_ENABLED" == true ]]; then
  check_binding egress tcp "$SERVER_EDGE_PROXY_EGRESS_BIND_IP" "$SERVER_EDGE_PROXY_EGRESS_PORT"
  check_binding egress udp "$SERVER_EDGE_PROXY_EGRESS_BIND_IP" "$SERVER_EDGE_PROXY_EGRESS_PORT"
fi

log "proxy host binding preflight passed"
