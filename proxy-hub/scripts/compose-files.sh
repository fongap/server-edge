#!/usr/bin/env bash

proxy_compose_files() {
  local release_dir="$1"
  local egress_enabled="$2"
  local local_node_enabled="$3"
  PROXY_COMPOSE_ARGS=(-f "$release_dir/proxy-hub/compose.yaml")

  if [[ "$egress_enabled" == true ]]; then
    PROXY_COMPOSE_ARGS+=(-f "$release_dir/proxy-hub/compose.egress.yaml")
  fi

  if [[ "$local_node_enabled" == true ]]; then
    PROXY_COMPOSE_ARGS+=(-f "$release_dir/proxy-hub/compose.local-node.yaml")
  fi
}
