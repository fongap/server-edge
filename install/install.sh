#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/modules.sh"

root=/opt/server-edge
profile_rel=profiles/default.json
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root=$2; shift 2 ;;
    --profile) profile_rel=$2; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

profile="$RELEASE_DIR/$profile_rel"
[[ -f "$profile" ]] || die "profile not found: $profile_rel"
profile_enabled "$profile" infra || die "infra must be enabled"

mkdir -p "$root"/{state,secrets,runtime,backups,shared/assets,releases}
chmod 700 "$root/secrets"

"$HERE/validate.sh"
"$RELEASE_DIR/infra/network/provision.sh"

mapfile -t modules < <(jq -r '.modules[].name' "$RELEASE_DIR/manifests/modules.json")
for module in "${modules[@]}"; do
  profile_enabled "$profile" "$module" || { log "$module: disabled"; continue; }
  mkdir -p "$root/state/$module" "$root/secrets/$module"
  chmod 700 "$root/secrets/$module"
  run_module_hook "$RELEASE_DIR" "$module" validate.sh "$root"
  run_module_hook "$RELEASE_DIR" "$module" install.sh "$root"
done

log "module installation completed"
