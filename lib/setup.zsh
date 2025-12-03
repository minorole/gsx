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
  echo "  1) 3-col      Three panes: left | middle | right"
  echo "  2) 2-col      Two panes: left | right"
  echo "  3) main+bottom  Top pane + bottom bar"
  echo ""
  local layout_choice=""
  prompt_input "Default layout [1]: " layout_choice

  local default_layout
  case "${layout_choice}" in
    2) default_layout="2-col" ;;
    3) default_layout="main+bottom" ;;
    *) default_layout="3-col" ;;
  esac

  echo ""
  echo "Commands for each pane (Enter = empty shell)"
  echo "Examples: claude, aider, npm run dev, clear && claude"
  echo ""

  local cmd_left="" cmd_middle="" cmd_right=""

  case "${default_layout}" in
    3-col)
      prompt_input "  Left pane: " cmd_left
      prompt_input "  Middle pane: " cmd_middle
      prompt_input "  Right pane: " cmd_right
      ;;
    2-col)
      prompt_input "  Left pane: " cmd_left
      prompt_input "  Right pane: " cmd_right
      ;;
    main+bottom)
      prompt_input "  Top pane: " cmd_left
      prompt_input "  Bottom pane: " cmd_middle
      ;;
  esac

  # Show summary and confirm
  echo ""
  echo "Summary:"
  echo "  Folder: ${projects_root}"
  echo "  Layout: ${default_layout}"
  echo "  Commands:"
  case "${default_layout}" in
    3-col)
      echo "    Left:   ${cmd_left:-<empty>}"
      echo "    Middle: ${cmd_middle:-<empty>}"
      echo "    Right:  ${cmd_right:-<empty>}"
      ;;
    2-col)
      echo "    Left:  ${cmd_left:-<empty>}"
      echo "    Right: ${cmd_right:-<empty>}"
      ;;
    main+bottom)
      echo "    Top:    ${cmd_left:-<empty>}"
      echo "    Bottom: ${cmd_middle:-<empty>}"
      ;;
  esac
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

  cat > "${CONFIG_FILE}" <<EOF
# gsx config - edit or run 'gsx setup' again
projects_root: ${projects_root}
default_layout: ${default_layout}

default_commands:
  left: "${cmd_left}"
  middle: "${cmd_middle}"
  right: "${cmd_right}"

# Per-project overrides:
# projects:
#   myproject:
#     layout: 2-col
#     commands:
#       left: "npm run dev"
#       right: ""
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
  echo "Layout: 1) 3-col  2) 2-col  3) main+bottom"
  local layout_choice=""
  prompt_input "Choice [keep default]: " layout_choice

  local project_layout=""
  case "${layout_choice}" in
    1) project_layout="3-col" ;;
    2) project_layout="2-col" ;;
    3) project_layout="main+bottom" ;;
  esac

  # Commands
  echo ""
  echo "Commands ('none' = empty shell):"
  local cmd_left="" cmd_middle="" cmd_right=""

  prompt_input "  Left: " cmd_left
  prompt_input "  Middle: " cmd_middle
  prompt_input "  Right: " cmd_right

  # Append to config
  if ! {
    echo ""
    echo "  ${project_name}:"
    [[ -n "${project_layout}" ]] && echo "    layout: ${project_layout}"
    if [[ -n "${cmd_left}" || -n "${cmd_middle}" || -n "${cmd_right}" ]]; then
      echo "    commands:"
      [[ -n "${cmd_left}" ]] && echo "      left: \"${cmd_left}\""
      [[ -n "${cmd_middle}" ]] && echo "      middle: \"${cmd_middle}\""
      [[ -n "${cmd_right}" ]] && echo "      right: \"${cmd_right}\""
    fi
  } >> "${CONFIG_FILE}" 2>&1; then
    echo "Failed to update config file."
    return 1
  fi

  echo ""
  echo "Project '${project_name}' configured."
  echo ""
}
