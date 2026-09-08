#!/usr/bin/env bash
set -Eeuo pipefail

[[ "$(uname -s)" == "Linux" ]] || {
  printf 'SERVER_EDGE_HOST_OS=%q\n' "$(uname -s | tr '[:upper:]' '[:lower:]')"
  exit 0
}

normalize_arch() {
  case "$1" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    armv7l|armv7) printf 'armv7' ;;
    *) printf '%s' "$1" ;;
  esac
}

package_manager=unknown
for candidate in apt-get dnf yum apk pacman zypper; do
  if command -v "$candidate" >/dev/null 2>&1; then
    package_manager="$candidate"
    break
  fi
done

service_manager=unknown
if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
  service_manager=systemd
elif command -v rc-service >/dev/null 2>&1; then
  service_manager=openrc
fi

host_id=unknown
host_version=unknown
host_codename=unknown
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  host_id="${ID:-unknown}"
  host_version="${VERSION_ID:-unknown}"
  host_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-unknown}}"
fi

environment="${SERVER_EDGE_ENVIRONMENT:-unknown}"
case "$environment" in cloud|local|unknown) ;; *) environment=unknown ;; esac

printf 'SERVER_EDGE_HOST_OS=%q\n' linux
printf 'SERVER_EDGE_HOST_ARCH=%q\n' "$(normalize_arch "$(uname -m)")"
printf 'SERVER_EDGE_HOST_ID=%q\n' "$host_id"
printf 'SERVER_EDGE_HOST_VERSION=%q\n' "$host_version"
printf 'SERVER_EDGE_HOST_CODENAME=%q\n' "$host_codename"
printf 'SERVER_EDGE_HOST_PACKAGE_MANAGER=%q\n' "$package_manager"
printf 'SERVER_EDGE_HOST_SERVICE_MANAGER=%q\n' "$service_manager"
printf 'SERVER_EDGE_HOST_ENVIRONMENT=%q\n' "$environment"
printf 'SERVER_EDGE_HOST_DOCKER=%q\n' "$(command -v docker >/dev/null 2>&1 && printf true || printf false)"
printf 'SERVER_EDGE_HOST_COMPOSE=%q\n' "$(docker compose version >/dev/null 2>&1 && printf true || printf false)"
printf 'SERVER_EDGE_HOST_TAILSCALE=%q\n' "$(command -v tailscale >/dev/null 2>&1 && command -v tailscaled >/dev/null 2>&1 && printf true || printf false)"
