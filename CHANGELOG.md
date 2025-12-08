# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.4] - 2025-12-08

### Added

- **`--here` flag**: Open panes in current Ghostty window instead of creating a new one
  - Alias: `--current-window`
  - When opening multiple projects, only the first uses the current window
  - Example: `gpane myproject --here`
- Automatic migration from old `gsx` installation when running installer
- Compatibility wrapper for `gsx` command with daily rename notice

### Changed

- **Renamed `gsx` to `gpane`** to avoid conflict with Ghostscript
  - Primary command is now `gpane`
  - `gsx` command still works as a compatibility wrapper (shows daily reminder)
  - Config location unchanged: `~/.config/gsx/config.yaml`
  - All existing configurations continue to work
- Installation location changed from `~/.local/share/gsx` to `~/.local/share/gpane`
- Update command now shows one-liner: `curl -sSL https://raw.githubusercontent.com/minorole/gsx/main/install.sh | bash`

## [0.2.3] - 2025-12-05

### Fixed

- `gsx setup <project>` now supports tabs layout (option 8 was missing)
- `gsx setup <project>` now prompts for correct pane count when keeping default layout

### Changed

- Extracted shared prompt functions to `lib/prompts.zsh`

## [0.2.2] - 2025-12-05

### Added

- **Tabs layout**: New `tabs` layout mode — opens multiple Ghostty tabs instead of split panes (up to 10 tabs)
- Setup wizard option 8 for tabs, with color-coded UI to distinguish from pane layouts
- User can choose number of tabs (2-10) during setup

### Fixed

- `get_layout_info()` now handles tabs layout correctly
- Race condition in update cache writes (atomic write with printf)
- Setup wizard now includes tabs option (was missing from menu)

### Changed

- `config.example.yaml` updated to array format with tabs example

## [0.2.1] - 2025-12-05

### Added

- `VERSION` file as single source of truth for version number
- `get_layout_info()` helper function for consistent pane count and label generation
- Support for relative paths (`./project`, `../project`) in project resolution
- Tests for `get_layout_info()` function

### Fixed

- **Path injection vulnerability**: Paths containing apostrophes (e.g., `/Users/O'Brien/Projects`) now handled safely using AppleScript's `quoted form of`
- **Config parsing for special project names**: Project names containing regex metacharacters (`.`, `+`, `?`, `(`, `)`, `[`, `]`, `^`, `$`, `*`, `\`) no longer break config parsing
- **Invalid YAML on project setup**: Generated config now includes uncommented `projects:` key, preventing malformed YAML when adding project-specific overrides
- Version mismatch between `install.sh` and `core.zsh` (now both read from `VERSION` file)

### Changed

- Refactored `setup.zsh` to use shared layout helpers, reducing code duplication (380 → 312 lines)
- Installer now copies `VERSION` file to installation directory

### Removed

- Legacy layout functions (`layout_2col`, `layout_3col`, `layout_main_bottom`) — superseded by dynamic layout engine
- Legacy AppleScript files (`layout-2col.applescript`, `layout-3col.applescript`, `layout-main-bottom.applescript`)

## [0.2.0] - 2025-12-04

### Added

- **Dynamic layouts**: Support for 2-10 panes in any row-based configuration
- New layout notation: `2-2` (4-pane grid), `1-3` (1 main + 3 below), `2-2-5-1`, etc.
- Preset aliases: `quad`, `dashboard`, `stacked`, `wide` (in addition to `duo`, `trio`)
- Array-based command format for configs with 4+ panes
- Layout validation (max 10 panes, max 4 rows)
- Setup wizard now supports all new layout options

### Changed

- Unified layout engine replaces separate layout scripts
- Commands typed inline during pane creation (more reliable)

### Fixed

- Command placement in asymmetric layouts (e.g., `2-2-5-1`)

## [0.1.1] - 2025-12-03

### Fixed

- Update checker sed regex for version parsing (now uses cut)
- Version validation to prevent corrupted cache display
- Auto-clear invalid cache entries

### Added

- GitHub Action to automatically update Homebrew formula on release

## [0.1.0] - 2025-12-03

### Added

- Interactive project picker with multi-select support
- Three layout options: 3-col, 2-col, main+bottom
- Setup wizard for first-time configuration
- Per-project configuration overrides
- Dry-run mode (`--dry-run`) for previewing actions
- Auto-update checker (checks GitHub releases daily)
- Uninstall command (`gsx uninstall`)

[0.2.4]: https://github.com/minorole/gsx/releases/tag/v0.2.4
[0.2.3]: https://github.com/minorole/gsx/releases/tag/v0.2.3
[0.2.2]: https://github.com/minorole/gsx/releases/tag/v0.2.2
[0.2.1]: https://github.com/minorole/gsx/releases/tag/v0.2.1
[0.2.0]: https://github.com/minorole/gsx/releases/tag/v0.2.0
[0.1.1]: https://github.com/minorole/gsx/releases/tag/v0.1.1
[0.1.0]: https://github.com/minorole/gsx/releases/tag/v0.1.0