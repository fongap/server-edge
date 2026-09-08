#!/usr/bin/env bash

proxy_compose_files() {
  local release_dir="$1"
  local egress="$2"
  PROXY_COMPOSE_ARGS=(-f "$release_dir/proxy-hub/compose.yaml")

  if [[ "$egress" != off ]]; then
    PROXY_COMPOSE_ARGS+=(-f "$release_dir/proxy-hub/compose.egress.yaml")
  fi

  if [[ "$egress" == local || "$egress" == hybrid ]]; then
    PROXY_COMPOSE_ARGS+=(-f "$release_dir/proxy-hub/compose.local-node.yaml")
  fi
}
