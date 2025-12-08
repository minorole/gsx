#!/usr/bin/env bash

set -e

# gpane installer (formerly gsx)
# https://github.com/minorole/gsx

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GPANE_VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "dev")"
INSTALL_DIR="${HOME}/.local/bin"
GPANE_HOME="${HOME}/.local/share/gpane"
OLD_GSX_HOME="${HOME}/.local/share/gsx"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Detect non-interactive mode
NON_INTERACTIVE=false
if [[ ! -t 0 ]] || [[ -n "${CI:-}" ]]; then
  NON_INTERACTIVE=true
fi
if [[ "${1:-}" == "-y" ]] || [[ "${1:-}" == "--yes" ]]; then
  NON_INTERACTIVE=true
fi

echo ""
echo -e "${BOLD}gpane installer v${GPANE_VERSION}${NC}"
echo "============================="
echo ""

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${YELLOW}Error:${NC} gpane currently only supports macOS."
  echo "(Linux support may come in future versions)"
  exit 1
fi

# Check for zsh
if ! command -v zsh &>/dev/null; then
  echo -e "${YELLOW}Error:${NC} zsh is required but not found."
  echo "macOS should have zsh by default. Please check your system."
  exit 1
fi

# Check for Ghostty
if ! command -v ghostty &>/dev/null && [[ ! -d "/Applications/Ghostty.app" ]]; then
  echo -e "${YELLOW}Warning:${NC} Ghostty is not installed."
  echo ""
  echo "gpane requires Ghostty terminal to work."
  echo -e "Download from: ${BLUE}https://ghostty.org${NC}"
  echo ""
  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    echo "(Continuing anyway - non-interactive mode)"
    echo ""
  else
    printf "Continue installation anyway? [y/N]: "
    read -r continue_install
    if [[ ! "${continue_install}" =~ ^[Yy]$ ]]; then
      echo "Installation cancelled. Install Ghostty first, then run this again."
      exit 0
    fi
    echo ""
  fi
fi

# Migrate from old gsx installation
if [[ -d "${OLD_GSX_HOME}" ]]; then
  echo -e "${YELLOW}Migrating from gsx to gpane...${NC}"
  echo "(gsx was renamed to avoid conflict with Ghostscript)"
  echo ""
  rm -rf "${OLD_GSX_HOME}"
  rm -rf "${HOME}/.cache/gsx"
  # Note: User config is preserved (~/.config/gsx or ~/.config/gpane)
  # Note: ~/.local/bin/gsx will be overwritten with wrapper
  echo -e "${GREEN}✓${NC} Migration complete"
  echo ""
fi

# Create directories
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${GPANE_HOME}/lib"
mkdir -p "${GPANE_HOME}/scripts"

# Copy files
echo -e "${BLUE}Installing gpane...${NC}"

cp "${SCRIPT_DIR}/bin/gpane" "${GPANE_HOME}/gpane"
cp "${SCRIPT_DIR}/bin/gsx" "${GPANE_HOME}/gsx"
cp "${SCRIPT_DIR}/VERSION" "${GPANE_HOME}/VERSION"
cp "${SCRIPT_DIR}/lib/"*.zsh "${GPANE_HOME}/lib/"
cp "${SCRIPT_DIR}/scripts/"*.applescript "${GPANE_HOME}/scripts/"
chmod +x "${GPANE_HOME}/gpane"
chmod +x "${GPANE_HOME}/gsx"

# Update the script to use installed location
sed -i '' "s|GPANE_ROOT=\"\${0:A:h:h}\"|GPANE_ROOT=\"${GPANE_HOME}\"|" "${GPANE_HOME}/gpane"

# Create symlinks
ln -sf "${GPANE_HOME}/gpane" "${INSTALL_DIR}/gpane"
ln -sf "${GPANE_HOME}/gsx" "${INSTALL_DIR}/gsx"

echo ""

# Add to PATH if needed
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  ZSHRC="${HOME}/.zshrc"
  PATH_LINE="export PATH=\"${INSTALL_DIR}:\$PATH\""

  # Check if already in .zshrc
  if ! grep -q "${INSTALL_DIR}" "${ZSHRC}" 2>/dev/null; then
    echo "" >> "${ZSHRC}"
    echo "# gpane" >> "${ZSHRC}"
    echo "${PATH_LINE}" >> "${ZSHRC}"
    echo -e "${GREEN}✓${NC} Added PATH to ~/.zshrc"
  fi

  echo ""
  echo -e "${RED}Restart${NC} your terminal or run: ${BOLD}source ~/.zshrc${NC}"
fi

echo ""
echo -e "${GREEN}✓ gpane installed successfully!${NC}"
echo ""

# Accessibility permission reminder
echo -e "${YELLOW}Important:${NC} gpane needs Accessibility permission to control Ghostty."
echo "Grant it in: System Settings → Privacy & Security → Accessibility"
echo "Add your terminal app (Terminal.app, iTerm, etc.) to the list."
echo ""

# Offer to run setup
if [[ "${NON_INTERACTIVE}" == "true" ]]; then
  echo "Next steps:"
  echo -e "  1. Run ${BOLD}gpane setup${NC} to configure"
  echo -e "  2. Run ${BOLD}gpane${NC} to launch sessions"
  echo ""
  echo -e "More info: ${BLUE}https://github.com/minorole/gsx${NC}"
  echo ""
else
  printf "Run ${BOLD}gpane setup${NC} now? [Y/n]: "
  read -r run_setup

  if [[ ! "${run_setup}" =~ ^[Nn]$ ]]; then
    echo ""
    "${GPANE_HOME}/gpane" setup

    # Remind about PATH if needed
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
      echo ""
      echo -e "${RED}Restart${NC} your terminal or run ${BOLD}source ~/.zshrc${NC} to use ${BOLD}gpane${NC} command"
    fi
  else
    echo ""
    echo "Next steps:"
    echo -e "  1. Run ${BOLD}gpane setup${NC} to configure"
    echo -e "  2. Run ${BOLD}gpane${NC} to launch sessions"
    echo ""
    echo -e "More info: ${BLUE}https://github.com/minorole/gsx${NC}"
    echo ""
  fi
fi
