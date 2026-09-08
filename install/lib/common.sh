#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[server-edge] %s\n' "$*"; }
die() { printf '[server-edge] ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

sanitize_ref() {
  printf '%s' "$1" | tr '/:@ ' '____' | tr -cd '[:alnum:]._+-'
}

atomic_symlink() {
  local target=$1 link=$2 tmp="${link}.next"
  ln -sfn "$target" "$tmp"
  mv -Tf "$tmp" "$link"
}
