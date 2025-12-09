# RFC: Support for Nested Projects in gpane

**Status:** Draft - Seeking Feedback
**Author:** @minorole
**Date:** 2025-12-08

---

## Summary

A user requested the ability to configure gpane for specific project directories that aren't direct children of `projects_root`. This RFC documents the problem, explores solutions, and proposes an implementation plan.

---

## Background: What is gpane?

gpane is a macOS CLI tool that launches Ghostty terminal with pre-configured split panes for development workflows. Users configure a `projects_root` directory, and gpane auto-discovers projects as immediate subdirectories.

**Current config structure (`~/.config/gpane/config.yaml`):**
```yaml
projects_root: ~/Projects
default_layout: duo

default_commands:
  - "claude"
  - ""

projects:
  myproject:
    layout: quad
    commands:
      - "nvim ."
      - "npm run dev"
```

**Current usage:**
```bash
gpane myproject      # Opens ~/Projects/myproject with configured layout
gpane list           # Lists all directories in ~/Projects
gpane                # Interactive picker showing all projects
```

---

## The Problem

### User Feedback (verbatim)

> "I think it would be great if I can config for specific project directory because in our workspace we have nested projects. gpane only looks for project directory at config projects dir."

### Concrete Example

User has this directory structure:
```
~/Projects/
  company-monorepo/
    frontend/      ← User wants to open THIS directly
    backend/       ← And THIS
    shared/
  simple-project/
```

**Current limitation:** `gpane frontend` fails because gpane only looks for `~/Projects/frontend`, not `~/Projects/company-monorepo/frontend`.

**Current workarounds:**
- `gpane ~/Projects/company-monorepo/frontend` (verbose, no saved config)
- `gpane ./frontend` from within monorepo (requires cd first)

Neither allows short aliases with project-specific layout/commands.

---

## Goals

1. Allow users to reference nested projects by short aliases
2. Support project-specific configuration (layout, commands) for nested projects
3. Maintain backwards compatibility with existing configs
4. Keep the solution simple and discoverable

---

## Solutions Considered

### Option A: YAML `path:` Field (Power User)

Add optional `path:` field to project config:

```yaml
projects_root: ~/Projects

projects:
  frontend:
    path: ~/Projects/company-monorepo/frontend
    layout: quad
    commands:
      - "npm run dev"
      - ""

  backend:
    path: ~/Projects/company-monorepo/backend
```

**Usage:**
```bash
gpane frontend  # Uses explicit path from config
gpane list      # Shows both auto-discovered AND explicitly configured
```

**Resolution logic:**
1. Check if `projects.<name>.path` exists in config → use that
2. Otherwise, fall back to `${projects_root}/<name>`

**Pros:**
- Flexible and explicit
- No new commands to learn
- Power users can bulk-edit config

**Cons:**
- Low discoverability (user must know to add `path:`)
- Manual YAML editing required
- Easy to make syntax errors

---

### Option B: `gpane add` Command (User-Friendly)

Add CLI commands to manage project aliases:

```bash
gpane add <alias> <path>    # Register a project alias
gpane remove <alias>        # Remove an alias
```

**Example:**
```bash
gpane add frontend ~/Projects/company-monorepo/frontend
gpane add backend ~/Projects/company-monorepo/backend

gpane frontend  # Works!
```

This writes to the YAML config automatically, same structure as Option A.

**Pros:**
- Highly discoverable via `gpane help`
- No manual YAML editing
- Validates path exists before saving
- Could prompt for layout/commands interactively

**Cons:**
- New commands to implement
- Slightly more code complexity

---

### Option C: Auto-Discovery with Markers

Automatically find projects by looking for markers (`.git`, `package.json`, etc.):

```yaml
projects_root: ~/Projects
discover:
  markers: [.git, package.json, Cargo.toml]
  max_depth: 3
```

**Pros:**
- Zero configuration for new projects

**Cons:**
- **Name collisions:** Multiple `frontend` directories → which one?
- Performance on deep directory trees
- Unpredictable results
- No way to assign custom aliases

**Verdict:** Rejected due to collision problem.

---

### Option D: Multiple `projects_roots`

```yaml
projects_roots:
  - ~/Projects
  - ~/Projects/company-monorepo
```

**Pros:**
- Simple extension of current model

**Cons:**
- Causes duplication (`company-monorepo` appears both as project AND as root)
- Still has name collision problem
- Doesn't allow custom aliases

**Verdict:** Rejected.

---

### Option E: Per-Directory Config Files

Put `.gpane.yaml` inside each project directory for gpane to discover.

**Cons:**
- Pollutes project directories
- Still has collision problem
- Harder to manage centrally

**Verdict:** Rejected.

---

## Recommended Solution: Option A + B Combined

Implement both layers:

1. **YAML `path:` field** - The underlying mechanism (Option A)
2. **`gpane add` command** - User-friendly wrapper (Option B)

This gives:
- Power users can edit YAML directly
- Regular users can use the CLI command
- Same underlying config format

---

## Detailed Design

### Config Format

