#!/usr/bin/env bash
set -Eeuo pipefail

profile_enabled() {
  local profile=$1 module=$2
  jq -e --arg name "$module" '.modules[$name] == true' "$profile" >/dev/null
}

run_module_hook() {
  local release_dir=$1 module=$2 hook=$3 root=$4
  local path="$release_dir/$module/install/$hook"
  [[ -f "$path" ]] || return 0
  log "${module}: ${hook}"
  SERVER_EDGE_ROOT="$root" \
  SERVER_EDGE_RELEASE_DIR="$release_dir" \
  SERVER_EDGE_STATE_DIR="$root/state/$module" \
  SERVER_EDGE_SECRETS_DIR="$root/secrets/$module" \
    bash "$path"
}
