#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"
root=/opt/server-edge
target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root=$2; shift 2 ;;
    --to) target=$2; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -n "$target" ]] || die "--to is required"
target_dir="$root/releases/$target"
[[ -d "$target_dir" ]] || die "release not found: $target"
"$target_dir/install/validate.sh"
atomic_symlink "$target_dir" "$root/current"
log "current -> $target"
