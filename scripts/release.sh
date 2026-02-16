#!/usr/bin/env zsh
# gsx release automation
# Usage: ./scripts/release.sh [patch|minor|major|X.Y.Z]

REPO_ROOT="${0:A:h:h}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo "${BLUE}▸${NC} $*" }
success() { echo "${GREEN}✓${NC} $*" }
error()   { echo "${RED}✗${NC} $*" >&2 }
warn()    { echo "${YELLOW}⚠${NC} $*" }

# --- Help ---
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: ./scripts/release.sh [patch|minor|major|X.Y.Z]"
    echo ""
    echo "Automates: version bump, changelog, commit, tag, push, GitHub release."
    echo "Default: patch"
    exit 0
fi

# --- Version math ---
bump_version() {
    local current=$1 bump_type=$2
    local major minor patch

    major=${current%%.*}
    local rest=${current#*.}
    minor=${rest%%.*}
    patch=${rest#*.}

    case "$bump_type" in
        patch) patch=$((patch + 1)) ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        major) major=$((major + 1)); minor=0; patch=0 ;;
        *)
            if [[ ! "$bump_type" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                error "Invalid version: $bump_type (expected X.Y.Z)"
                exit 1
            fi
            echo "$bump_type"
            return
            ;;
    esac
    echo "${major}.${minor}.${patch}"
}

# --- Preflight ---
preflight() {
    info "Running pre-flight checks..."

    if ! git rev-parse --git-dir &>/dev/null; then
        error "Not in a git repository"
        exit 1
    fi

    local branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$branch" != "main" ]]; then
        error "Not on main branch (on: $branch)"
        exit 1
    fi

    if [[ -n $(git status --porcelain) ]]; then
        error "Working tree not clean"
        git status --short
        exit 1
    fi

    if ! command -v gh &>/dev/null; then
        error "gh CLI not found (brew install gh)"
        exit 1
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        error "gh not authenticated (gh auth login)"
        exit 1
    fi

    info "Running tests..."
    if ! "${REPO_ROOT}/tests/test-layouts.zsh"; then
        error "Tests failed"
        exit 1
    fi

    if ! "${REPO_ROOT}/bin/gsx" help &>/dev/null; then
        error "gsx help failed"
        exit 1
    fi

    if ! "${REPO_ROOT}/bin/gsx" version &>/dev/null; then
        error "gsx version failed"
        exit 1
    fi

    git fetch origin --quiet
    local local_sha=$(git rev-parse HEAD)
    local remote_sha=$(git rev-parse origin/main 2>/dev/null)
    if [[ -n "$remote_sha" && "$local_sha" != "$remote_sha" ]]; then
        error "Local main differs from origin/main. Pull or push first."
        exit 1
    fi

    success "Pre-flight passed"
}

# --- Find last tag ---
get_last_tag() {
    local tag=$(git tag --sort=-version:refname | head -1)
    if [[ -z "$tag" ]]; then
        echo ""
    else
        echo "$tag"
    fi
}

# --- Generate changelog ---
generate_changelog() {
    local last_tag=$1 new_version=$2
    local date_str=$(date +%Y-%m-%d)
    local added=() fixed=() changed=() uncategorized=()

    local commits
    if [[ -z "$last_tag" ]]; then
        commits=$(git log --oneline --no-merges)
    else
        commits=$(git log "${last_tag}..HEAD" --oneline --no-merges)
    fi

    if [[ -z "$commits" ]]; then
        error "No commits since ${last_tag:-beginning}"
        exit 1
    fi

    while IFS= read -r line; do
        local hash=${line%% *}
        local msg=${line#* }

        case "$msg" in
            feat:*|feat\(*)   added+=("- ${msg#feat*: }") ;;
            fix:*|fix\(*)     fixed+=("- ${msg#fix*: }") ;;
            chore:*|docs:*|refactor:*|test:*|style:*|ci:*) changed+=("- ${msg}") ;;
            *)                uncategorized+=("- ${msg}") ;;
        esac
    done <<< "$commits"

    if [[ ${#uncategorized[@]} -gt 0 ]]; then
        warn "Uncategorized commits (will appear under Changed):"
        printf '  %s\n' "${uncategorized[@]}"
        echo ""
    fi

    local entry="## [${new_version}] - ${date_str}"

    if [[ ${#added[@]} -gt 0 ]]; then
        entry+=$'\n\n### Added\n'
        for item in "${added[@]}"; do entry+="${item}"$'\n'; done
    fi

    if [[ ${#fixed[@]} -gt 0 ]]; then
        entry+=$'\n\n### Fixed\n'
        for item in "${fixed[@]}"; do entry+="${item}"$'\n'; done
    fi

    if [[ ${#changed[@]} -gt 0 || ${#uncategorized[@]} -gt 0 ]]; then
        entry+=$'\n\n### Changed\n'
        for item in "${changed[@]}"; do entry+="${item}"$'\n'; done
        for item in "${uncategorized[@]}"; do entry+="${item}"$'\n'; done
    fi

    printf '%s' "$entry"
}

# --- Update CHANGELOG.md ---
update_changelog() {
    local new_version=$1 entry=$2
    local changelog="${REPO_ROOT}/CHANGELOG.md"
    local tmp="${changelog}.tmp"
    local link="[${new_version}]: https://github.com/minorole/gsx/releases/tag/v${new_version}"

    # Write entry to temp file to avoid awk -v injection with special chars
    local entry_file="${tmp}.entry"
    printf '%s\n' "$entry" > "$entry_file"

    # Insert entry before first ## [ line
    awk '
        /^## \[/ && !inserted {
            while ((getline line < "'"$entry_file"'") > 0) print line
            close("'"$entry_file"'")
            print ""
            inserted=1
        }
        { print }
    ' "$changelog" > "$tmp"
    rm -f "$entry_file"

    if ! grep -q "^## \[${new_version}\]" "$tmp"; then
        error "Failed to insert changelog entry"
        rm -f "$tmp"
        exit 1
    fi

    # Insert link ref before first existing link ref
    local has_links=$(grep -c '^\[.*\]: https://github.com' "$tmp")
    if [[ "$has_links" -gt 0 ]]; then
        awk -v link="$link" '
            /^\[.*\]: https:\/\/github\.com/ && !inserted {
                print link
                inserted=1
            }
            { print }
        ' "$tmp" > "${tmp}.2"
        mv "${tmp}.2" "$tmp"
    else
        echo "" >> "$tmp"
        echo "$link" >> "$tmp"
    fi

    mv "$tmp" "$changelog"
}

# --- Extract release notes from changelog ---
extract_release_notes() {
    local new_version=$1
    local changelog="${REPO_ROOT}/CHANGELOG.md"

    awk "/^## \[${new_version}\]/{found=1; next} /^## \[/{if(found) exit} found{print}" "$changelog" \
        | sed '/^$/d'
}

# --- Main ---
main() {
    local bump_type=${1:-patch}

    preflight

    local current_version=$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")
    local new_version=$(bump_version "$current_version" "$bump_type")

    if git tag -l "v${new_version}" | grep -q "v${new_version}"; then
        error "Tag v${new_version} already exists"
        exit 1
    fi

    local last_tag=$(get_last_tag)
    info "Current: ${current_version} → New: ${new_version}"
    info "Last tag: ${last_tag:-<none>}"
    echo ""

    local changelog_entry=$(generate_changelog "$last_tag" "$new_version")

    echo "${BOLD}=== Release Summary ===${NC}"
    echo ""
    echo "Version: ${YELLOW}${current_version}${NC} → ${GREEN}${new_version}${NC}"
    echo ""
    echo "${BOLD}Changelog:${NC}"
    echo "$changelog_entry" | sed 's/^/  /'
    echo ""
    echo "${BOLD}Actions:${NC}"
    echo "  1. Update VERSION → ${new_version}"
    echo "  2. Insert changelog entry"
    echo "  3. Commit: chore: release v${new_version}"
    echo "  4. Tag: v${new_version}"
    echo "  5. Push to origin"
    echo "  6. Create GitHub release"
    echo ""

    read "confirm?${YELLOW}Proceed? [y/N]${NC} "
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""

    info "Updating VERSION..."
    echo "$new_version" > "${REPO_ROOT}/VERSION"

    info "Updating CHANGELOG.md..."
    update_changelog "$new_version" "$changelog_entry"

    info "Committing..."
    git add "${REPO_ROOT}/VERSION" "${REPO_ROOT}/CHANGELOG.md"
    if ! git commit -m "chore: release v${new_version}"; then
        error "Commit failed"
        exit 1
    fi

    info "Tagging v${new_version}..."
    if ! git tag "v${new_version}"; then
        error "Tag failed"
        exit 1
    fi

    info "Pushing..."
    if ! git push origin main; then
        error "Push failed (commit). Tag is local — fix and retry."
        exit 1
    fi

    if ! git push origin "v${new_version}"; then
        error "Push failed (tag). Run: git push origin v${new_version}"
        exit 1
    fi

    info "Creating GitHub release..."
    local notes_file="${REPO_ROOT}/.release-notes.tmp"
    extract_release_notes "$new_version" > "$notes_file"
    if ! gh release create "v${new_version}" --title "v${new_version}" --notes-file "$notes_file"; then
        error "gh release create failed. Run manually:"
        echo "  gh release create v${new_version} --title v${new_version} --notes-file ${notes_file}"
        exit 1
    fi
    rm -f "$notes_file"

    echo ""
    success "${BOLD}Released v${new_version}${NC}"
    echo ""
    echo "  ${BLUE}https://github.com/minorole/gsx/releases/tag/v${new_version}${NC}"
    echo ""
    echo "  Homebrew will update automatically via GH Action."
}

main "$@"
