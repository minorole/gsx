# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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

[0.2.0]: https://github.com/minorole/gsx/releases/tag/v0.2.0
[0.1.1]: https://github.com/minorole/gsx/releases/tag/v0.1.1
[0.1.0]: https://github.com/minorole/gsx/releases/tag/v0.1.0