# gsx update checker
# Checks GitHub for new versions

GSX_REPO="minorole/gsx"
GSX_UPDATE_CACHE="${HOME}/.cache/gsx/update-check"

# Validate version string (basic semver: X.Y.Z with optional pre-release)
is_valid_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]
}

# Check for updates (runs in background, caches for 24 hours)
check_for_updates() {
  # Skip if no internet commands available
  if ! command -v curl &>/dev/null; then
    return 0
  fi

  # Create cache directory if needed
  mkdir -p "$(dirname "${GSX_UPDATE_CACHE}")"

  local now=$(date +%s)
  local cache_max_age=86400  # 24 hours

  # Check if cache exists and is fresh
  if [[ -f "${GSX_UPDATE_CACHE}" ]]; then
    local cache_time=$(head -1 "${GSX_UPDATE_CACHE}" 2>/dev/null || echo 0)
    local cache_age=$((now - cache_time))

    if (( cache_age < cache_max_age )); then
      # Cache is fresh, show cached result if update available
      local cached_version=$(tail -1 "${GSX_UPDATE_CACHE}" 2>/dev/null)
      # Validate cached version; clear corrupted cache
      if ! is_valid_version "${cached_version}"; then
        rm -f "${GSX_UPDATE_CACHE}"
      elif [[ "${cached_version}" != "${GSX_VERSION}" ]]; then
        show_update_notice "${cached_version}"
      fi
      return 0
    fi
  fi

  # Fetch latest version in background (don't block)
  {
    local latest=$(curl -sf --max-time 3 \
      "https://api.github.com/repos/${GSX_REPO}/releases/latest" 2>/dev/null \
      | grep '"tag_name"' | head -1 | cut -d'"' -f4 | sed 's/^v//')

    # If no releases, try tags
    if [[ -z "${latest}" ]]; then
      latest=$(curl -sf --max-time 3 \
        "https://api.github.com/repos/${GSX_REPO}/tags" 2>/dev/null \
        | grep '"name"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
    fi

    # Save to cache atomically (only if valid version)
    if is_valid_version "${latest}"; then
      printf '%s\n%s\n' "${now}" "${latest}" > "${GSX_UPDATE_CACHE}"
    fi
  } &>/dev/null &
  disown 2>/dev/null
}

# Compare versions: returns 0 if $1 > $2
is_newer_version() {
  local v1=$1 v2=$2
  # Split by dots and compare each part
  local IFS='.'
  local -a parts1=(${=v1%%-*})  # Remove pre-release suffix
  local -a parts2=(${=v2%%-*})

  for i in 1 2 3; do
    local p1=${parts1[$i]:-0}
    local p2=${parts2[$i]:-0}
    (( p1 > p2 )) && return 0
    (( p1 < p2 )) && return 1
  done
  return 1  # Equal, not newer
}

# Display update notice
show_update_notice() {
  local latest_version=$1

  # Only show if latest is actually newer than current
  if ! is_newer_version "${latest_version}" "${GSX_VERSION}"; then
    return 0
  fi

  echo ""
  echo "Update available: v${GSX_VERSION} -> v${latest_version}"
  echo ""

  # Detect install method and show appropriate update command
  if command -v brew &>/dev/null && brew list gsx &>/dev/null 2>&1; then
    echo "  Update with: brew upgrade gsx"
  elif [[ -d "${HOME}/.local/share/gsx/.git" ]]; then
    echo "  Update with: cd ~/.local/share/gsx && git pull && ./install.sh"
  else
    echo "  Update with: cd <gsx-repo> && git pull && ./install.sh"
  fi
  echo ""
}
