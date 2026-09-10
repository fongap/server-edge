#!/usr/bin/env bash

ensure_platform_config() {
  local release_dir="$1"
  local root="$2"
  local config_root="$root/config"
  local publications="$config_root/publications.json"
  local default_publications="$release_dir/config/publications.default.json"
  local key origin

  mkdir -p "$config_root"
  chown root:root "$config_root"
  chmod 755 "$config_root"

  if [[ ! -e "$publications" ]]; then
    cp "$default_publications" "$publications"
    chown root:root "$publications"
    chmod 644 "$publications"
  fi

  [[ ! -L "$publications" ]] || die "platform publications config must not be a symlink: $publications"
  [[ "$(stat -c '%U' "$publications")" == root ]] || die "platform publications config must be owned by root: $publications"
  jq -e '.schema_version == 1 and (.services | type == "object") and all(.services[]; type == "object")' "$publications" >/dev/null \
    || die "invalid platform publications config: $publications"

  while IFS= read -r key; do
    [[ "$key" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || die "invalid publication service id: $key"
    origin="$(jq -r --arg id "$key" '.services[$id].origin // empty' "$publications")"
    [[ -n "$origin" ]] || continue
    [[ "$origin" =~ ^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] \
      || die "publication $key origin must be canonical HTTPS without path or port"
  done < <(jq -r '.services | keys[]' "$publications")
}

ensure_module_config() {
  local release_dir="$1"
  local root="$2"
  local module="$3"
  local defaults="$release_dir/$module/config/defaults.env"
  local target="$root/config/$module.env"

  [[ -f "$defaults" ]] || return 0
  mkdir -p "$root/config"
  if [[ ! -e "$target" ]]; then
    cat > "$target" <<EOF
# Server Edge instance overrides for $module.
# Keep only values that differ from release defaults in $module/config/defaults.env.
EOF
    chown root:root "$target"
    chmod 600 "$target"
  fi
  [[ ! -L "$target" ]] || die "module config must not be a symlink: $target"
  [[ "$(stat -c '%U' "$target")" == root ]] || die "module config must be owned by root: $target"
}

resolve_publication_origin() {
  local root="$1"
  local service_id="$2"
  local publications="$root/config/publications.json"
  [[ -s "$publications" ]] || return 0
  jq -r --arg id "$service_id" '.services[$id].origin // empty' "$publications"
}
