# gsx layout functions
# Handles different pane configurations in Ghostty via AppleScript

# Scripts directory (relative to GSX_ROOT, set in bin/gsx)
SCRIPTS_DIR="${GSX_ROOT}/scripts"

# Run a layout script with progress dots
# Usage: run_layout <script_name> <label> <args...>
run_layout() {
  local script_name=$1
  local label=$2
  shift 2
  local script_path="${SCRIPTS_DIR}/${script_name}.applescript"

  if [[ ! -f "${script_path}" ]]; then
    echo "Error: Layout script not found: ${script_path}" >&2
    return 1
  fi

  local tmpout=$(mktemp)
  local exit_status

  printf "  %s" "${label}"

  # Run osascript in background
  osascript "${script_path}" "$@" > "$tmpout" 2>&1 &
  local pid=$!

  # Show dots while waiting
  while kill -0 $pid 2>/dev/null; do
    printf "."
    sleep 0.5
  done

  wait $pid
  exit_status=$?
  local script_result=$(cat "$tmpout")
  rm -f "$tmpout"

  if [[ $exit_status -eq 0 ]]; then
    echo " ok"
    return 0
  else
    echo " failed"
    echo "Error: Failed to open Ghostty window" >&2
    if [[ "${script_result}" == *"not allowed"* || "${script_result}" == *"assistive"* ]]; then
      echo "" >&2
      echo "This looks like a permissions issue." >&2
      echo "Grant Accessibility permission: System Settings > Privacy & Security > Accessibility" >&2
      echo "Add your terminal app to the list and ensure it's enabled." >&2
    elif [[ -n "${script_result}" ]]; then
      echo "${script_result}" >&2
    fi
    return 1
  fi
}

# Layout: 3-col (left | middle | right)
layout_3col() {
  local label=$1 project_dir=$2 cmd_left=$3 cmd_middle=$4 cmd_right=$5
  run_layout "layout-3col" "${label}" "${project_dir}" "${cmd_left}" "${cmd_middle}" "${cmd_right}"
}

# Layout: 2-col (left | right)
layout_2col() {
  local label=$1 project_dir=$2 cmd_left=$3 cmd_right=$4
  run_layout "layout-2col" "${label}" "${project_dir}" "${cmd_left}" "${cmd_right}"
}

# Layout: main+bottom (top | bottom)
layout_main_bottom() {
  local label=$1 project_dir=$2 cmd_top=$3 cmd_bottom=$4
  run_layout "layout-main-bottom" "${label}" "${project_dir}" "${cmd_top}" "${cmd_bottom}"
}
