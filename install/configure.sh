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
[[ -d "$source_dir" ]] || die "instance source not found: $source_dir"
need_cmd jq

config_source="$source_dir/config"
secrets_source="$source_dir/secrets"
manifest="$root/runtime/config-source.manifest"

mkdir -p "$root/config" "$root/secrets" "$root/runtime" "$root/backups/configure"
chown root:root "$root/config" "$root/secrets" "$root/runtime" "$root/backups/configure"
chmod 755 "$root/config"
chmod 700 "$root/secrets" "$root/backups/configure"

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
cleanup_manifest() { rm -f "$new_manifest"; }
trap cleanup_manifest EXIT

if [[ -d "$config_source" ]]; then
  while IFS= read -r -d '' path; do
    printf 'config/%s\n' "${path#"$config_source"/}"
  done < <(find -P "$config_source" -type f -print0 | sort -z)
fi
if [[ -d "$secrets_source" ]]; then
  while IFS= read -r -d '' path; do
    printf 'secrets/%s\n' "${path#"$secrets_source"/}"
  done < <(find -P "$secrets_source" -type f -print0 | sort -z)
fi > "$new_manifest"

backup="$root/backups/configure/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$backup"
chmod 700 "$backup"

backup_target() {
  local rel=$1 target="$root/$1"
  [[ -e "$target" ]] || return 0
  mkdir -p "$backup/$(dirname "$rel")"
  cp -a "$target" "$backup/$rel"
}

if [[ -f "$manifest" ]]; then
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    [[ "$rel" =~ ^(config|secrets)/[A-Za-z0-9._/-]+$ ]] || die "invalid previous managed path: $rel"
    backup_target "$rel"
  done < "$manifest"
fi
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  backup_target "$rel"
done < "$new_manifest"

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

if [[ -z "$(find "$backup" -mindepth 1 -print -quit)" ]]; then
  rmdir "$backup"
fi

log "instance configuration applied from local source"
