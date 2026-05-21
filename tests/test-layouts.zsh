#!/usr/bin/env zsh
# gpane layout tests
# Run: ./tests/test-layouts.zsh

# Source the layouts lib
SCRIPT_DIR="${0:A:h}"
GPANE_ROOT="${SCRIPT_DIR:h}"
source "${GPANE_ROOT}/lib/layouts.zsh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test helper
assert_eq() {
    local name=$1 expected=$2 actual=$3
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $name"
        echo "  expected: $expected"
        echo "  actual:   $actual"
    fi
}

assert_valid_layout() {
    local name=$1 spec=$2
    TESTS_RUN=$((TESTS_RUN + 1))
    if validate_layout "$spec" 2>/dev/null; then
        echo "✓ $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $name"
    fi
}

assert_invalid_layout() {
    local name=$1 spec=$2
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! validate_layout "$spec" 2>/dev/null; then
        echo "✓ $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $name (should be invalid)"
    fi
}

# Test: parse_layout_spec
echo "=== parse_layout_spec ==="
assert_eq "parse '2'" "2" "$(parse_layout_spec '2')"
assert_eq "parse '2-2'" "2 2" "$(parse_layout_spec '2-2')"
assert_eq "parse '1-3'" "1 3" "$(parse_layout_spec '1-3')"
assert_eq "parse '1-2-1'" "1 2 1" "$(parse_layout_spec '1-2-1')"
assert_eq "parse '3-3-3'" "3 3 3" "$(parse_layout_spec '3-3-3')"

# Test: resolve_layout_alias
echo ""
echo "=== resolve_layout_alias ==="
assert_eq "alias 'duo'" "2" "$(resolve_layout_alias 'duo')"
assert_eq "alias 'trio'" "3" "$(resolve_layout_alias 'trio')"
assert_eq "alias 'quad'" "2-2" "$(resolve_layout_alias 'quad')"
assert_eq "alias 'dashboard'" "1-3" "$(resolve_layout_alias 'dashboard')"
assert_eq "alias 'stacked'" "1-1" "$(resolve_layout_alias 'stacked')"
assert_eq "alias 'wide'" "3-1" "$(resolve_layout_alias 'wide')"
assert_eq "alias '3-col'" "3" "$(resolve_layout_alias '3-col')"
assert_eq "alias '2-col'" "2" "$(resolve_layout_alias '2-col')"
assert_eq "alias 'main-bottom'" "1-1" "$(resolve_layout_alias 'main-bottom')"
assert_eq "alias 'main-side'" "1|2" "$(resolve_layout_alias 'main-side')"
assert_eq "alias 'side-main'" "2|1" "$(resolve_layout_alias 'side-main')"
assert_eq "passthrough '1|2'" "1|2" "$(resolve_layout_alias '1|2')"
assert_eq "passthrough '2-2'" "2-2" "$(resolve_layout_alias '2-2')"
assert_eq "passthrough '1-3'" "1-3" "$(resolve_layout_alias '1-3')"

# Test: compute_total_panes
echo ""
echo "=== compute_total_panes ==="
assert_eq "total '2'" "2" "$(compute_total_panes '2')"
assert_eq "total '3'" "3" "$(compute_total_panes '3')"
assert_eq "total '2-2'" "4" "$(compute_total_panes '2-2')"
assert_eq "total '1-3'" "4" "$(compute_total_panes '1-3')"
assert_eq "total '1-2-1'" "4" "$(compute_total_panes '1-2-1')"
assert_eq "total '3-3-3'" "9" "$(compute_total_panes '3-3-3')"
assert_eq "total '5-5'" "10" "$(compute_total_panes '5-5')"
assert_eq "total '1|3'" "4" "$(compute_total_panes '1|3')"
assert_eq "total '3|1'" "4" "$(compute_total_panes '3|1')"
assert_eq "total '2|3|1'" "6" "$(compute_total_panes '2|3|1')"
assert_eq "total '4|3|2|1'" "10" "$(compute_total_panes '4|3|2|1')"

# Test: validate_layout
echo ""
echo "=== validate_layout ==="
assert_valid_layout "valid '2'" "2"
assert_valid_layout "valid '2-2'" "2-2"
assert_valid_layout "valid '1-2-3-4'" "1-2-3-4"
assert_valid_layout "valid '1|2'" "1|2"
assert_valid_layout "valid '2|1'" "2|1"
assert_valid_layout "valid '4|3|2|1'" "4|3|2|1"
assert_invalid_layout "invalid '0-2'" "0-2"
assert_invalid_layout "invalid '5-6' (>10 panes)" "5-6"
assert_invalid_layout "invalid '1-1-1-1-1' (>4 rows)" "1-1-1-1-1"
assert_invalid_layout "invalid '1|1|1|1|1' (>4 columns)" "1|1|1|1|1"
assert_invalid_layout "invalid '5|6' (>10 panes)" "5|6"
assert_invalid_layout "invalid '1-2|1' (mixed delimiters)" "1-2|1"
assert_invalid_layout "invalid '1||2'" "1||2"
assert_invalid_layout "invalid '1|0'" "1|0"

