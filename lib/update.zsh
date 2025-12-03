# gsx update checker
# Checks GitHub for new versions

GSX_REPO="minorole/gsx"
GSX_UPDATE_CACHE="${HOME}/.cache/gsx/update-check"

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
      if [[ -n "${cached_version}" && "${cached_version}" != "${GSX_VERSION}" ]]; then
        show_update_notice "${cached_version}"
      fi
      return 0
    fi
  fi

  # Fetch latest version in background (don't block)
  {
    local latest=$(curl -sf --max-time 3 \
      "https://api.github.com/repos/${GSX_REPO}/releases/latest" 2>/dev/null \
      | grep '"tag_name"' | head -1 | sed 's/.*"v\?\([^"]*\)".*/\1/')

    # If no releases, try tags
    if [[ -z "${latest}" ]]; then
      latest=$(curl -sf --max-time 3 \
        "https://api.github.com/repos/${GSX_REPO}/tags" 2>/dev/null \
        | grep '"name"' | head -1 | sed 's/.*"v\?\([^"]*\)".*/\1/')
    fi

    # Save to cache
    if [[ -n "${latest}" ]]; then
      echo "${now}" > "${GSX_UPDATE_CACHE}"
      echo "${latest}" >> "${GSX_UPDATE_CACHE}"
    fi
  } &>/dev/null &
  disown 2>/dev/null
}

# Display update notice
show_update_notice() {
  local latest_version=$1

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
