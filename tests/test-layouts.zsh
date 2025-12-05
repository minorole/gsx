#!/usr/bin/env zsh
# gsx layout tests
# Run: ./tests/test-layouts.zsh

# Source the layouts lib
SCRIPT_DIR="${0:A:h}"
GSX_ROOT="${SCRIPT_DIR:h}"
source "${GSX_ROOT}/lib/layouts.zsh"

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

# Test: validate_layout
echo ""
echo "=== validate_layout ==="
if validate_layout "2" 2>/dev/null; then
    echo "✓ valid '2'"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ valid '2'"
    TESTS_RUN=$((TESTS_RUN + 1))
fi

if validate_layout "2-2" 2>/dev/null; then
    echo "✓ valid '2-2'"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ valid '2-2'"
    TESTS_RUN=$((TESTS_RUN + 1))
fi

if validate_layout "1-2-3-4" 2>/dev/null; then
    echo "✓ valid '1-2-3-4'"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ valid '1-2-3-4'"
    TESTS_RUN=$((TESTS_RUN + 1))
fi

if ! validate_layout "0-2" 2>/dev/null; then
    echo "✓ invalid '0-2'"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ invalid '0-2' (should be invalid)"
    TESTS_RUN=$((TESTS_RUN + 1))
fi

if ! validate_layout "5-6" 2>/dev/null; then
    echo "✓ invalid '5-6' (>10 panes)"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ invalid '5-6' (should be invalid)"
    TESTS_RUN=$((TESTS_RUN + 1))
fi

if ! validate_layout "1-1-1-1-1" 2>/dev/null; then
    echo "✓ invalid '1-1-1-1-1' (>4 rows)"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ invalid '1-1-1-1-1' (should be invalid)"
    TESTS_RUN=$((TESTS_RUN + 1))
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

# Summary
echo ""
echo "=== Summary ==="
echo "$TESTS_PASSED / $TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
