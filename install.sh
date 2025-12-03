#!/usr/bin/env bash

set -e

# gsx installer
# https://github.com/minorole/gsx

GSX_VERSION="0.1.0"
INSTALL_DIR="${HOME}/.local/bin"
GSX_HOME="${HOME}/.local/share/gsx"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${BOLD}gsx installer v${GSX_VERSION}${NC}"
echo "========================="
echo ""

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${YELLOW}Error:${NC} gsx currently only supports macOS."
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
  echo "gsx requires Ghostty terminal to work."
  echo -e "Download from: ${BLUE}https://ghostty.org${NC}"
  echo ""
  printf "Continue installation anyway? [y/N]: "
  read -r continue_install
  if [[ ! "${continue_install}" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled. Install Ghostty first, then run this again."
    exit 0
  fi
  echo ""
fi

# Create directories
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${GSX_HOME}/lib"
mkdir -p "${GSX_HOME}/scripts"

# Copy files
echo -e "${BLUE}Installing gsx...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "${SCRIPT_DIR}/bin/gsx" "${GSX_HOME}/gsx"
cp "${SCRIPT_DIR}/lib/"*.zsh "${GSX_HOME}/lib/"
cp "${SCRIPT_DIR}/scripts/"*.applescript "${GSX_HOME}/scripts/"
chmod +x "${GSX_HOME}/gsx"

# Update the script to use installed location
sed -i '' "s|GSX_ROOT=\"\${0:A:h:h}\"|GSX_ROOT=\"${GSX_HOME}\"|" "${GSX_HOME}/gsx"

# Create symlink
ln -sf "${GSX_HOME}/gsx" "${INSTALL_DIR}/gsx"

echo ""

# Add to PATH if needed
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  ZSHRC="${HOME}/.zshrc"
  PATH_LINE="export PATH=\"${INSTALL_DIR}:\$PATH\""

  # Check if already in .zshrc
  if ! grep -q "${INSTALL_DIR}" "${ZSHRC}" 2>/dev/null; then
    echo "" >> "${ZSHRC}"
    echo "# gsx" >> "${ZSHRC}"
    echo "${PATH_LINE}" >> "${ZSHRC}"
    echo -e "${GREEN}✓${NC} Added PATH to ~/.zshrc"
  fi

  echo ""
  echo -e "${RED}Restart${NC} your terminal or run: ${BOLD}source ~/.zshrc${NC}"
fi

echo ""
echo -e "${GREEN}✓ gsx installed successfully!${NC}"
echo ""

# Accessibility permission reminder
echo -e "${YELLOW}Important:${NC} gsx needs Accessibility permission to control Ghostty."
echo "Grant it in: System Settings → Privacy & Security → Accessibility"
echo "Add your terminal app (Terminal.app, iTerm, etc.) to the list."
echo ""

# Offer to run setup
printf "Run ${BOLD}gsx setup${NC} now? [Y/n]: "
read -r run_setup

if [[ ! "${run_setup}" =~ ^[Nn]$ ]]; then
  echo ""
  "${GSX_HOME}/gsx" setup

  # Remind about PATH if needed
  if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo -e "${RED}Restart${NC} your terminal or run ${BOLD}source ~/.zshrc${NC} to use ${BOLD}gsx${NC} command"
  fi
else
  echo ""
  echo "Next steps:"
  echo -e "  1. Run ${BOLD}gsx setup${NC} to configure"
  echo -e "  2. Run ${BOLD}gsx${NC} to launch sessions"
  echo ""
  echo -e "More info: ${BLUE}https://github.com/minorole/gsx${NC}"
  echo ""
fi
