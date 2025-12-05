# gsx config parsing
# Handles reading and parsing the YAML config file

CONFIG_DIR="${HOME}/.config/gsx"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# Global config variables (set by parse_config)
PROJECTS_ROOT=""
DEFAULT_LAYOUT="3-col"

# Legacy variables (for backward compatibility)
CMD_LEFT=""
CMD_MIDDLE=""
CMD_RIGHT=""

# New: array of commands in spatial order (left-to-right, top-to-bottom)
typeset -a PANE_COMMANDS

# Parse the main config file
parse_config() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    return 1
  fi

  # Reset to defaults
  PROJECTS_ROOT=""
  DEFAULT_LAYOUT="3-col"
  CMD_LEFT=""
  CMD_MIDDLE=""
  CMD_RIGHT=""
  PANE_COMMANDS=()

  local line in_commands=false cmd_format=""

  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Skip comments and empty lines
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Track sections
    if [[ "${line}" =~ ^default_commands: ]]; then
      in_commands=true
      cmd_format=""  # Will detect format on first command line
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

    # Parse default commands (supports both formats)
    if [[ "${in_commands}" == true ]]; then
      # NEW FORMAT: array items with "- "
      if [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\"(.*)\"$ ]]; then
        cmd_format="array"
        PANE_COMMANDS+=("${match[1]}")
      elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\'(.*)\'$ ]]; then
        cmd_format="array"
        PANE_COMMANDS+=("${match[1]}")
      elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\"\"$ ]]; then
        cmd_format="array"
        PANE_COMMANDS+=("")
      elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]*$ ]]; then
        # Bare dash means empty string
        cmd_format="array"
        PANE_COMMANDS+=("")
      elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
        # Unquoted value (e.g., "- claude")
        cmd_format="array"
        PANE_COMMANDS+=("${match[1]}")
      # OLD FORMAT: named keys (left, middle, right, top, bottom)
      elif [[ "${line}" =~ ^[[:space:]]+left:[[:space:]]*\"(.*)\"$ ]]; then
        cmd_format="named"
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+left:[[:space:]]*(.+)$ ]]; then
        cmd_format="named"
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+middle:[[:space:]]*\"(.*)\"$ ]]; then
        cmd_format="named"
        CMD_MIDDLE="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+middle:[[:space:]]*(.+)$ ]]; then
        cmd_format="named"
        CMD_MIDDLE="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+right:[[:space:]]*\"(.*)\"$ ]]; then
        cmd_format="named"
        CMD_RIGHT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+right:[[:space:]]*(.+)$ ]]; then
        cmd_format="named"
        CMD_RIGHT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+top:[[:space:]]*\"(.*)\"$ ]]; then
        cmd_format="named"
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+top:[[:space:]]*(.+)$ ]]; then
        cmd_format="named"
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+bottom:[[:space:]]*\"(.*)\"$ ]]; then
        cmd_format="named"
        CMD_MIDDLE="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+bottom:[[:space:]]*(.+)$ ]]; then
        cmd_format="named"
        CMD_MIDDLE="${match[1]}"
      fi
    fi
  done < "${CONFIG_FILE}"

  # If using old format, convert to array
  if [[ "$cmd_format" == "named" ]]; then
    PANE_COMMANDS=("$CMD_LEFT" "$CMD_MIDDLE" "$CMD_RIGHT")
  fi

  # If using new format, also set legacy vars for backward compat
  if [[ "$cmd_format" == "array" && ${#PANE_COMMANDS[@]} -ge 1 ]]; then
    CMD_LEFT="${PANE_COMMANDS[1]:-}"
    [[ ${#PANE_COMMANDS[@]} -ge 2 ]] && CMD_MIDDLE="${PANE_COMMANDS[2]:-}"
    [[ ${#PANE_COMMANDS[@]} -ge 3 ]] && CMD_RIGHT="${PANE_COMMANDS[3]:-}"
  fi
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

  local line in_project=false in_commands=false cmd_format=""
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
          cmd_format="array"
          project_commands+=("${match[1]}")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\'(.*)\'$ ]]; then
          cmd_format="array"
          project_commands+=("${match[1]}")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+\"\"$ ]]; then
          cmd_format="array"
          project_commands+=("")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]*$ ]]; then
          cmd_format="array"
          project_commands+=("")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+([^\"\'[:space:]][^[:space:]]*)$ ]]; then
          # Unquoted value (e.g., "- claude" or "- btop")
          cmd_format="array"
          project_commands+=("${match[1]}")
        elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
          # Fallback: any value after dash
          cmd_format="array"
          project_commands+=("${match[1]}")
        fi
      # Handle legacy named format
      elif [[ "${line}" =~ ^[[:space:]]+left:[[:space:]]*\"(.*)\"$ ]]; then
        cmd_format="named"
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+left:[[:space:]]*(.+)$ ]]; then
        cmd_format="named"
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+middle:[[:space:]]*\"(.*)\"$ ]]; then
        cmd_format="named"
        CMD_MIDDLE="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+middle:[[:space:]]*(.+)$ ]]; then
        cmd_format="named"
        CMD_MIDDLE="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+right:[[:space:]]*\"(.*)\"$ ]]; then
        cmd_format="named"
        CMD_RIGHT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+right:[[:space:]]*(.+)$ ]]; then
        cmd_format="named"
        CMD_RIGHT="${match[1]}"
      fi
    fi
  done < "${CONFIG_FILE}"

  # Apply project commands if found
  if [[ "$cmd_format" == "array" && ${#project_commands[@]} -gt 0 ]]; then
    PANE_COMMANDS=("${project_commands[@]}")
    # Also update legacy vars
    CMD_LEFT="${project_commands[1]:-}"
    [[ ${#project_commands[@]} -ge 2 ]] && CMD_MIDDLE="${project_commands[2]:-}"
    [[ ${#project_commands[@]} -ge 3 ]] && CMD_RIGHT="${project_commands[3]:-}"
  elif [[ "$cmd_format" == "named" ]]; then
    PANE_COMMANDS=("$CMD_LEFT" "$CMD_MIDDLE" "$CMD_RIGHT")
  fi
}

# Check if config exists
config_exists() {
  [[ -f "${CONFIG_FILE}" ]]
}

# Show current config
show_config() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "No config found. Run 'gsx setup' first."
    return 1
  fi

  echo "Config: ${CONFIG_FILE}"
  echo "---"
  cat "${CONFIG_FILE}"
}
