# gpane help and uninstall
# Help text and uninstall function

# Show help
show_help() {
  cat <<EOF
gpane - Ghostty Session Manager v${GPANE_VERSION}

Usage:
  gpane                     Interactive picker (type "1 3 5" to open multiple)
  gpane <project>           Launch session (searches projects_root, then current dir)
  gpane list                List all projects
  gpane setup               Run setup wizard
  gpane setup <project>     Configure project-specific overrides
  gpane config              Show current configuration
  gpane uninstall           Remove gpane from your system
  gpane help                Show this help

Options:
  --dry-run               Show what would happen without opening windows
  --here, --current-window
                          Use current Ghostty window instead of creating new one
                          (For multiple projects, only the first uses current window)

Layouts:
  Row notation: "2" (2 side-by-side), "2-2" (4-pane grid), "1-3" (1 top + 3 bottom)

  Aliases:
    tabs       Multiple tabs (one command per tab, up to 10)
    duo        2 panes side-by-side
    trio       3 panes side-by-side
    quad       2x2 grid (4 panes)
    dashboard  1 top + 3 bottom (4 panes)
    stacked    2 panes vertically
    wide       3 top + 1 bottom (4 panes)

Examples:
  gpane setup               # First-time setup
  gpane myproject           # Launch session in new window
  gpane myproject --here    # Launch session in current window
  gpane myproject --dry-run # Preview without launching
  gpane list                # See all projects
  gpane ./help              # Open project named 'help' (use ./ for reserved names)
  cd ~/monorepo && gpane frontend  # Open nested project from current directory

Requirements:
  - macOS (uses AppleScript for window management)
  - Ghostty terminal (https://ghostty.org)

More info: https://github.com/minorole/gsx
EOF
}

# Uninstall gpane
do_uninstall() {
  echo ""
  echo "gpane uninstall"
  echo "==============="
  echo ""
  echo "This will remove:"
  echo "  - ~/.local/share/gpane/ (program files)"
  echo "  - ~/.local/bin/gpane (symlink)"
  echo "  - ~/.local/bin/gsx (compatibility symlink)"
  echo ""

  # Detect which config directory exists
  local config_path=""
  if [[ -d "${HOME}/.config/gsx" ]]; then
    config_path="${HOME}/.config/gsx"
  elif [[ -d "${HOME}/.config/gpane" ]]; then
    config_path="${HOME}/.config/gpane"
  fi

  local remove_config=""
  if [[ -n "${config_path}" ]]; then
    prompt_input "Also remove config (${config_path})? [y/N]: " remove_config
  fi
  echo ""

  if [[ -d "${HOME}/.local/share/gpane" ]]; then
    rm -rf "${HOME}/.local/share/gpane"
    echo "Removed: ~/.local/share/gpane/"
  fi

  # Also remove old gsx location if exists
  if [[ -d "${HOME}/.local/share/gsx" ]]; then
    rm -rf "${HOME}/.local/share/gsx"
    echo "Removed: ~/.local/share/gsx/ (old location)"
  fi

  if [[ -L "${HOME}/.local/bin/gpane" ]]; then
    rm -f "${HOME}/.local/bin/gpane"
    echo "Removed: ~/.local/bin/gpane"
  fi

  if [[ -L "${HOME}/.local/bin/gsx" ]]; then
    rm -f "${HOME}/.local/bin/gsx"
    echo "Removed: ~/.local/bin/gsx"
  fi

  # Clean up cache
  rm -rf "${HOME}/.cache/gpane"
  rm -rf "${HOME}/.cache/gsx"

  if [[ "${remove_config}" =~ ^[Yy]$ ]]; then
    # Remove whichever config directory exists
    if [[ -d "${HOME}/.config/gsx" ]]; then
      rm -rf "${HOME}/.config/gsx"
      echo "Removed: ~/.config/gsx/"
    fi
    if [[ -d "${HOME}/.config/gpane" ]]; then
      rm -rf "${HOME}/.config/gpane"
      echo "Removed: ~/.config/gpane/"
    fi
  elif [[ -n "${config_path}" ]]; then
    echo "Kept: ${config_path}/ (your settings)"
  fi

  echo ""
  echo "gpane has been uninstalled."
  echo ""
}
