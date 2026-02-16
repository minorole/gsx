# gpane layout functions
# Handles different pane configurations in Ghostty via AppleScript

# Scripts directory (relative to GPANE_ROOT, set in bin/gpane)
SCRIPTS_DIR="${GPANE_ROOT}/scripts"

# =============================================================================
# Layout Aliases & Resolution
# =============================================================================

# Layout alias map: name -> row notation (or special keyword)
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

# Prepend cd to project directory for every pane command
# Empty commands become "cd <dir>"
# Non-empty commands become "cd <dir> && <cmd>"
prepend_cd_to_commands() {
    local project_dir=$1
    shift
    local -a cmds=("$@")
    local -a result=()
    for cmd in "${cmds[@]}"; do
        if [[ -z "$cmd" ]]; then
            result+=("cd ${(q)project_dir}")
        else
            result+=("cd ${(q)project_dir} && ${cmd}")
        fi
    done
    PREPARED_COMMANDS=("${result[@]}")
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
# Hybrid Layout (tabs + panes)
# =============================================================================

# Layout: hybrid (multiple tabs, each with pane splits)
# Commands fill tabs in order: tab1-pane1, tab1-pane2, ..., tab2-pane1, ...
layout_hybrid() {
    local project_name=$1
    local project_dir=$2
    local layout_spec=$3
    local tabs_count=$4
    local reuse_window=$5
    shift 5
    local -a cmds=("$@")

    local label="[${project_name}]"

    # Validate layout
    if ! validate_layout "$layout_spec"; then
        echo "Error: Invalid layout '$layout_spec'" >&2
        return 1
    fi

    # Validate tabs count
    if (( tabs_count < 1 || tabs_count > 10 )); then
        echo "Error: tabs must be between 1 and 10 (got $tabs_count)" >&2
        return 1
    fi

    # Pad commands to fill all pane slots across all tabs
    local panes_per_tab
    panes_per_tab=$(compute_total_panes "$layout_spec")
    local total_slots=$((panes_per_tab * tabs_count))
    while (( ${#cmds[@]} < total_slots )); do
        cmds+=("")
    done

    prepend_cd_to_commands "${project_dir}" "${cmds[@]}"
    run_layout "layout-hybrid" "${label}" "${reuse_window}" "${project_dir}" "${layout_spec}" "${tabs_count}" "${PREPARED_COMMANDS[@]}"
}

# Check for deprecated layout: tabs syntax
# Returns 1 and shows migration message if deprecated syntax detected
check_deprecated_tabs_layout() {
    local layout=$1
    if [[ "$layout" == "tabs" ]]; then
        echo "" >&2
        echo "Error: 'layout: tabs' is deprecated." >&2
        echo "" >&2
        echo "Update your config to use the new tabs + panes system:" >&2
        echo "  layout: 1        # panes per tab (or duo, trio, quad, etc.)" >&2
        echo "  tabs: N          # number of tabs (2-10)" >&2
        echo "" >&2
        echo "Example - 3 tabs, each with 2 panes:" >&2
        echo "  layout: duo" >&2
        echo "  tabs: 3" >&2
        echo "" >&2
        return 1
    fi
    return 0
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
    local reuse_window=$4
    shift 4
    local -a spatial_cmds=("$@")

    local label="[${project_name}]"

    # Validate layout
    if ! validate_layout "$layout_spec"; then
        echo "Error: Invalid layout '$layout_spec'" >&2
        return 1
    fi

    # Pad commands to fill all pane slots
    local total_panes
    total_panes=$(compute_total_panes "$layout_spec")
    while (( ${#spatial_cmds[@]} < total_panes )); do
        spatial_cmds+=("")
    done

    prepend_cd_to_commands "${project_dir}" "${spatial_cmds[@]}"
    run_layout "layout-dynamic" "${label}" "${reuse_window}" "${project_dir}" "${layout_spec}" "${PREPARED_COMMANDS[@]}"
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

  exit_status=0
  wait $pid || exit_status=$?
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
