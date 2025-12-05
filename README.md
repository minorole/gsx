<p align="center">
  <img src="assets/logo.svg" width="80" alt="gsx logo">
</p>

<h1 align="center">gsx</h1>

<p align="center">
  <strong>Ghostty Session Manager</strong> — Launch AI-ready development environments with one command.
</p>

<p align="center">
  <code>gsx</code> — Open multiple projects in parallel, each with your configured layout
</p>

<br>

<p align="center">
  <img src="assets/demo.gif" alt="gsx demo" width="700">
</p>

## What it does

gsx creates pre-configured [Ghostty](https://ghostty.org) terminal windows for your projects:

- **Dynamic layouts**: 2-10 panes in any row-based configuration
- **Presets**: `duo`, `trio`, `quad`, `dashboard`, `stacked`, `wide`
- **Custom**: `2-2` (grid), `1-3` (1 main + 3 below), `2-2-5-1`, etc.

No more manually opening terminals, splitting panes, cd-ing to directories, and launching Claude/Aider/Copilot.

## Installation

### Homebrew

```bash
brew install minorole/tap/gsx
```

### From source

```bash
git clone https://github.com/minorole/gsx.git
cd gsx
./install.sh
```

### Requirements

- macOS (uses AppleScript for window management)
- [Ghostty](https://ghostty.org) terminal
- zsh
- **Accessibility permission** for your terminal (see below)

### Granting Accessibility Permission

gsx uses AppleScript to control Ghostty windows. macOS requires you to grant accessibility permission:

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button
3. Add your terminal app (Terminal.app, iTerm, or wherever you run `gsx`)
4. Ensure the checkbox is enabled

Without this permission, gsx will fail to create window splits.

## Usage

### First-time setup

```bash
gsx setup
```

This interactive wizard will ask for:
- Your projects folder (e.g., `~/Projects`)
- Default layout (3-col, 2-col, main+bottom)
- Commands for each pane

### Launch a session

```bash
gsx                     # Interactive picker — type "1 3 5" to open multiple projects in parallel
gsx myproject           # Launch session for 'myproject'
```

### Per-project configuration

```bash
gsx setup myproject     # Configure overrides for 'myproject'
```

This lets you set different layouts or commands for specific projects.

### Other commands

```bash
gsx list                # List all projects
gsx config              # Show current configuration
gsx help                # Show help
gsx myproject --dry-run # Preview without opening windows
gsx ./help              # Open project with reserved name
```

**Reserved names:** `help`, `setup`, `config`, `list`, `uninstall`, `version`. Use `./` prefix if your project has one of these names.

## Configuration

Config is stored in `~/.config/gsx/config.yaml`:

```yaml
projects_root: ~/Projects
default_layout: quad    # or "2-2", "1-3", "duo", etc.

# Array format for 4+ panes (spatial order: left-to-right, top-to-bottom)
default_commands:
  - "claude"
  - "aider"
  - "npm run dev"
  - ""

# Per-project overrides
projects:
  my-web-app:
    layout: dashboard    # 1 main top, 3 below
    commands:
      - "claude"
      - "npm run dev"
      - "npm test"
      - "tail -f logs"

  simple-project:
    layout: duo          # 2 panes side-by-side
    commands:
      - "claude"
      - ""
```

> **Tip:** Use `clear && claude` for a cleaner startup. For fully automated workflows, Claude supports `--dangerously-skip-permissions` (use with caution).

## Layouts

### Presets

| Alias | Layout | Panes | Description |
|-------|--------|-------|-------------|
| `duo` | `2` | 2 | Side-by-side |
| `trio` | `3` | 3 | Three columns |
| `stacked` | `1-1` | 2 | Top and bottom |
| `quad` | `2-2` | 4 | 2x2 grid |
| `dashboard` | `1-3` | 4 | 1 main top, 3 below |
| `wide` | `3-1` | 4 | 3 top, 1 bottom |

### Custom Layouts

Use row notation: numbers separated by dashes, each number = panes in that row.

```
2-2     → 4 panes (2 top, 2 bottom)
1-3     → 4 panes (1 top, 3 bottom)
1-2-1   → 4 panes (1 top, 2 middle, 1 bottom)
3-3-3   → 9 panes (3x3 grid)
2-2-5-1 → 10 panes (complex layout)
```

**Limits**: Max 10 panes, max 4 rows.

## How it works

gsx uses AppleScript to:
1. Open a new Ghostty window
2. `cd` to your project directory
3. Create splits based on your layout
4. Run configured commands in each pane

All panes inherit the project directory, so you're ready to code immediately.

## Tips

**Avoid leftover terminal:** When you run `gsx` from a terminal, that terminal stays open. To avoid this:
- Run from Spotlight/Alfred/Raycast instead
- Or use `gsx myproject && exit` to auto-close

## Uninstalling

To completely remove gsx:

```bash
gsx uninstall
```

This will:
- Remove program files (`~/.local/share/gsx/`)
- Remove the symlink (`~/.local/bin/gsx`)
- Optionally remove your config (`~/.config/gsx/`)

If you cloned the repo, you can also delete that directory.

## Roadmap

- [ ] Session save/restore
- [x] Dynamic layouts (grid, custom)
- [ ] Linux support (xdotool)
- [x] Homebrew tap

## License

MIT — see [LICENSE](LICENSE)

## Credits

Built for the [Ghostty](https://ghostty.org) terminal by Mitchell Hashimoto.

Inspired by the friction of setting up AI coding environments every. single. time.
