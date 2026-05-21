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
                          Set current_window: true in config to make this default
                          (For multiple projects, only the first uses current window)
  --new-window            Create a new Ghostty window, overriding current_window

Layouts:
  Row notation uses '-' for top-to-bottom rows:
    "2"      2 sections side-by-side
    "2-2"    2 top + 2 bottom (4 sections)
    "1-3"    1 top + 3 bottom (4 sections)

  Column notation uses '|' for left-to-right columns:
    "1|2"    1 main left + 2 stacked on the right
    "2|1"    2 stacked on the left + 1 main right

  Command order is spatial. Rows fill left-to-right, then top-to-bottom.
  Columns fill top-to-bottom, then left-to-right.
  Max 10 sections total; max 4 rows or columns.

  Aliases:
    duo        2 sections side-by-side
    trio       3 sections side-by-side
    quad       2x2 grid (4 sections)
    dashboard  1 top + 3 bottom (4 sections)
    stacked    2 sections vertically
    wide       3 top + 1 bottom (4 sections)
    main-side  1 main left + 2 stacked on the right
    side-main  2 stacked on the left + 1 main right

Tabs (optional):
  Add 'tabs: N' to your config (2-10) to create multiple tabs.
  Each tab will have the layout you specify.

  Example: layout: duo + tabs: 3 = 3 tabs, each with 2 sections

Examples:
  gpane setup               # First-time setup
  gpane myproject           # Launch session in new window
  gpane myproject --here    # Launch session in current window
  gpane myproject --new-window
                            # Override current_window config for this launch
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