```yaml
projects_root: ~/Projects
default_layout: duo
default_commands:
  - "claude"
  - ""

projects:
  # Nested project with explicit path
  frontend:
    path: ~/Projects/company-monorepo/frontend
    layout: quad
    commands:
      - "npm run dev"
      - "npm test"
      - "claude"
      - ""

  # Project in projects_root (no path needed, existing behavior)
  simple-app:
    layout: trio
```

### CLI Commands

```bash
# Register a new project alias
gpane add <alias> <path>
gpane add frontend ~/Projects/monorepo/frontend

# With optional layout
gpane add frontend ~/Projects/monorepo/frontend --layout quad

# Remove an alias
gpane remove <alias>
gpane remove frontend

# List shows both auto-discovered and explicit
gpane list
```

### Resolution Priority

When user runs `gpane <name>`:

1. **Absolute path** (`/Users/...`) → use directly
2. **Relative path** (`./foo`, `../bar`) → resolve from cwd
3. **Project name:**
   - Check `projects.<name>.path` in config → use if exists
   - Otherwise check `${projects_root}/<name>` → use if exists
   - Otherwise error

### `gpane list` Output

```
Projects in /Users/me/Projects:

  ai-app
  booksite
  frontend     → company-monorepo/frontend
  backend      → company-monorepo/backend
  simple-app
  tools

6 project(s)
```

Explicitly configured projects show their relative path for clarity.

### Interactive Picker

`gpane` (no args) shows merged list, sorted alphabetically:

```
Projects:

   1) ai-app
   2) backend
   3) booksite
   4) frontend
   5) simple-app
   6) tools

Select project(s):
```

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Name collision (explicit + auto-discovered) | Explicit wins |
| Explicit path doesn't exist | Error: "Configured path '...' does not exist" |
| Relative path in config | Error: "Path must be absolute or use ~" |
| `gpane add` with existing alias | Prompt: "Overwrite existing? [y/N]" |
| `gpane remove` non-existent | Error: "Alias 'foo' not found" |
| Tilde in path (`~/...`) | Expand to $HOME |
| Trailing slashes | Normalize (remove) |
| `projects_root` doesn't exist but explicit paths do | Explicit projects still work |

---

## Implementation Plan

### Phase 1: YAML Support

**Files to modify:**

1. **`lib/config.zsh`**
   - Add `get_project_path()` function to extract `projects.<name>.path`
   - Handle tilde expansion

2. **`lib/projects.zsh`**
   - Modify `resolve_project_dir()` to check explicit path first
   - Modify `list_projects()` to include explicit projects
   - Modify `interactive_select()` to merge lists

3. **`config.example.yaml`**
   - Add `path:` example with documentation

4. **`lib/help.zsh`**
   - Document the `path:` feature

### Phase 2: CLI Commands

1. **`bin/gpane`**
   - Add `add` and `remove` command handlers

2. **`lib/projects.zsh`** (or new `lib/aliases.zsh`)
   - `add_project_alias()` - validates and writes to config
   - `remove_project_alias()` - removes from config

3. **`lib/help.zsh`**
   - Document new commands

### Testing

- `gpane add test-alias ~/some/path` → creates config entry
- `gpane test-alias --dry-run` → shows correct path
- `gpane list` → shows alias in list
- `gpane remove test-alias` → removes from config
- Edge cases: collisions, missing paths, etc.

---

## Open Questions

1. **Should `gpane add` prompt for layout/commands interactively?**
   - Pro: More complete setup
   - Con: More complex, user can run `gpane setup <alias>` after

2. **Should `gpane list` visually distinguish explicit vs auto-discovered?**
   - Option: Show arrow `→ actual/path` for explicit
   - Option: No distinction, just merge

3. **Should we warn about shadowed auto-discovered projects?**
   - When explicit alias matches a directory in projects_root

4. **Command naming: `gpane add` or `gpane alias` or `gpane register`?**
   - `add` is simpler and more common (git remote add, etc.)

---

## Alternatives Not Chosen

| Alternative | Why Rejected |
|-------------|--------------|
| Auto-discovery with markers | Name collision problem |
| Multiple projects_roots | Duplication and collision |
| Per-directory config files | Pollutes projects, collision |
| Symlinks | Manual, not discoverable |

---

## Request for Feedback

1. Does the `path:` + `gpane add` approach solve your use case?
2. Are there edge cases we haven't considered?
3. Preference on open questions above?
4. Any concerns about the implementation?

---

## Appendix: Current Architecture

```
bin/gpane           # Entry point, dispatches commands
lib/config.zsh      # YAML parsing, config management
lib/projects.zsh    # Project resolution, listing, picker
lib/layouts.zsh     # Layout handling (panes, tabs)
lib/setup.zsh       # Setup wizard
lib/help.zsh        # Help text
```

Key functions:
- `resolve_project_dir()` - converts name/path to absolute path
- `parse_project_config()` - loads per-project overrides
- `list_projects()` - lists projects from projects_root
- `interactive_select()` - interactive picker UI
