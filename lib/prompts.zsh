# gsx shared prompt functions
# Centralized UI prompts for setup wizard and project configuration

# =============================================================================
# Layout Menu & Selection
# =============================================================================

# Display layout menu
# Usage: show_layout_menu [style]
#   style: "full" (default) - detailed with ASCII diagrams
#          "compact" - single line per option
show_layout_menu() {
  local style="${1:-full}"

  local dim=$'\e[2m'
  local cyan=$'\e[36m'
  local reset=$'\e[0m'

  if [[ "${style}" == "full" ]]; then
    echo "Layouts:"
    echo "  ${dim}── Panes (split window) ──${reset}"
    echo "  1) duo        Two panes side-by-side    [1|2]"
    echo "  2) trio       Three panes side-by-side  [1|2|3]"
    echo "  3) stacked    Two panes vertically      [1] / [2]"
    echo "  4) quad       2x2 grid                  [1|2] / [3|4]"
    echo "  5) dashboard  1 main + 3 below          [  1  ] / [2|3|4]"
    echo "  6) wide       3 top + 1 bottom          [1|2|3] / [  4  ]"
    echo "  7) custom     Enter your own (e.g. 2-3, 1-2-1)"
    echo ""
    echo "  ${cyan}── Tabs (separate tabs) ──${reset}"
    echo "  ${cyan}8) tabs       One tab per command (up to 10)${reset}"
  else
    echo "Layout:"
    echo "  ${dim}── Panes ──${reset}"
    echo "  1) duo        2) trio       3) stacked"
    echo "  4) quad       5) dashboard  6) wide"
    echo "  7) custom"
    echo "  ${cyan}── Tabs ──${reset}"
    echo "  ${cyan}8) tabs${reset}"
  fi
  echo ""
}

# Prompt for layout choice and resolve it
# Usage: prompt_layout_choice [default_choice]
#   default_choice: what to use if user presses Enter (default: "1")
#                   use "" to allow empty selection (keep current)
#
# Sets globals:
#   SELECTED_LAYOUT - the layout name/spec (e.g., "duo", "tabs", "2-3"), empty if keeping default
#   SELECTED_NUM_TABS - number of tabs if tabs layout (0 otherwise)
#   SELECTED_LAYOUT_VALID - true if selection was valid, false if invalid input
prompt_layout_choice() {
  local default_choice="${1:-1}"
  local layout_choice=""

  prompt_input "Choice [${default_choice:-keep default}]: " layout_choice
  layout_choice="${layout_choice:-${default_choice}}"

  SELECTED_LAYOUT=""
  SELECTED_NUM_TABS=0
  SELECTED_LAYOUT_VALID=true

  case "${layout_choice}" in
    1) SELECTED_LAYOUT="duo" ;;
    2) SELECTED_LAYOUT="trio" ;;
    3) SELECTED_LAYOUT="stacked" ;;
    4) SELECTED_LAYOUT="quad" ;;
    5) SELECTED_LAYOUT="dashboard" ;;
    6) SELECTED_LAYOUT="wide" ;;
    7)
      echo ""
      echo "Custom layout: N-M-O (panes per row, max 10 panes, max 4 rows)"
      echo "Examples: 2-2 (4 panes), 1-3 (4 panes), 2-3-1 (6 panes)"
      local custom_layout=""
      while true; do
        prompt_input "Layout: " custom_layout
        if validate_layout "${custom_layout}" 2>/dev/null; then
          SELECTED_LAYOUT="${custom_layout}"
          break
        fi
        echo "Invalid layout. Try again (e.g., 2-2, 1-3, 2-3-1)"
      done
      ;;
    8)
      SELECTED_LAYOUT="tabs"
      echo ""
      local tabs_input=""
      while true; do
        prompt_input "How many tabs? [2-10, default 4]: " tabs_input
        if [[ -z "${tabs_input}" ]]; then
          SELECTED_NUM_TABS=4
          break
        elif [[ "${tabs_input}" =~ ^[0-9]+$ ]] && (( tabs_input >= 2 && tabs_input <= 10 )); then
          SELECTED_NUM_TABS="${tabs_input}"
          break
        fi
        echo "Invalid number. Enter 2-10 or press Enter for default."
      done
      ;;
    "")
      # Empty input with no default - valid, means keep current
      SELECTED_LAYOUT=""
      ;;
    *)
      # Invalid menu choice - caller should re-prompt
      echo "Invalid choice."
      SELECTED_LAYOUT=""
      SELECTED_LAYOUT_VALID=false
      ;;
  esac
}

# =============================================================================
# Command Prompting
# =============================================================================

# Prompt for commands for each pane/tab
# Usage: prompt_pane_commands <num_panes> <label1> <label2> ...
#
# Sets global:
#   PROMPTED_COMMANDS - array of commands entered by user
prompt_pane_commands() {
  local num_panes=$1
  shift
  local -a labels=("$@")

  PROMPTED_COMMANDS=()

  local i=1
  while (( i <= num_panes )); do
    local label="${labels[$i]:-Pane ${i}}"
    local cmd=""
    prompt_input "  ${label}: " cmd
    PROMPTED_COMMANDS+=("${cmd}")
    i=$((i + 1))
  done
}

# =============================================================================
# Layout Info Helpers
# =============================================================================

# Get pane count and labels for a layout, with optional tab count override
# Usage: get_layout_info_for_prompts <layout> [num_tabs]
#
# Sets globals:
#   PROMPT_PANE_COUNT - number of panes/tabs
#   PROMPT_PANE_LABELS - array of labels
#   PROMPT_UNIT - "pane" or "tab"
get_layout_info_for_prompts() {
  local layout=$1
  local num_tabs="${2:-0}"

  PROMPT_PANE_COUNT=0
  PROMPT_PANE_LABELS=()
  PROMPT_UNIT="pane"

  if [[ "${layout}" == "tabs" ]]; then
    PROMPT_UNIT="tab"
    if (( num_tabs > 0 )); then
      PROMPT_PANE_COUNT="${num_tabs}"
    else
      PROMPT_PANE_COUNT=4  # default
    fi
    local i=1
    while (( i <= PROMPT_PANE_COUNT )); do
      PROMPT_PANE_LABELS+=("Tab ${i}")
      i=$((i + 1))
    done
  else
    get_layout_info "${layout}"
    PROMPT_PANE_COUNT=$LAYOUT_PANE_COUNT
    PROMPT_PANE_LABELS=("${LAYOUT_PANE_LABELS[@]}")
  fi
}
