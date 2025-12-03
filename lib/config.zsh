# gsx config parsing
# Handles reading and parsing the YAML config file

CONFIG_DIR="${HOME}/.config/gsx"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# Global config variables (set by parse_config)
PROJECTS_ROOT=""
DEFAULT_LAYOUT="3-col"
CMD_LEFT=""
CMD_MIDDLE=""
CMD_RIGHT=""

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

    # Parse default commands
    if [[ "${in_commands}" == true ]]; then
      if [[ "${line}" =~ ^[[:space:]]+left:[[:space:]]*\"(.*)\"$ ]]; then
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+middle:[[:space:]]*\"(.*)\"$ ]]; then
        CMD_MIDDLE="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+right:[[:space:]]*\"(.*)\"$ ]]; then
        CMD_RIGHT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+top:[[:space:]]*\"(.*)\"$ ]]; then
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+bottom:[[:space:]]*\"(.*)\"$ ]]; then
        CMD_MIDDLE="${match[1]}"
      fi
    fi
  done < "${CONFIG_FILE}"
}

# Parse project-specific overrides (call after parse_config)
parse_project_config() {
  local target_project=$1

  [[ ! -f "${CONFIG_FILE}" ]] && return 1

  local line in_project=false

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    # Found target project section
    if [[ "${line}" =~ ^[[:space:]]{2}${target_project}:[[:space:]]*$ ]]; then
      in_project=true
      continue
    fi

    # Moved to different project
    if [[ "${in_project}" == true && "${line}" =~ ^[[:space:]]{2}[^[:space:]].*:$ && ! "${line}" =~ ^[[:space:]]{4} ]]; then
      break
    fi

    # Parse project settings
    if [[ "${in_project}" == true ]]; then
      if [[ "${line}" =~ ^[[:space:]]+layout:[[:space:]]*(.+)$ ]]; then
        DEFAULT_LAYOUT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+left:[[:space:]]*\"(.*)\"$ ]]; then
        CMD_LEFT="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+middle:[[:space:]]*\"(.*)\"$ ]]; then
        CMD_MIDDLE="${match[1]}"
      elif [[ "${line}" =~ ^[[:space:]]+right:[[:space:]]*\"(.*)\"$ ]]; then
        CMD_RIGHT="${match[1]}"
      fi
    fi
  done < "${CONFIG_FILE}"
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
