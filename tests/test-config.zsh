#!/usr/bin/env zsh
# gpane config parser tests
# Run: ./tests/test-config.zsh

set -eu

SCRIPT_DIR="${0:A:h}"
GPANE_ROOT="${SCRIPT_DIR:h}"

TESTS_RUN=0
TESTS_PASSED=0

assert_eq() {
    local name=$1 expected=$2 actual=$3
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "${expected}" == "${actual}" ]]; then
        echo "✓ ${name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ ${name}"
        echo "  expected: ${expected}"
        echo "  actual:   ${actual}"
    fi
}

parse_with_config() {
    local config_body=$1
    local tmp_home
    local old_home=${HOME}

    tmp_home=$(mktemp -d)
    {
        mkdir -p "${tmp_home}/.config/gpane"
        print -r -- "${config_body}" > "${tmp_home}/.config/gpane/config.yaml"

        HOME="${tmp_home}"
        source "${GPANE_ROOT}/lib/config.zsh"
        CONFIG_WARNED_INVALID_CURRENT_WINDOW=false
        parse_config
        print -r -- "HOME=${HOME}"
        print -r -- "PROJECTS_ROOT=${PROJECTS_ROOT}"
        print -r -- "DEFAULT_LAYOUT=${DEFAULT_LAYOUT}"
        print -r -- "TABS_COUNT=${TABS_COUNT}"
        print -r -- "DEFAULT_REUSE_WINDOW=${DEFAULT_REUSE_WINDOW-<unset>}"
        print -r -- "PANE_COMMANDS_COUNT=${#PANE_COMMANDS[@]}"
        print -r -- "PANE_COMMAND_1=${PANE_COMMANDS[1]-}"
        print -r -- "PANE_COMMAND_2=${PANE_COMMANDS[2]-}"
        print -r -- "PANE_COMMAND_3=${PANE_COMMANDS[3]-}"
    } always {
        HOME="${old_home}"
        rm -rf "${tmp_home}"
    }
}

parse_twice_with_config() {
    local config_body=$1
    local tmp_home stderr_file
    local old_home=${HOME}

    tmp_home=$(mktemp -d)
    stderr_file="${tmp_home}/stderr"
    {
        mkdir -p "${tmp_home}/.config/gpane"
        print -r -- "${config_body}" > "${tmp_home}/.config/gpane/config.yaml"

        HOME="${tmp_home}"
        source "${GPANE_ROOT}/lib/config.zsh"
        CONFIG_WARNED_INVALID_CURRENT_WINDOW=false
        parse_config 2> "${stderr_file}"
        parse_config 2>> "${stderr_file}"
        print -r -- "DEFAULT_REUSE_WINDOW=${DEFAULT_REUSE_WINDOW-<unset>}"
        print -r -- "WARNING_COUNT=$(grep -c "invalid current_window" "${stderr_file}" || true)"
    } always {
        HOME="${old_home}"
        rm -rf "${tmp_home}"
    }
}

parsed_value() {
    local output=$1 key=$2
    local line
    while IFS= read -r line; do
        if [[ "${line}" == "${key}="* ]]; then
            print -r -- "${line#*=}"
            return 0
        fi
    done <<< "${output}"
    print -r -- ""
}

assert_current_window() {
    local value=$1 expected=$2
    local output
    output=$(parse_with_config "current_window: ${value}")
    assert_eq "current_window ${value}" "${expected}" "$(parsed_value "${output}" "DEFAULT_REUSE_WINDOW")"
}

echo "=== current_window ==="
assert_current_window "true" "true"
assert_current_window "false" "false"
assert_current_window "yes" "true"
assert_current_window "on" "true"
assert_current_window "1" "true"
assert_current_window "no" "false"
assert_current_window "\"true\"" "true"
assert_current_window "true # reuse the current Ghostty window" "true"
assert_current_window "banana" "false"

output=$(parse_with_config $'current_window: true\ncurrent_window: banana')
assert_eq "invalid repeated current_window resets false" "false" "$(parsed_value "${output}" "DEFAULT_REUSE_WINDOW")"

output=$(parse_twice_with_config "current_window: banana")
assert_eq "invalid current_window warns once across repeated parse_config calls" "1" "$(parsed_value "${output}" "WARNING_COUNT")"
assert_eq "invalid current_window remains false across repeated parse_config calls" "false" "$(parsed_value "${output}" "DEFAULT_REUSE_WINDOW")"

echo ""
echo "=== existing parsing ==="
output=$(parse_with_config $'projects_root: ~/work\ndefault_layout: main-side\ndefault_commands:\n  - npm test\n  - ""\n  - "npm run dev"')
assert_eq "projects_root expands temp HOME" "$(parsed_value "${output}" "HOME")/work" "$(parsed_value "${output}" "PROJECTS_ROOT")"
assert_eq "default_layout parses" "main-side" "$(parsed_value "${output}" "DEFAULT_LAYOUT")"
assert_eq "commands count" "3" "$(parsed_value "${output}" "PANE_COMMANDS_COUNT")"
assert_eq "command 1 parses unquoted" "npm test" "$(parsed_value "${output}" "PANE_COMMAND_1")"
assert_eq "command 2 parses empty command" "" "$(parsed_value "${output}" "PANE_COMMAND_2")"
assert_eq "command 3 parses quoted command" "npm run dev" "$(parsed_value "${output}" "PANE_COMMAND_3")"

echo ""
echo "=== Summary ==="
echo "${TESTS_PASSED} / ${TESTS_RUN} tests passed"

if [[ ${TESTS_PASSED} -eq ${TESTS_RUN} ]]; then
    exit 0
else
    exit 1
fi
