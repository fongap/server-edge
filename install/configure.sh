#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"

root=/opt/server-edge
source_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root=$2; shift 2 ;;
    --source) source_dir=$2; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "configure must run as root"
[[ -n "$source_dir" ]] || die "--source is required"
[[ -d "$source_dir" && ! -L "$source_dir" ]] || die "instance source must be a real directory: $source_dir"
need_cmd jq

config_source="$source_dir/config"
secrets_source="$source_dir/secrets"
manifest="$root/runtime/config-source.manifest"

for path in "$root/config" "$root/secrets" "$root/runtime" "$root/backups"; do
  [[ ! -L "$path" ]] || die "managed path must not be a symlink: $path"
done
mkdir -p "$root/config" "$root/secrets" "$root/runtime" "$root/backups/configure"
chown root:root "$root/config" "$root/secrets" "$root/runtime" "$root/backups/configure"
chmod 755 "$root/config"
chmod 700 "$root/secrets" "$root/backups/configure"

existing_link="$(find -P "$root/config" "$root/secrets" -type l -print -quit 2>/dev/null || true)"
[[ -z "$existing_link" ]] || die "managed instance tree must not contain symlinks: $existing_link"

validate_tree() {
  local base=$1 kind=$2 path rel
  [[ ! -e "$base" ]] && return 0
  [[ -d "$base" && ! -L "$base" ]] || die "$kind source must be a real directory: $base"

  while IFS= read -r -d '' path; do
    [[ ! -L "$path" ]] || die "$kind source must not contain symlinks: $path"
    [[ -d "$path" || -f "$path" ]] || die "$kind source contains unsupported file type: $path"
    rel=${path#"$base"/}
    [[ "$rel" =~ ^[A-Za-z0-9._/-]+$ ]] || die "$kind source contains unsafe path: $rel"
    [[ "$rel" != */../* && "$rel" != ../* && "$rel" != */.. ]] || die "$kind source contains parent traversal: $rel"
  done < <(find -P "$base" -mindepth 1 -print0)
}

validate_tree "$config_source" config
validate_tree "$secrets_source" secret

if [[ -d "$config_source" ]]; then
  while IFS= read -r -d '' path; do
    rel=${path#"$config_source"/}
    [[ "$rel" != */* ]] || die "instance config must be flat: $rel"
    case "$rel" in
      *.env) bash -n "$path" || die "invalid shell syntax in instance config: $rel" ;;
      publications.json)
        jq -e '.schema_version == 1 and (.services | type == "object") and all(.services[]; type == "object")' "$path" >/dev/null \
          || die "invalid publications config: $rel"
        while IFS= read -r origin; do
          [[ -z "$origin" || "$origin" =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] \
            || die "publication origin must be canonical HTTPS without path or port"
        done < <(jq -r '.services[]?.origin // empty' "$path")
        ;;
      *) die "unsupported instance config file: $rel" ;;
    esac
  done < <(find -P "$config_source" -mindepth 1 -maxdepth 1 -type f -print0)
fi

new_manifest="$(mktemp)"
affected="$(mktemp)"
cleanup_files() { rm -f "$new_manifest" "$affected"; }
trap cleanup_files EXIT

{
  if [[ -d "$config_source" ]]; then
    while IFS= read -r -d '' path; do
      printf 'config/%s\n' "${path#"$config_source"/}"
    done < <(find -P "$config_source" -type f -print0 | sort -z)
  fi
  if [[ -d "$secrets_source" ]]; then
    while IFS= read -r -d '' path; do
      printf 'secrets/%s\n' "${path#"$secrets_source"/}"
    done < <(find -P "$secrets_source" -type f -print0 | sort -z)
  fi
} > "$new_manifest"

if [[ -f "$manifest" ]]; then
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    [[ "$rel" =~ ^(config|secrets)/[A-Za-z0-9._/-]+$ ]] || die "invalid previous managed path: $rel"
    printf '%s\n' "$rel"
  done < "$manifest" >> "$affected"
fi
cat "$new_manifest" >> "$affected"
sort -u -o "$affected" "$affected"

backup="$root/backups/configure/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$backup"
chmod 700 "$backup"
restore_manifest="$backup/restore.manifest"
: > "$restore_manifest"
chmod 600 "$restore_manifest"

while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  target="$root/$rel"
  [[ ! -L "$target" ]] || die "managed target must not be a symlink: $target"
  if [[ -e "$target" ]]; then
    [[ -f "$target" ]] || die "managed target must be a regular file: $target"
    mkdir -p "$backup/$(dirname "$rel")"
    cp -a "$target" "$backup/$rel"
    printf 'existing\t%s\n' "$rel" >> "$restore_manifest"
  else
    printf 'new\t%s\n' "$rel" >> "$restore_manifest"
  fi
done < "$affected"

committed=false
rollback_on_error() {
  local rc=$?
  if [[ $rc -ne 0 && "$committed" != true ]]; then
    while IFS=$'\t' read -r action rel; do
      [[ -n "$rel" ]] || continue
      target="$root/$rel"
      case "$action" in
        existing)
          mkdir -p "$(dirname "$target")"
          cp -a "$backup/$rel" "$target"
          ;;
        new) rm -f "$target" ;;
      esac
    done < "$restore_manifest"
  fi
  cleanup_files
  exit "$rc"
}
trap rollback_on_error EXIT

if [[ -f "$manifest" ]]; then
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    grep -Fxq "$rel" "$new_manifest" || rm -f "$root/$rel"
  done < "$manifest"
fi

if [[ -d "$config_source" ]]; then
  while IFS= read -r -d '' path; do
    rel=${path#"$config_source"/}
    target="$root/config/$rel"
    tmp="${target}.next.$$"
    install -o root -g root -m 600 "$path" "$tmp"
    mv -f "$tmp" "$target"
  done < <(find -P "$config_source" -mindepth 1 -maxdepth 1 -type f -print0)
fi

if [[ -d "$secrets_source" ]]; then
  while IFS= read -r -d '' path; do
    rel=${path#"$secrets_source"/}
    target="$root/secrets/$rel"
    mkdir -p "$(dirname "$target")"
    chmod 700 "$(dirname "$target")"
    tmp="${target}.next.$$"
    install -o root -g root -m 600 "$path" "$tmp"
    mv -f "$tmp" "$target"
  done < <(find -P "$secrets_source" -type f -print0)
  find "$root/secrets" -type d -exec chmod 700 {} +
fi

manifest_next="${manifest}.next.$$"
install -o root -g root -m 600 "$new_manifest" "$manifest_next"
mv -f "$manifest_next" "$manifest"
committed=true

if [[ -z "$(find "$backup" -mindepth 1 ! -name restore.manifest -print -quit)" ]]; then
  rm -rf "$backup"
fi

log "instance configuration applied from local source"
