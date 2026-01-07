# gpane setup wizard
# Interactive configuration for first-time users

# =============================================================================
# Projects Root Selection (used only in setup_wizard)
# =============================================================================

# Prompt for projects root directory
# Sets global: SELECTED_PROJECTS_ROOT
prompt_projects_root() {
  SELECTED_PROJECTS_ROOT=""

  # Scan for common directories
  local -a common_dirs=("Projects" "Developer" "Code" "dev" "code" "repos" "Sites" "workspace" "Documents" "Downloads")
  local -a found_dirs=()
  local dir

  for dir in "${common_dirs[@]}"; do
    [[ -d "${HOME}/${dir}" ]] && found_dirs+=("${HOME}/${dir}")
  done

  local choice

  if (( ${#found_dirs[@]} > 0 )); then
    echo "Possible project folders:"
    local -i i=1
    for dir in "${found_dirs[@]}"; do
      echo "  ${i}) ${dir}"
      i=$((i + 1))
    done
    echo "  ${i}) Other (enter path)"
    echo ""
    choice=""
    prompt_input "Select [1]: " choice

    if [[ -z "${choice}" || "${choice}" == "1" ]]; then
      SELECTED_PROJECTS_ROOT="${found_dirs[1]}"
    elif [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice <= ${#found_dirs[@]} )); then
      SELECTED_PROJECTS_ROOT="${found_dirs[choice]}"
    fi
  fi

  # If no selection yet, ask for path
  if [[ -z "${SELECTED_PROJECTS_ROOT}" ]]; then
    local default_root="${HOME}/Projects"

    while true; do
      SELECTED_PROJECTS_ROOT=""
      prompt_input "Projects folder [${default_root}]: " SELECTED_PROJECTS_ROOT
      SELECTED_PROJECTS_ROOT="${SELECTED_PROJECTS_ROOT:-${default_root}}"
      SELECTED_PROJECTS_ROOT="${SELECTED_PROJECTS_ROOT/#\~/${HOME}}"

      # Validate: must start with /
      if [[ "${SELECTED_PROJECTS_ROOT}" != /* ]]; then
        echo "Invalid path. Must be absolute (start with / or ~)"
        continue
      fi

      # If doesn't exist, confirm creation
      if [[ ! -d "${SELECTED_PROJECTS_ROOT}" ]]; then
        local confirm=""
        prompt_input "Create '${SELECTED_PROJECTS_ROOT}'? [Y/n]: " confirm
        if [[ "${confirm}" =~ ^[Nn]$ ]]; then
          continue
        fi
        if ! mkdir -p "${SELECTED_PROJECTS_ROOT}" 2>&1; then
          echo "Try a different path."
          continue
        fi
        echo "Created."
      fi

      break
    done
  fi
}

# =============================================================================
# Setup Wizard
# =============================================================================

setup_wizard() {
  echo ""
  echo "gpane setup"
  echo "============"
  echo ""

  # Warn if config exists
  if [[ -f "${CONFIG_FILE}" ]]; then
    echo "Existing config found: ${CONFIG_FILE}"
    echo ""
    local overwrite=""
    prompt_input "Overwrite? This will reset all settings. [y/N]: " overwrite
    if [[ ! "${overwrite}" =~ ^[Yy]$ ]]; then
      echo "Setup cancelled. Config unchanged."
      return 0
    fi
    echo ""
  fi

  # Step 1: Projects root
  prompt_projects_root
  local projects_root="${SELECTED_PROJECTS_ROOT}"
  echo ""

  # Step 2: Tabs selection
  prompt_tabs_choice
  local tabs_count="${SELECTED_TABS_COUNT}"
  echo ""

  # Step 3: Layout selection (sections per tab)
  show_layout_menu "full"
  while true; do
    prompt_layout_choice "1"
    [[ "${SELECTED_LAYOUT_VALID}" == true ]] && break
  done

  local default_layout="${SELECTED_LAYOUT}"

  # Step 4: Get layout info and prompt for commands
  get_layout_info_for_prompts "${default_layout}" "${tabs_count}"

  echo ""
  echo "Commands for each ${PROMPT_UNIT} (Enter = empty shell)"
  echo "Examples: claude, aider, npm run dev, clear && claude"
  echo ""

  prompt_pane_commands "${PROMPT_PANE_COUNT}" "${PROMPT_PANE_LABELS[@]}"
  local -a commands=("${PROMPTED_COMMANDS[@]}")

  # Show summary and confirm
  echo ""
  echo "Summary:"
  echo "  Folder: ${projects_root}"
  if (( tabs_count > 1 )); then
    echo "  Layout: ${default_layout} × ${tabs_count} tabs"
  else
    echo "  Layout: ${default_layout}"
  fi
  echo "  Commands:"
  local i=1
  while (( i <= PROMPT_PANE_COUNT )); do
    echo "    ${PROMPT_PANE_LABELS[i]}: ${commands[i]:-<empty>}"
    i=$((i + 1))
  done
  echo ""
  local save_confirm=""
  prompt_input "Save this config? [Y/n]: " save_confirm

  if [[ "${save_confirm}" =~ ^[Nn]$ ]]; then
    echo ""
    echo "Setup cancelled. Run 'gpane setup' to try again."
    return 0
  fi

  # Write config
  if ! mkdir -p "${CONFIG_DIR}" 2>&1; then
    echo "Failed to create config directory: ${CONFIG_DIR}"
    return 1
  fi

  # Build commands section (always use array format for consistency)
  local commands_yaml=""
  i=1
  while (( i <= PROMPT_PANE_COUNT )); do
    commands_yaml="${commands_yaml}  - \"${commands[i]}\"\n"
    i=$((i + 1))
  done

  # Build tabs line (only include if > 1)
  local tabs_yaml=""
  if (( tabs_count > 1 )); then
    tabs_yaml="tabs: ${tabs_count}"
  fi

  cat > "${CONFIG_FILE}" <<EOF
# gpane config - edit or run 'gpane setup' again
projects_root: ${projects_root}
default_layout: ${default_layout}
${tabs_yaml}

default_commands:
$(echo -e "${commands_yaml}")
# Per-project overrides (uncomment and edit):
projects:
#   myproject:
#     layout: quad
#     tabs: 2
#     commands:
#       - "nvim ."
#       - "npm run dev"
#       - "npm test"
#       - ""
EOF

  if [[ $? -ne 0 ]]; then
    echo "Failed to write config file: ${CONFIG_FILE}"
    return 1
  fi

  echo ""
  echo "Saved: ${CONFIG_FILE}"
  echo ""
  echo "Usage:"
  echo "  gpane              # Pick a project"
  echo "  gpane <project>    # Open specific project"
  echo "  gpane list         # List projects"
  echo ""
}

# =============================================================================
# Per-Project Setup
# =============================================================================

# Setup per-project override
setup_project() {
  local project_name=$1

  if ! config_exists; then
    echo "Run 'gpane setup' first."
    exit 1
  fi

  # Parse existing config to get default layout
  parse_config

  echo ""
  echo "Configure: ${project_name}"
  echo "=========================="
  echo "(Enter = keep default)"
  echo ""

  # Tabs selection
  prompt_tabs_choice
  local project_tabs="${SELECTED_TABS_COUNT}"
  echo ""

  # Layout selection with compact menu
  show_layout_menu "compact"
  while true; do
    prompt_layout_choice ""  # empty default = keep current
    [[ "${SELECTED_LAYOUT_VALID}" == true ]] && break
  done

  local project_layout="${SELECTED_LAYOUT}"

  # Determine which layout to use for command prompts
  local effective_layout
  if [[ -n "${project_layout}" ]]; then
    effective_layout="${project_layout}"
  else
    effective_layout="${DEFAULT_LAYOUT}"
    echo ""
    echo "Using default layout: ${effective_layout}"
  fi

  # Determine effective tabs count
  local effective_tabs="${project_tabs}"
  if (( effective_tabs <= 1 )); then
    effective_tabs="${TABS_COUNT}"  # Use global default
  fi

  # Get layout info for the effective layout and tabs
  get_layout_info_for_prompts "${effective_layout}" "${effective_tabs}"

  # Commands
  echo ""
  echo "Commands (Enter = keep default):"
  prompt_pane_commands "${PROMPT_PANE_COUNT}" "${PROMPT_PANE_LABELS[@]}"

  # Check if any commands were actually entered
  local has_commands=false
  local -a commands=("${PROMPTED_COMMANDS[@]}")
  for cmd in "${commands[@]}"; do
    [[ -n "${cmd}" ]] && has_commands=true && break
  done

  # Append to config
  if ! {
    echo ""
    echo "  ${project_name}:"
    [[ -n "${project_layout}" ]] && echo "    layout: ${project_layout}"
    # Write tabs if different from global default (allows overriding multi-tab to single)
    (( project_tabs != TABS_COUNT )) && echo "    tabs: ${project_tabs}"
    if ${has_commands}; then
      echo "    commands:"
      for cmd in "${commands[@]}"; do
        echo "      - \"${cmd}\""
      done
    fi
  } >> "${CONFIG_FILE}" 2>&1; then
    echo "Failed to update config file."
    return 1
  fi

  echo ""
  echo "Project '${project_name}' configured."
  echo ""
}
