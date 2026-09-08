#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

root="${SERVER_EDGE_ROOT:-/opt/server-edge}"
mode="${SERVER_EDGE_OVERLAY:-auto}"
case "$mode" in auto|off|required) ;; *) die "SERVER_EDGE_OVERLAY must be auto, off, or required" ;; esac
[[ "$mode" == off ]] && { log "overlay network disabled"; exit 0; }

if ! command -v tailscale >/dev/null 2>&1 || ! command -v tailscaled >/dev/null 2>&1; then
  host_file="$(mktemp)"
  trap 'rm -f "$host_file"' EXIT
  bash "$RELEASE_DIR/infra/host/detect.sh" > "$host_file"
  source "$host_file"

  if [[ "$SERVER_EDGE_HOST_PACKAGE_MANAGER" == apt-get && "$SERVER_EDGE_HOST_SERVICE_MANAGER" == systemd ]]; then
    case "$SERVER_EDGE_HOST_ID" in
      ubuntu|debian) ;;
      *)
        [[ "$mode" == required ]] && die "automatic Tailscale installation supports Ubuntu/Debian in M1"
        log "Tailscale not installed: no supported overlay adapter for $SERVER_EDGE_HOST_ID"
        exit 0
        ;;
    esac

    bash "$RELEASE_DIR/infra/host/adapters/package/apt.sh"
    codename="$SERVER_EDGE_HOST_CODENAME"
    [[ "$codename" != unknown && -n "$codename" ]] || die "cannot determine distro codename for Tailscale repository"
    install -m 0755 -d /usr/share/keyrings
    curl -fsSL "https://pkgs.tailscale.com/stable/${SERVER_EDGE_HOST_ID}/${codename}.noarmor.gpg" \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg
    curl -fsSL "https://pkgs.tailscale.com/stable/${SERVER_EDGE_HOST_ID}/${codename}.tailscale-keyring.list" \
      -o /etc/apt/sources.list.d/tailscale.list
    apt-get update
    apt-get install -y tailscale
    systemctl enable --now tailscaled
  else
    [[ "$mode" == required ]] && die "Tailscale is required but no supported installer is available"
    log "Tailscale not installed; overlay remains optional on this compatible host"
    exit 0
  fi
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now tailscaled >/dev/null 2>&1 || true
fi

auth_file="$root/secrets/infra/tailscale-auth-key"
backend_state="$(tailscale status --json 2>/dev/null | jq -r '.BackendState // empty' 2>/dev/null || true)"
if [[ "$backend_state" == Running ]]; then
  log "Tailscale already connected"
elif [[ -s "$auth_file" ]]; then
  chown root:root "$auth_file"
  chmod 600 "$auth_file"
  hostname="${SERVER_EDGE_TAILSCALE_HOSTNAME:-$(hostname -s)}"
  tailscale up --auth-key="file:${auth_file}" --hostname="$hostname" --accept-dns=false
  log "Tailscale authenticated as $hostname"
else
  log "Tailscale installed; authentication deferred (optional secret: $auth_file)"
fi
