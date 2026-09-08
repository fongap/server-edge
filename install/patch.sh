#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_RELEASE="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/repository.sh"
source "$HERE/lib/modules.sh"

root=/opt/server-edge
target_ref=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root=$2; shift 2 ;;
    --ref) target_ref=$2; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -n "$target_ref" ]] || die "--ref is required"
[[ -f "$root/runtime/install.env" ]] || die "missing runtime/install.env"
# shellcheck disable=SC1090
source "$root/runtime/install.env"
repo="${SERVER_EDGE_REPOSITORY:-}"
[[ -n "$repo" ]] || die "repository metadata missing"

current_version="$(cat "$CURRENT_RELEASE/VERSION")"
target_release="$(fetch_release "$repo" "$target_ref" "$root")"
target_version="$(cat "$target_release/VERSION")"

"$target_release/install/validate.sh"
patch_manifest="$target_release/patches/index.json"
entry="$(jq -c --arg from "$current_version" --arg to "$target_version" \
  '.patches[]? | select(.from == $from and .to == $to)' "$patch_manifest" | head -n1)"
[[ -n "$entry" ]] || die "no declared patch path: ${current_version} -> ${target_version}"

mapfile -t modules < <(jq -r '.modules[]' <<<"$entry")
backup_required="$(jq -r '.backup_required // false' <<<"$entry")"

for module in "${modules[@]}"; do
  if [[ "$backup_required" == "true" ]]; then
    run_module_hook "$target_release" "$module" backup.sh "$root"
  fi
  run_module_hook "$target_release" "$module" validate.sh "$root"
  run_module_hook "$target_release" "$module" patch.sh "$root"
done

for module in "${modules[@]}"; do
  run_module_hook "$target_release" "$module" healthcheck.sh "$root"
done

atomic_symlink "$target_release" "$root/current"
release_id="$(basename "$target_release")"
cat > "$root/runtime/install.env" <<META
SERVER_EDGE_REPOSITORY=$repo
SERVER_EDGE_REF=$target_ref
SERVER_EDGE_RELEASE_ID=$release_id
META
chmod 600 "$root/runtime/install.env"
log "patched ${current_version} -> ${target_version}"
