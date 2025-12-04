# gsx core
# Version, constants, and preflight checks

GSX_VERSION="0.1.1"

# Preflight checks (macOS, osascript)
preflight_check() {
  if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: gsx only supports macOS."
    echo "Linux support is planned for a future release."
    exit 1
  fi

  if ! command -v osascript &>/dev/null; then
    echo "Error: 'osascript' not found."
    echo "This is required for controlling Ghostty windows."
    exit 1
  fi
}

# Check if Ghostty is installed
check_ghostty() {
  if command -v ghostty &>/dev/null; then
    return 0
  fi
  if [[ -d "/Applications/Ghostty.app" ]]; then
    return 0
  fi

  echo "Error: Ghostty is not installed."
  echo ""
  echo "Install from: https://ghostty.org"
  echo ""
  echo "After installing, run 'gsx' again."
  exit 1
}
