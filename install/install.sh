#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/.." && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/config.sh"

root=/opt/server-edge
profile_rel=profiles/default.json
instance_source=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root=$2; shift 2 ;;
    --profile) profile_rel=$2; shift 2 ;;
    --instance-source) instance_source=$2; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

mkdir -p "$root/runtime" "$root/releases"
bash "$RELEASE_DIR/infra/host/bootstrap.sh" --root "$root"

source "$HERE/lib/modules.sh"
profile="$RELEASE_DIR/$profile_rel"
[[ -f "$profile" ]] || die "profile not found: $profile_rel"
profile_enabled "$profile" infra || die "infra must be enabled"

mkdir -p "$root"/{config,state,secrets,runtime,backups,shared/assets,releases}
chmod 700 "$root/secrets"

if [[ -n "$instance_source" ]]; then
  bash "$HERE/configure.sh" --root "$root" --source "$instance_source"
fi

ensure_platform_config "$RELEASE_DIR" "$root"
bash "$HERE/validate.sh"

mapfile -t modules < <(jq -r '.modules[].name' "$RELEASE_DIR/manifests/modules.json")
for module in "${modules[@]}"; do
  profile_enabled "$profile" "$module" || { log "$module: disabled"; continue; }
  mkdir -p "$root/state/$module" "$root/secrets/$module"
  chmod 700 "$root/secrets/$module"
  ensure_module_config "$RELEASE_DIR" "$root" "$module"
  run_module_hook "$RELEASE_DIR" "$module" validate.sh "$root"
  run_module_hook "$RELEASE_DIR" "$module" install.sh "$root"
  run_module_hook "$RELEASE_DIR" "$module" healthcheck.sh "$root"
done

log "module installation completed"
