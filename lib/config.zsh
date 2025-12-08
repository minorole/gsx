# gpane config parsing
# Handles reading and parsing the YAML config file
#
# Dual-path config support (v0.2.4+):
# - Existing users: ~/.config/gsx/ (legacy path, kept working)
# - New installs: ~/.config/gpane/ (new path)

# Detect which config directory to use
if [[ -d "${HOME}/.config/gsx" ]]; then
  # Legacy path exists - use it (existing user)
  CONFIG_DIR="${HOME}/.config/gsx"
else
  # New install - use new path
  CONFIG_DIR="${HOME}/.config/gpane"
fi
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# Global config variables (set by parse_config)
PROJECTS_ROOT=""
DEFAULT_LAYOUT="3-col"

# Array of commands in spatial order (left-to-right, top-to-bottom)
typeset -a PANE_COMMANDS

# Parse the main config file
parse_config() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    return 1
  fi

  # Reset to defaults
  PROJECTS_ROOT=""
  DEFAULT_LAYOUT="3-col"
  PANE_COMMANDS=()

  local line in_commands=false

  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Skip comments and empty lines
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Track sections
    if [[ "${line}" =~ ^default_commands: ]]; then
      in_commands=true
      continue
    elif [[ "${line}" =~ ^projects: ]]; then
      in_commands=false
      continue
    elif [[ ! "${line}" =~ ^[[:space:]] ]]; then
      in_commands=false
    fi

    # Parse top-level keys
    if [[ "${line}" =~ ^projects_root:[[:space:]]*(.+)$ ]]; then
      PROJECTS_ROOT="${match[1]}"
      PROJECTS_ROOT="${PROJECTS_ROOT/#\~/${HOME}}"
    elif [[ "${line}" =~ ^default_layout:[[:space:]]*(.+)$ ]]; then
      DEFAULT_LAYOUT="${match[1]}"
    fi

    # Parse default commands (array format: "- value")
    if [[ "${in_commands}" == true ]]; then
      if [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\"(.*)\"$ ]]; then
        PANE_COMMANDS+=("${match[1]}")
      elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\'(.*)\'$ ]]; then
        PANE_COMMANDS+=("${match[1]}")
      elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\"\"$ ]]; then
        PANE_COMMANDS+=("")
      elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]*$ ]]; then
        PANE_COMMANDS+=("")
      elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
        PANE_COMMANDS+=("${match[1]}")
      fi
    fi
  done < "${CONFIG_FILE}"
}

# Parse project-specific overrides (call after parse_config)
parse_project_config() {
  local target_project=$1

  [[ ! -f "${CONFIG_FILE}" ]] && return 1

  # Escape regex metacharacters in project name for safe matching
  local escaped_project="${target_project//\\/\\\\}"
  escaped_project="${escaped_project//./\\.}"
  escaped_project="${escaped_project//\*/\\*}"
  escaped_project="${escaped_project//\[/\\[}"
  escaped_project="${escaped_project//\]/\\]}"
  escaped_project="${escaped_project//^/\\^}"
  escaped_project="${escaped_project//\$/\\\$}"
  escaped_project="${escaped_project//\?/\\?}"
  escaped_project="${escaped_project//+/\\+}"
  escaped_project="${escaped_project//\(/\\(}"
  escaped_project="${escaped_project//\)/\\)}"

  local line in_project=false in_commands=false
  local -a project_commands=()

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    # Found target project section
    if [[ "${line}" =~ ^[[:space:]]{2}${escaped_project}:[[:space:]]*$ ]]; then
      in_project=true
      in_commands=false
      continue
    fi

    # Moved to different project
    if [[ "${in_project}" == true && "${line}" =~ ^[[:space:]]{2}[^[:space:]].*:$ && ! "${line}" =~ ^[[:space:]]{4} ]]; then
      break
    fi

    # Track commands section within project
    if [[ "${in_project}" == true ]]; then
      if [[ "${line}" =~ ^[[:space:]]+commands:[[:space:]]*$ ]]; then
        in_commands=true
        project_commands=()
        continue
      elif [[ "${line}" =~ ^[[:space:]]{4}[^[:space:]-] ]]; then
        # Non-command key at 4-space indent, exit commands section
        in_commands=false
      fi
    fi

    # Parse project settings
    if [[ "${in_project}" == true ]]; then
      if [[ "${line}" =~ ^[[:space:]]+layout:[[:space:]]*(.+)$ ]]; then
        DEFAULT_LAYOUT="${match[1]}"
      # Handle commands array format
      elif [[ "${in_commands}" == true ]]; then
        if [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\"(.*)\"$ ]]; then
          project_commands+=("${match[1]}")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\'(.*)\'$ ]]; then
          project_commands+=("${match[1]}")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\"\"$ ]]; then
          project_commands+=("")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]*$ ]]; then
          project_commands+=("")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
          project_commands+=("${match[1]}")
        fi
      fi
    fi
  done < "${CONFIG_FILE}"

  # Apply project commands if found
  if [[ ${#project_commands[@]} -gt 0 ]]; then
    PANE_COMMANDS=("${project_commands[@]}")
  fi
}

# Check if config exists
config_exists() {
  [[ -f "${CONFIG_FILE}" ]]
}

# Show current config
show_config() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "No config found. Run 'gpane setup' first."
    return 1
  fi

  echo "Config: ${CONFIG_FILE}"
  echo "---"
  cat "${CONFIG_FILE}"
}
