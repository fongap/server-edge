#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$(cd "$HERE/../../.." && pwd)"
source "$RELEASE_DIR/install/lib/common.sh"

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    log "container runtime already available: $(docker --version) / $(docker compose version --short 2>/dev/null || docker compose version)"
    exit 0
  fi
  die "Docker is already installed but Compose v2 is missing; refusing to replace an existing runtime automatically"
fi

host_file="$(mktemp)"
trap 'rm -f "$host_file"' EXIT
bash "$RELEASE_DIR/infra/host/detect.sh" > "$host_file"
source "$host_file"

[[ "$SERVER_EDGE_HOST_PACKAGE_MANAGER" == apt-get ]] || die "no Docker installer for package manager: $SERVER_EDGE_HOST_PACKAGE_MANAGER"
[[ "$SERVER_EDGE_HOST_SERVICE_MANAGER" == systemd ]] || die "automatic Docker installation currently requires systemd"
case "$SERVER_EDGE_HOST_ID" in ubuntu|debian) ;; *) die "automatic Docker installation currently supports Ubuntu and Debian" ;; esac

bash "$RELEASE_DIR/infra/host/adapters/package/apt.sh"

for conflict in docker.io docker-compose docker-compose-v2 podman-docker containerd runc; do
  if dpkg-query -W -f='${Status}' "$conflict" 2>/dev/null | grep -q 'ok installed'; then
    die "conflicting package detected: $conflict; remove or migrate it explicitly before Server Edge installs Docker CE"
  fi
done

repo_family="$SERVER_EDGE_HOST_ID"
codename="$SERVER_EDGE_HOST_CODENAME"
[[ "$codename" != unknown && -n "$codename" ]] || die "cannot determine distro codename for Docker repository"

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${repo_family}/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
arch="$(dpkg --print-architecture)"
cat > /etc/apt/sources.list.d/docker.sources <<EOF_REPO
Types: deb
URIs: https://download.docker.com/linux/${repo_family}
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF_REPO

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

docker info >/dev/null
docker compose version >/dev/null
log "container runtime installed"