# Test: dry-run validates before computing pane counts
echo ""
echo "=== gpane dry-run validation ==="
TESTS_RUN=$((TESTS_RUN + 1))
tmp_home=$(mktemp -d)
mkdir -p "${tmp_home}/.config/gpane" "${tmp_home}/projects/demo"
{
    echo "projects_root: ${tmp_home}/projects"
    echo "default_layout: 1-2|1"
} > "${tmp_home}/.config/gpane/config.yaml"
dry_run_output=$(HOME="${tmp_home}" "${GPANE_ROOT}/bin/gpane" demo --dry-run 2>&1)
dry_run_status=$?
rm -rf "${tmp_home}"

if (( dry_run_status != 0 )) && [[ "${dry_run_output}" == *"Invalid layout format: 1-2|1"* ]] && [[ "${dry_run_output}" != *"Error: Invalid layout"* ]]; then
    echo "✓ dry-run rejects mixed delimiter layout"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ dry-run rejects mixed delimiter layout"
    echo "  status: ${dry_run_status}"
    echo "  output: ${dry_run_output}"
fi

TESTS_RUN=$((TESTS_RUN + 1))
tmp_home=$(mktemp -d)
mkdir -p "${tmp_home}/.config/gpane" "${tmp_home}/projects/demo"
{
    echo "projects_root: ${tmp_home}/projects"
    echo "default_layout: 1"
    echo "tabs: 11"
} > "${tmp_home}/.config/gpane/config.yaml"
dry_run_output=$(HOME="${tmp_home}" "${GPANE_ROOT}/bin/gpane" demo --dry-run 2>&1)
dry_run_status=$?
rm -rf "${tmp_home}"

if (( dry_run_status != 0 )) && [[ "${dry_run_output}" == *"Error: tabs must be between 1 and 10 (got 11)"* ]]; then
    echo "✓ dry-run rejects tabs greater than 10"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ dry-run rejects tabs greater than 10"
    echo "  status: ${dry_run_status}"
    echo "  output: ${dry_run_output}"
fi

TESTS_RUN=$((TESTS_RUN + 1))
tmp_home=$(mktemp -d)
mkdir -p "${tmp_home}/.config/gpane" "${tmp_home}/projects/demo"
{
    echo "projects_root: ${tmp_home}/projects"
    echo "default_layout: 1"
    echo "current_window: true"
} > "${tmp_home}/.config/gpane/config.yaml"
dry_run_output=$(HOME="${tmp_home}" "${GPANE_ROOT}/bin/gpane" demo --dry-run --new-window 2>&1)
dry_run_status=$?
rm -rf "${tmp_home}"

if (( dry_run_status == 0 )) && [[ "${dry_run_output}" == *"window: new"* ]]; then
    echo "✓ --new-window overrides current_window true"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ --new-window overrides current_window true"
    echo "  status: ${dry_run_status}"
    echo "  output: ${dry_run_output}"
fi

# Test: get_layout_info
echo ""
echo "=== get_layout_info ==="

get_layout_info "duo"
assert_eq "duo pane count" "2" "$LAYOUT_PANE_COUNT"

get_layout_info "quad"
assert_eq "quad pane count" "4" "$LAYOUT_PANE_COUNT"

get_layout_info "2-3-1"
assert_eq "2-3-1 pane count" "6" "$LAYOUT_PANE_COUNT"

get_layout_info "dashboard"
assert_eq "dashboard pane count" "4" "$LAYOUT_PANE_COUNT"

get_layout_info "main-side"
assert_eq "main-side pane count" "3" "$LAYOUT_PANE_COUNT"
assert_eq "main-side labels" "Left (main) Right-top Right-bottom" "${LAYOUT_PANE_LABELS[*]}"

get_layout_info "side-main"
assert_eq "side-main pane count" "3" "$LAYOUT_PANE_COUNT"
assert_eq "side-main labels" "Left-top Left-bottom Right (main)" "${LAYOUT_PANE_LABELS[*]}"

# Summary
echo ""
echo "=== Summary ==="
echo "$TESTS_PASSED / $TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
