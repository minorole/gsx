# gsx help and uninstall
# Help text and uninstall function

# Show help
show_help() {
  cat <<EOF
gsx - Ghostty Session Manager v${GSX_VERSION}

Usage:
  gsx                     Interactive project picker
  gsx <project>           Launch session for project
  gsx list                List all projects
  gsx setup               Run setup wizard
  gsx setup <project>     Configure project-specific overrides
  gsx config              Show current configuration
  gsx uninstall           Remove gsx from your system
  gsx help                Show this help

Options:
  --dry-run               Show what would happen without opening windows

Examples:
  gsx setup               # First-time setup
  gsx myproject           # Launch session for 'myproject'
  gsx myproject --dry-run # Preview without launching
  gsx list                # See all projects
  gsx ./help              # Open project named 'help' (use ./ for reserved names)

Requirements:
  - macOS (uses AppleScript for window management)
  - Ghostty terminal (https://ghostty.org)

More info: https://github.com/minorole/gsx
EOF
}

# Uninstall gsx
do_uninstall() {
  echo ""
  echo "gsx uninstall"
  echo "============="
  echo ""
  echo "This will remove:"
  echo "  - ~/.local/share/gsx/ (program files)"
  echo "  - ~/.local/bin/gsx (symlink)"
  echo ""
  local remove_config=""
  prompt_input "Also remove config (~/.config/gsx)? [y/N]: " remove_config
  echo ""

  if [[ -d "${HOME}/.local/share/gsx" ]]; then
    rm -rf "${HOME}/.local/share/gsx"
    echo "Removed: ~/.local/share/gsx/"
  fi

  if [[ -L "${HOME}/.local/bin/gsx" ]]; then
    rm -f "${HOME}/.local/bin/gsx"
    echo "Removed: ~/.local/bin/gsx"
  fi

  if [[ "${remove_config}" =~ ^[Yy]$ ]]; then
    if [[ -d "${HOME}/.config/gsx" ]]; then
      rm -rf "${HOME}/.config/gsx"
      echo "Removed: ~/.config/gsx/"
    fi
  else
    echo "Kept: ~/.config/gsx/ (your settings)"
  fi

  echo ""
  echo "gsx has been uninstalled."
  echo ""
}
