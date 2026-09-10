#!/usr/bin/env bash
set -Eeuo pipefail

repo=""
ref=""
root=/opt/server-edge
profile=profiles/default.json
instance_source=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo=$2; shift 2 ;;
    --ref) ref=$2; shift 2 ;;
    --root) root=$2; shift 2 ;;
    --profile) profile=$2; shift 2 ;;
    --instance-source) instance_source=$2; shift 2 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ -n "$repo" && -n "$ref" ]] || { echo 'ERROR: --repo and --ref are required' >&2; exit 2; }
[[ "$(uname -s)" == Linux ]] || { echo 'ERROR: Server Edge requires Linux' >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo 'ERROR: run bootstrap with sudo/root' >&2; exit 1; }
command -v curl >/dev/null || { echo 'ERROR: curl is required to fetch the release' >&2; exit 1; }
command -v tar >/dev/null || { echo 'ERROR: tar is required to unpack the release' >&2; exit 1; }
[[ -z "$instance_source" || -d "$instance_source" ]] || { echo 'ERROR: --instance-source must be an existing local directory' >&2; exit 2; }

mkdir -p "$root/releases" "$root/runtime"
archive="$(mktemp)"; tmp="$(mktemp -d)"
cleanup() { rm -f "$archive"; rm -rf "$tmp"; }
trap cleanup EXIT
headers=(-H 'Accept: application/vnd.github+json')
[[ -n "${GITHUB_TOKEN:-}" ]] && headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
curl -fL --retry 3 --retry-delay 2 "${headers[@]}" \
  "https://api.github.com/repos/${repo}/tarball/${ref}" -o "$archive"
tar -xzf "$archive" -C "$tmp"
source_dir="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
[[ -n "$source_dir" ]] || { echo 'ERROR: invalid GitHub archive' >&2; exit 1; }
release_id="$(printf '%s' "$ref" | tr '/:@ ' '____' | tr -cd '[:alnum:]._+-')-$(date -u +%Y%m%d%H%M%S)"
release_dir="$root/releases/$release_id"
mv "$source_dir" "$release_dir"

# GitHub archive extraction may not preserve executable bits for scripts created via the Contents API.
source "$release_dir/install/lib/common.sh"
ensure_release_script_modes "$release_dir"

install_args=(--root "$root" --profile "$profile")
[[ -z "$instance_source" ]] || install_args+=(--instance-source "$instance_source")
bash "$release_dir/install/install.sh" "${install_args[@]}"
ln -sfn "$release_dir" "$root/current.next"
mv -Tf "$root/current.next" "$root/current"
cat > "$root/runtime/install.env" <<META
SERVER_EDGE_REPOSITORY=$repo
SERVER_EDGE_REF=$ref
SERVER_EDGE_RELEASE_ID=$release_id
META
chmod 600 "$root/runtime/install.env"
printf '[server-edge] installed %s@%s as %s\n' "$repo" "$ref" "$release_id"
