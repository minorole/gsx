# gpane shared prompt functions
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
    echo "How many sections per tab?"
    echo ""
    echo "  1) duo        Two sections side-by-side    [1|2]"
    echo "  2) trio       Three sections              [1|2|3]"
    echo "  3) stacked    Two sections vertically      [1] / [2]"
    echo "  4) quad       2x2 grid                     [1|2] / [3|4]"
    echo "  5) dashboard  1 main + 3 below             [  1  ] / [2|3|4]"
    echo "  6) wide       3 top + 1 bottom             [1|2|3] / [  4  ]"
    echo "  7) custom     Enter your own (e.g. 2-3, 1-2-1)"
  else
    echo "Sections per tab:"
    echo "  1) duo        2) trio       3) stacked"
    echo "  4) quad       5) dashboard  6) wide"
    echo "  7) custom"
  fi
  echo ""
}

# Prompt for layout choice and resolve it
# Usage: prompt_layout_choice [default_choice]
#   default_choice: what to use if user presses Enter (default: "1")
#                   use "" to allow empty selection (keep current)
#
# Sets globals:
#   SELECTED_LAYOUT - the layout name/spec (e.g., "duo", "2-3"), empty if keeping default
#   SELECTED_LAYOUT_VALID - true if selection was valid, false if invalid input
prompt_layout_choice() {
  local default_choice="${1:-1}"
  local layout_choice=""

  prompt_input "Choice [${default_choice:-keep default}]: " layout_choice
  layout_choice="${layout_choice:-${default_choice}}"

  SELECTED_LAYOUT=""
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
      echo "Custom layout: N-M-O (sections per row, max 10 sections, max 4 rows)"
      echo "Examples: 2-2 (4 sections), 1-3 (4 sections), 2-3-1 (6 sections)"
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
# Tabs Prompt
# =============================================================================

# Prompt for tabs choice
# Usage: prompt_tabs_choice
#
# Sets global:
#   SELECTED_TABS_COUNT - number of tabs (1 = no tabs, 2-10 = multiple tabs)
prompt_tabs_choice() {
  SELECTED_TABS_COUNT=1

  local want_tabs=""
  prompt_input "Do you want multiple tabs? [y/N]: " want_tabs

  if [[ "${want_tabs}" =~ ^[Yy]$ ]]; then
    local tabs_input=""
    while true; do
      prompt_input "How many tabs? [2-10, default 3]: " tabs_input
      tabs_input="${tabs_input:-3}"
      if [[ "${tabs_input}" =~ ^[0-9]+$ ]] && (( tabs_input >= 2 && tabs_input <= 10 )); then
        SELECTED_TABS_COUNT="${tabs_input}"
        break
      fi
      echo "Enter a number between 2 and 10."
    done
  fi
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

# Get pane count and labels for a layout, with optional tab count
# Usage: get_layout_info_for_prompts <layout> [num_tabs]
#
# Sets globals:
#   PROMPT_PANE_COUNT - total number of command slots
#   PROMPT_PANE_LABELS - array of labels
#   PROMPT_UNIT - "section" (beginner-friendly)
get_layout_info_for_prompts() {
  local layout=$1
  local num_tabs="${2:-1}"

  PROMPT_PANE_COUNT=0
  PROMPT_PANE_LABELS=()
  PROMPT_UNIT="section"

  # Get base layout info
  get_layout_info "${layout}"
  local panes_per_tab=$LAYOUT_PANE_COUNT
  local -a base_labels=("${LAYOUT_PANE_LABELS[@]}")

  if (( num_tabs > 1 )); then
    # Hybrid mode: tabs × panes
    PROMPT_PANE_COUNT=$((num_tabs * panes_per_tab))
    local t=1
    while (( t <= num_tabs )); do
      local p=1
      while (( p <= panes_per_tab )); do
        PROMPT_PANE_LABELS+=("Tab ${t} - ${base_labels[$p]}")
        p=$((p + 1))
      done
      t=$((t + 1))
    done
  else
    # Single window mode
    PROMPT_PANE_COUNT=$panes_per_tab
    PROMPT_PANE_LABELS=("${base_labels[@]}")
  fi
}
