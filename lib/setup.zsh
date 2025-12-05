# gsx setup wizard
# Interactive configuration for first-time users

setup_wizard() {
  echo ""
  echo "gsx setup"
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

  # Projects root - scan for common directories
  local -a common_dirs=("Projects" "Developer" "Code" "dev" "code" "repos" "Sites" "workspace" "Documents" "Downloads")
  local -a found_dirs=()
  local dir

  for dir in "${common_dirs[@]}"; do
    [[ -d "${HOME}/${dir}" ]] && found_dirs+=("${HOME}/${dir}")
  done

  local projects_root=""
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
      projects_root="${found_dirs[1]}"
    elif [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice <= ${#found_dirs[@]} )); then
      projects_root="${found_dirs[choice]}"
    fi
  fi

  # If no selection yet, ask for path
  if [[ -z "${projects_root}" ]]; then
    local default_root="${HOME}/Projects"

    while true; do
      projects_root=""
      prompt_input "Projects folder [${default_root}]: " projects_root
      projects_root="${projects_root:-${default_root}}"
      projects_root="${projects_root/#\~/${HOME}}"

      # Validate: must start with /
      if [[ "${projects_root}" != /* ]]; then
        echo "Invalid path. Must be absolute (start with / or ~)"
        continue
      fi

      # If doesn't exist, confirm creation
      if [[ ! -d "${projects_root}" ]]; then
        local confirm=""
        prompt_input "Create '${projects_root}'? [Y/n]: " confirm
        if [[ "${confirm}" =~ ^[Nn]$ ]]; then
          continue
        fi
        if ! mkdir -p "${projects_root}" 2>&1; then
          echo "Try a different path."
          continue
        fi
        echo "Created."
      fi

      break
    done
  fi

  echo ""

  # Layout selection
  echo "Layouts:"
  echo "  1) duo        Two panes side-by-side    [1|2]"
  echo "  2) trio       Three panes side-by-side  [1|2|3]"
  echo "  3) stacked    Two panes vertically      [1] / [2]"
  echo "  4) quad       2x2 grid                  [1|2] / [3|4]"
  echo "  5) dashboard  1 main + 3 below          [  1  ] / [2|3|4]"
  echo "  6) wide       3 top + 1 bottom          [1|2|3] / [  4  ]"
  echo "  7) custom     Enter your own (e.g. 2-3, 1-2-1)"
  echo ""
  local layout_choice=""
  prompt_input "Default layout [1]: " layout_choice

  local default_layout
  case "${layout_choice}" in
    1|"") default_layout="duo" ;;
    2) default_layout="trio" ;;
    3) default_layout="stacked" ;;
    4) default_layout="quad" ;;
    5) default_layout="dashboard" ;;
    6) default_layout="wide" ;;
    7)
      echo ""
      echo "Custom layout: N-M-O (panes per row, max 10 panes, max 4 rows)"
      echo "Examples: 2-2 (4 panes), 1-3 (4 panes), 2-3-1 (6 panes), 5-5 (10 panes)"
      local custom_layout=""
      prompt_input "Layout: " custom_layout
      if validate_layout "${custom_layout}" 2>/dev/null; then
        default_layout="${custom_layout}"
      else
        echo "Invalid layout. Using 'duo' instead."
        default_layout="duo"
      fi
      ;;
    *) default_layout="duo" ;;
  esac

  # Calculate number of panes for this layout
  get_layout_info "${default_layout}"
  local num_panes=$LAYOUT_PANE_COUNT
  local -a pane_labels=("${LAYOUT_PANE_LABELS[@]}")

  echo ""
  echo "Commands for each pane (Enter = empty shell)"
  echo "Examples: claude, aider, npm run dev, clear && claude"
  echo ""

  local -a commands=()
  local i=1
  while (( i <= num_panes )); do
    local cmd=""
    prompt_input "  ${pane_labels[i]}: " cmd
    commands+=("${cmd}")
    i=$((i + 1))
  done

  # Show summary and confirm
  echo ""
  echo "Summary:"
  echo "  Folder: ${projects_root}"
  echo "  Layout: ${default_layout}"
  echo "  Commands:"
  i=1
  while (( i <= num_panes )); do
    echo "    ${pane_labels[i]}: ${commands[i]:-<empty>}"
    i=$((i + 1))
  done
  echo ""
  local save_confirm=""
  prompt_input "Save this config? [Y/n]: " save_confirm

  if [[ "${save_confirm}" =~ ^[Nn]$ ]]; then
    echo ""
    echo "Setup cancelled. Run 'gsx setup' to try again."
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
  while (( i <= num_panes )); do
    commands_yaml="${commands_yaml}  - \"${commands[i]}\"\n"
    i=$((i + 1))
  done

  cat > "${CONFIG_FILE}" <<EOF
# gsx config - edit or run 'gsx setup' again
projects_root: ${projects_root}
default_layout: ${default_layout}

default_commands:
$(echo -e "${commands_yaml}")
# Per-project overrides (uncomment and edit):
projects:
#   myproject:
#     layout: quad
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
  echo "  gsx              # Pick a project"
  echo "  gsx <project>    # Open specific project"
  echo "  gsx list         # List projects"
  echo ""
}

# Setup per-project override
setup_project() {
  local project_name=$1

  if ! config_exists; then
    echo "Run 'gsx setup' first."
    exit 1
  fi

  echo ""
  echo "Configure: ${project_name}"
  echo "=========================="
  echo "(Enter = keep default)"
  echo ""

  # Layout
  echo "Layout:"
  echo "  1) duo        2) trio       3) stacked"
  echo "  4) quad       5) dashboard  6) wide"
  echo "  7) custom"
  local layout_choice=""
  prompt_input "Choice [keep default]: " layout_choice

  local project_layout=""
  case "${layout_choice}" in
    1) project_layout="duo" ;;
    2) project_layout="trio" ;;
    3) project_layout="stacked" ;;
    4) project_layout="quad" ;;
    5) project_layout="dashboard" ;;
    6) project_layout="wide" ;;
    7)
      echo "Custom: N-M-O (max 10 panes, max 4 rows)"
      local custom_layout=""
      prompt_input "Layout: " custom_layout
      if validate_layout "${custom_layout}" 2>/dev/null; then
        project_layout="${custom_layout}"
      else
        echo "Invalid layout. Skipping layout override."
      fi
      ;;
  esac

  # Calculate panes for selected layout (or use default's pane count)
  local -a pane_labels=()
  local num_panes=0

  if [[ -n "${project_layout}" ]]; then
    get_layout_info "${project_layout}"
    num_panes=$LAYOUT_PANE_COUNT
    pane_labels=("${LAYOUT_PANE_LABELS[@]}")
  fi

  # Commands
  echo ""
  local -a commands=()
  local has_commands=false

  if [[ ${num_panes} -gt 0 ]]; then
    echo "Commands (Enter = keep default):"
    local i=1
    while (( i <= num_panes )); do
      local cmd=""
      prompt_input "  ${pane_labels[i]}: " cmd
      commands+=("${cmd}")
      [[ -n "${cmd}" ]] && has_commands=true
      i=$((i + 1))
    done
  else
    echo "Commands (Enter = keep default, applies to default layout):"
    for label in "Pane 1" "Pane 2" "Pane 3" "Pane 4"; do
      local cmd=""
      prompt_input "  ${label}: " cmd
      [[ -z "${cmd}" ]] && break
      commands+=("${cmd}")
      has_commands=true
    done
  fi

  # Append to config
  if ! {
    echo ""
    echo "  ${project_name}:"
    [[ -n "${project_layout}" ]] && echo "    layout: ${project_layout}"
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
