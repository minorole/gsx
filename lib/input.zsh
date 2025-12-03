# gsx input handling
# User input with line editing support

# Read user input with line editing support when available
# Usage: prompt_input "Prompt text: " varname
# - Interactive (TTY): uses vared for full line editing (delete, arrows, etc.)
# - Non-interactive (pipe): falls back to read for scripting compatibility
prompt_input() {
  local prompt=$1
  local varname=$2

  if [[ -t 0 ]]; then
    # Interactive: use vared for line editing
    vared -p "${prompt}" "${varname}"
  else
    # Piped/scripted: use read for compatibility
    printf '%s' "${prompt}"
    read -r "${varname}"
  fi
}
