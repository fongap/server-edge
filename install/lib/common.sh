#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[server-edge] %s\n' "$*"; }
die() { printf '[server-edge] ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

sanitize_ref() {
  printf '%s' "$1" | tr '/:@ ' '____' | tr -cd '[:alnum:]._+-'
}

ensure_release_script_modes() {
  local release_dir=$1
  [[ -d "$release_dir" ]] || die "release directory not found: $release_dir"
  find "$release_dir" -type f -name '*.sh' -exec chmod 0755 {} +
}

atomic_symlink() {
  local target=$1 link=$2 tmp="${link}.next"
  ln -sfn "$target" "$tmp"
  mv -Tf "$tmp" "$link"
}
