# gsx layout functions
# Handles different pane configurations in Ghostty via AppleScript

# Scripts directory (relative to GSX_ROOT, set in bin/gsx)
SCRIPTS_DIR="${GSX_ROOT}/scripts"

# =============================================================================
# Layout Aliases & Resolution
# =============================================================================

# Layout alias map: name -> row notation
typeset -A LAYOUT_ALIASES
LAYOUT_ALIASES[duo]="2"
LAYOUT_ALIASES[trio]="3"
LAYOUT_ALIASES[2-col]="2"
LAYOUT_ALIASES[3-col]="3"
LAYOUT_ALIASES[main-bottom]="1-1"
LAYOUT_ALIASES[stacked]="1-1"
LAYOUT_ALIASES[quad]="2-2"
LAYOUT_ALIASES[dashboard]="1-3"
LAYOUT_ALIASES[wide]="3-1"

# Resolve layout alias to row notation
# Usage: resolve_layout_alias "quad" -> "2-2"
resolve_layout_alias() {
    local layout=$1
    # Check if key exists in associative array (safe with set -u)
    if (( ${+LAYOUT_ALIASES[$layout]} )); then
        echo "${LAYOUT_ALIASES[$layout]}"
    else
        echo "$layout"
    fi
}

# =============================================================================
# Layout Parsing & Validation
# =============================================================================

# Parse layout spec "2-2" -> "2 2" (space-separated)
parse_layout_spec() {
    local spec=$1
    echo "${spec//-/ }"
}

# Compute total panes from layout spec
compute_total_panes() {
    local spec=$1
    local -a rows=(${(s:-:)spec})
    local total=0
    for r in "${rows[@]}"; do
        total=$((total + r))
    done
    echo $total
}

# Validate layout spec
# Returns 0 if valid, 1 if invalid (with error message to stderr)
validate_layout() {
    local spec=$1

    # Must match pattern: digits separated by dashes
    if [[ ! "$spec" =~ ^[1-9](-[1-9])*$ ]]; then
        echo "Invalid layout format: $spec (must be like '2', '2-2', '1-3')" >&2
        return 1
    fi

    local -a rows=(${(s:-:)spec})
    local num_rows=${#rows[@]}
    local total=0

    # Max 4 rows
    if ((num_rows > 4)); then
        echo "Too many rows: $num_rows (max 4)" >&2
        return 1
    fi

    # Count total panes
    for r in "${rows[@]}"; do
        total=$((total + r))
    done

    # Max 10 panes
    if ((total > 10)); then
        echo "Too many panes: $total (max 10)" >&2
        return 1
    fi

    return 0
}

# Get pane count and labels for a layout
# Usage: get_layout_info "quad" -> sets LAYOUT_PANE_COUNT and LAYOUT_PANE_LABELS
# Returns via global variables to avoid subshell issues with arrays
get_layout_info() {
    local layout=$1

    # Resolve alias first
    local resolved
    resolved=$(resolve_layout_alias "$layout")

    LAYOUT_PANE_COUNT=0
    LAYOUT_PANE_LABELS=()

    case "${resolved}" in
        2)   LAYOUT_PANE_COUNT=2; LAYOUT_PANE_LABELS=("Left" "Right") ;;
        3)   LAYOUT_PANE_COUNT=3; LAYOUT_PANE_LABELS=("Left" "Middle" "Right") ;;
        1-1) LAYOUT_PANE_COUNT=2; LAYOUT_PANE_LABELS=("Top" "Bottom") ;;
        2-2) LAYOUT_PANE_COUNT=4; LAYOUT_PANE_LABELS=("Top-left" "Top-right" "Bottom-left" "Bottom-right") ;;
        1-3) LAYOUT_PANE_COUNT=4; LAYOUT_PANE_LABELS=("Top (main)" "Bottom-left" "Bottom-middle" "Bottom-right") ;;
        3-1) LAYOUT_PANE_COUNT=4; LAYOUT_PANE_LABELS=("Top-left" "Top-middle" "Top-right" "Bottom (main)") ;;
        *)
            # Custom layout - count panes from spec
            LAYOUT_PANE_COUNT=$(compute_total_panes "$resolved")
            local i=1
            while (( i <= LAYOUT_PANE_COUNT )); do
                LAYOUT_PANE_LABELS+=("Pane ${i}")
                i=$((i + 1))
            done
            ;;
    esac
}

# =============================================================================
# Dynamic Layout (main entry point)
# =============================================================================

# Layout: dynamic (any row-based configuration)
# Commands are passed in spatial order (left-to-right, top-to-bottom)
# AppleScript types commands inline during Phase 2
layout_dynamic() {
    local project_name=$1
    local project_dir=$2
    local layout_spec=$3
    shift 3
    local -a spatial_cmds=("$@")

    local label="[${project_name}]"

    # Validate layout
    if ! validate_layout "$layout_spec"; then
        echo "Error: Invalid layout '$layout_spec'" >&2
        return 1
    fi

    # Pass commands directly in spatial order - AppleScript handles them inline
    run_layout "layout-dynamic" "${label}" "${project_dir}" "${layout_spec}" "${spatial_cmds[@]}"
}

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
