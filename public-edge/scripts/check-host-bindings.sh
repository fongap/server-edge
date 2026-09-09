#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
env_file="$root/runtime/public-edge/compose.env"
[[ -s "$env_file" ]] || die "missing public-edge runtime env: $env_file"
# shellcheck disable=SC1090
source "$env_file"

need_cmd docker
need_cmd jq
need_cmd ss

project="server-edge-public-edge"

docker_binding_owner() {
  local proto="$1" ip="$2" port="$3"
  local id inspect name owner_project
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    inspect="$(docker inspect "$id")"
    if jq -e \
      --arg proto "$proto" \
      --arg ip "$ip" \
      --arg port "$port" \
      '[.[0].NetworkSettings.Ports // {} | to_entries[] | select(.key | endswith("/" + $proto)) | (.value // [])[]? | select((($ip == "0.0.0.0") or .HostIp == $ip or .HostIp == "0.0.0.0") and .HostPort == $port)] | length > 0' \
      <<<"$inspect" >/dev/null 2>&1; then
      name="$(jq -r '.[0].Name | ltrimstr("/")' <<<"$inspect")"
      owner_project="$(jq -r '.[0].Config.Labels["com.docker.compose.project"] // empty' <<<"$inspect")"
      printf '%s|%s\n' "$owner_project" "$name"
      return 0
    fi
  done < <(docker ps -q)
  return 1
}

socket_binding_in_use() {
  local proto="$1" ip="$2" port="$3"
  local flags output escaped_ip
  case "$proto" in
    tcp) flags='-ltnp' ;;
    udp) flags='-lunp' ;;
    *) die "unsupported binding protocol: $proto" ;;
  esac
  output="$(ss -H $flags "sport = :$port" 2>/dev/null || true)"
  [[ -n "$output" ]] || return 1
  if [[ "$ip" == 0.0.0.0 ]]; then
    return 0
  fi
  escaped_ip="${ip//./\\.}"
  grep -Eq "[[:space:]](${escaped_ip}|0\\.0\\.0\\.0|\\*):${port}[[:space:]]" <<<"$output"
}

show_socket_owner() {
  local proto="$1" port="$2"
  if [[ "$proto" == tcp ]]; then
    ss -H -ltnp "sport = :$port" 2>/dev/null || true
  else
    ss -H -lunp "sport = :$port" 2>/dev/null || true
  fi
}

check_binding() {
  local label="$1" proto="$2" ip="$3" port="$4"
  local docker_owner owner_project owner_name

  docker_owner="$(docker_binding_owner "$proto" "$ip" "$port" || true)"
  if [[ -n "$docker_owner" ]]; then
    owner_project="${docker_owner%%|*}"
    owner_name="${docker_owner#*|}"
    if [[ "$owner_project" == "$project" ]]; then
      log "host binding already owned by current Public Edge: $label $proto://$ip:$port ($owner_name)"
      return 0
    fi
    die "host binding conflict: Public Edge requires $proto://$ip:$port; Docker container $owner_name already publishes a conflicting binding. Stop the legacy public edge or change SERVER_EDGE_PUBLIC_BIND_IP in /opt/server-edge/config/public-edge.env"
  fi

  if socket_binding_in_use "$proto" "$ip" "$port"; then
    show_socket_owner "$proto" "$port" >&2
    die "host binding conflict: Public Edge requires $proto://$ip:$port; a host process already owns a conflicting binding"
  fi
}

check_binding http tcp "$SERVER_EDGE_PUBLIC_BIND_IP" 80
check_binding https tcp "$SERVER_EDGE_PUBLIC_BIND_IP" 443
check_binding https udp "$SERVER_EDGE_PUBLIC_BIND_IP" 443

log "public-edge host binding preflight passed"
