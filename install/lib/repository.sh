#!/usr/bin/env bash
set -Eeuo pipefail

fetch_release() {
  local repo=$1 ref=$2 root=$3
  local release_id archive tmp extract_dir release_dir
  release_id="$(sanitize_ref "$ref")-$(date -u +%Y%m%d%H%M%S)"
  archive="$(mktemp)"
  tmp="$(mktemp -d)"

  local -a headers=(-H 'Accept: application/vnd.github+json')
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  log "fetching ${repo}@${ref}"
  curl -fL --retry 3 --retry-delay 2 "${headers[@]}" \
    "https://api.github.com/repos/${repo}/tarball/${ref}" -o "$archive"

  tar -xzf "$archive" -C "$tmp"
  extract_dir="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  [[ -n "$extract_dir" ]] || die "invalid GitHub archive"

  mkdir -p "$root/releases"
  release_dir="$root/releases/$release_id"
  mv "$extract_dir" "$release_dir"
  ensure_release_script_modes "$release_dir"

  rm -f "$archive"
  rm -rf "$tmp"
  printf '%s\n' "$release_dir"
}
