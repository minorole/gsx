# RFC-001: Dynamic Pane Layouts

**Status:** Approved (pending implementation)
**Author:** @minorole
**Created:** 2024-12-04
**Reviewed:** 2024-12-04

---

## Summary

Add support for user-configurable pane layouts beyond the current hardcoded `duo` (2-col) and `trio` (3-col) presets. Users should be able to specify arbitrary row-based layouts like `2-2` (4-pane grid) or `1-3` (1 main + 3 below).

---

## Motivation

### User Request
> "This looks nice, but do I understand correctly that I cannot freely configure the layout? Because I, for example, use 4 tabs. Would be really handy to start it up with one command."
> — Reddit user

### Current Limitations
- Only 3 hardcoded layouts: `2-col`, `3-col`, `main-bottom`
- Adding new layouts requires writing new AppleScript files
- Users cannot customize pane counts or arrangements

### Goals
1. Support 2-10 panes in flexible arrangements
2. Intuitive configuration syntax
3. Single AppleScript that handles all layouts
4. Backward compatible with existing configs

---

## Proposed Solution

### Layout Notation: Row-Based Syntax

```
"N"       → N panes in a single row (horizontal)
"N-M"     → N panes top row, M panes bottom row
"N-M-O"   → 3 rows with N, M, O panes respectively
```

#### Examples

| Notation | Panes | Visual |
|----------|-------|--------|
| `2` | 2 | `[1 \| 2]` |
| `3` | 3 | `[1 \| 2 \| 3]` |
| `1-1` | 2 | `[1]` / `[2]` (stacked) |
| `2-2` | 4 | `[1 \| 2]` / `[3 \| 4]` |
| `1-3` | 4 | `[  1  ]` / `[2\|3\|4]` |
| `3-1` | 4 | `[1\|2\|3]` / `[  4  ]` |
| `1-2-1` | 4 | `[1]` / `[2\|3]` / `[4]` |
| `2-3-1` | 6 | `[1\|2]` / `[3\|4\|5]` / `[6]` |

#### Why This Notation?

| Alternative | Example | Rejected Because |
|-------------|---------|------------------|
| Grid `NxM` | `2x2` | Can't express asymmetric layouts like `1-3` |
| Count only | `panes: 4` | No control over arrangement |
| Tree DSL | `H[V[1,2],3]` | Too complex for config files |

The row-based notation is:
- **Intuitive**: reads as "2 panes, then 2 panes" = `2-2`
- **Flexible**: handles both grids and asymmetric layouts
- **Simple**: just numbers and dashes

### Preset Aliases

For discoverability, provide named presets that map to row notation:

| Alias | Layout | Description |
|-------|--------|-------------|
| `duo` | `2` | 2 panes side-by-side (legacy) |
| `trio` | `3` | 3 panes side-by-side (legacy) |
| `stacked` | `1-1` | 2 panes vertically |
| `quad` | `2-2` | 2x2 grid |
| `dashboard` | `1-3` | 1 main top, 3 below |
| `wide` | `3-1` | 3 top, 1 bottom |

Users can use either form:
```yaml
layout: quad       # alias
layout: "2-2"      # explicit notation
```

---

## Technical Design

### Ghostty Split Behavior

Ghostty uses a **tree structure** for splits (like tmux):

```
Cmd+D         → Horizontal split (new pane to RIGHT)
Cmd+Shift+D   → Vertical split (new pane BELOW)
Cmd+[ / Cmd+] → Navigate by CREATION ORDER (not spatial)
```

**Key constraint**: `Cmd+[/]` navigation follows creation order, not left-right/top-bottom spatial order. This creates an ordering mismatch we must handle.

### Algorithm Overview

For layout `[r1, r2, ..., rn]` where `ri` = panes in row `i`:

```
PHASE 1: Create row spine
─────────────────────────
- Execute (n-1) vertical splits to create n rows
- Result: n panes stacked vertically (one per row)

PHASE 2: Expand rows horizontally
───────────────────────────────────
- Navigate to top row
- For each row i:
  - Execute (ri - 1) horizontal splits
  - Navigate to next row

PHASE 3: Equalize
─────────────────
- Execute equalize_splits to balance sizes

PHASE 4: Run commands
─────────────────────
- Navigate to pane 1
- Traverse in creation order
- Execute command for each pane
```

### Detailed Walkthrough: Layout `2-2`

```
Input: layout = [2, 2]

PHASE 1: Create 1 vertical split (2 rows - 1)
┌─────────┐      ┌─────────┐
│  pane1  │  →   │  pane1  │  Creation: [1, 2]
│         │      ├─────────┤  Focus: pane2
└─────────┘      │  pane2  │
                 └─────────┘

Navigate to top: Cmd+[
Focus: pane1

PHASE 2: Split each row

Row 1 (pane1): needs 2-1=1 horizontal split
┌─────────┐      ┌────┬────┐
│  pane1  │  →   │ p1 │ p3 │  Creation: [1, 2, 3]
├─────────┤      ├────┴────┤  Focus: pane3
│  pane2  │      │  pane2  │
└─────────┘      └─────────┘

Navigate to row 2: Cmd+[ (to pane2)

Row 2 (pane2): needs 2-1=1 horizontal split
┌────┬────┐      ┌────┬────┐
│ p1 │ p3 │  →   │ p1 │ p3 │  Creation: [1, 2, 3, 4]
├────┴────┤      ├────┼────┤  Focus: pane4
│  pane2  │      │ p2 │ p4 │
└─────────┘      └────┴────┘

PHASE 3: Equalize (Cmd+Ctrl++)

PHASE 4: Run commands (see Ordering Problem below)
```

### The Ordering Problem

**Creation order** differs from **spatial order** (left→right, top→bottom):

```
Spatial positions:          Creation order:
┌─────┬─────┐               ┌─────┬─────┐
│  0  │  1  │               │  1  │  3  │
├─────┼─────┤               ├─────┼─────┤
│  2  │  3  │               │  2  │  4  │
└─────┴─────┘               └─────┴─────┘

Spatial order: [pane1, pane3, pane2, pane4]
Creation order: [pane1, pane2, pane3, pane4]
```

**Users think spatially** — they'll provide commands as `[top-left, top-right, bottom-left, bottom-right]`.

**Ghostty navigates by creation** — `Cmd+]` goes pane1→pane2→pane3→pane4.

**Solution**: Compute a mapping and reorder commands before passing to AppleScript.

### Mapping Algorithm

```python
def compute_creation_to_spatial(layout):
    """
    For layout [r1, r2, ...], compute mapping from creation index
    to spatial index.

    Creation order:
    - First n panes are row "anchors" (pane i anchors row i-1)
    - Additional panes added row by row

    Returns: list where result[creation_idx] = spatial_idx
    """
    n = len(layout)
    total = sum(layout)

    # Track position of each pane (by creation index)
    creation_to_pos = {}

    # Anchors: pane i is at (row=i-1, col=0) for i in 1..n
    for i in range(n):
        creation_to_pos[i] = (i, 0)

    # Additional panes per row
    pane_idx = n
    for row in range(n):
        for col in range(1, layout[row]):
            creation_to_pos[pane_idx] = (row, col)
            pane_idx += 1

    # Spatial order: row-major (left→right, top→bottom)
    spatial_order = []
    for row in range(n):
        for col in range(layout[row]):
            spatial_order.append((row, col))

    pos_to_spatial = {pos: i for i, pos in enumerate(spatial_order)}

    # Map creation index → spatial index
    return [pos_to_spatial[creation_to_pos[i]] for i in range(total)]
```

### Mapping Examples

| Layout | Creation → Spatial | Notes |
|--------|-------------------|-------|
| `2` | `[0, 1]` | Trivial |
| `3` | `[0, 1, 2]` | Trivial |
| `1-1` | `[0, 1]` | Trivial (stacked) |
| `2-2` | `[0, 2, 1, 3]` | Grid reordering |
| `1-3` | `[0, 1, 2, 3]` | Happens to match |
| `3-1` | `[0, 3, 1, 2]` | Complex reordering |
| `1-2-1` | `[0, 1, 3, 2]` | 3-row case |

---

## Config Format

### Current Format
```yaml
default_layout: 3-col

default_commands:
  left: "nvim ."
  middle: "npm run dev"
  right: ""
```

### Proposed Format
```yaml
default_layout: "2-2"

default_commands:
  - "nvim ."           # spatial position 0 (top-left)
  - "npm run dev"      # spatial position 1 (top-right)
  - "npm test --watch" # spatial position 2 (bottom-left)
  - ""                 # spatial position 3 (bottom-right)

# Project override example
projects:
  myapp:
    layout: "1-3"
    commands:
      - "nvim ."       # top (full width)
      - "npm run dev"  # bottom-left
      - "npm test"     # bottom-middle
      - "tail -f logs" # bottom-right
```

### Backward Compatibility

Support legacy named layouts:
```yaml
default_layout: duo        # alias for "2"
default_layout: trio       # alias for "3"
default_layout: 3-col      # alias for "3"
default_layout: main-bottom # alias for "1-1"
```

### Config Format Migration

**Problem**: The RFC changes command format from named keys to array:

```yaml
# OLD FORMAT (named keys)
default_commands:
  left: "nvim ."
  middle: "npm run dev"
  right: ""

# NEW FORMAT (array)
default_commands:
  - "nvim ."
  - "npm run dev"
  - ""
```

**Solution**: Support both formats (detect and convert internally).

The parser can distinguish formats by checking for named keys vs array syntax:

```zsh
# Detection logic
if [[ "${line}" =~ ^[[:space:]]+(left|middle|right|top|bottom):[[:space:]]* ]]; then
    # Old format: named keys
elif [[ "${line}" =~ ^[[:space:]]+-[[:space:]]* ]]; then
    # New format: array
fi
```

**Mapping old keys to indices**:
| Key | Index | Notes |
|-----|-------|-------|
| `left` | 0 | First pane |
| `middle` | 1 | Second pane |
| `right` | 2 | Third pane |
| `top` | 0 | Alias for left (stacked layouts) |
| `bottom` | 1 | Alias for middle (stacked layouts) |

**Fallback behavior**: If a user specifies `layout: "2-2"` with old-format commands (only `left`, `middle`, `right`), panes 0-2 get those commands, pane 3 gets empty string.

---

## Implementation Plan

### Files to Modify/Create

| File | Change |
|------|--------|
| `scripts/layout-dynamic.applescript` | **New** — Single script handling all layouts |
| `lib/layouts.zsh` | Add `layout_dynamic()`, mapping logic |
| `lib/config.zsh` | Parse new array-based commands format |
| `scripts/layout-2col.applescript` | Keep for backward compat, or remove |
| `scripts/layout-3col.applescript` | Keep for backward compat, or remove |

### AppleScript Pseudocode

```applescript
on run argv
    set projectDir to item 1 of argv
    set layoutSpec to item 2 of argv    -- e.g., "2-2"
    set commands to items 3 thru -1 of argv  -- already in creation order

    tell application "Ghostty" to activate
    delay 0.3

    tell application "System Events"
        tell process "Ghostty"
            -- New window + cd to project
            keystroke "n" using {command down}
            delay 0.6
            keystroke "cd '" & projectDir & "'"
            key code 36  -- Enter
            delay 0.3

            -- Parse layout
            set rows to splitByDash(layoutSpec)  -- {2, 2}
            set numRows to count of rows

            -- PHASE 1: Create row spine
            repeat numRows - 1 times
                keystroke "d" using {command down, shift down}
                delay 0.25
            end repeat

            -- Navigate to top
            repeat numRows - 1 times
                keystroke "[" using {command down}
                delay 0.15
            end repeat

            -- PHASE 2: Expand rows
            repeat with rowIdx from 1 to numRows
                set panesInRow to (item rowIdx of rows) as integer
                repeat panesInRow - 1 times
                    keystroke "d" using {command down}
                    delay 0.25
                end repeat

                if rowIdx < numRows then
                    -- Back to left of row
                    repeat panesInRow - 1 times
                        keystroke "[" using {command down}
                        delay 0.15
                    end repeat
                    -- Down to next row
                    keystroke "]" using {command down}
                    delay 0.15
                end if
            end repeat

            -- PHASE 3: Equalize
            key code 24 using {command down, control down}
            delay 0.5

            -- PHASE 4: Navigate to pane1 and run commands
            set totalPanes to count of commands
            repeat totalPanes - 1 times
                keystroke "[" using {command down}
                delay 0.1
            end repeat

            repeat with i from 1 to totalPanes
                set cmd to item i of commands
                if cmd is not "" then
                    keystroke cmd
                    key code 36
                    delay 0.3
                end if
                if i < totalPanes then
                    keystroke "]" using {command down}
                    delay 0.15
                end if
            end repeat
        end tell
    end tell
end run
```

---

## Edge Cases & Open Questions

### Edge Cases to Test

| Case | Layout | Expected Behavior |
|------|--------|-------------------|
| Single pane | `1` | No splits, just cd + run command |
| Single row | `4` | 3 horizontal splits |
| Single column | `1-1-1-1` | 3 vertical splits |
| Asymmetric | `1-3` | 1 top, 3 bottom |
| Inverse asymmetric | `3-1` | 3 top, 1 bottom |
| Large grid | `3-3-3` | 9 panes |
| Max reasonable | `5-5` | 10 panes (proposed max) |
| Empty commands | `2-2` with `["", "", "", ""]` | 4 empty shells |
| Fewer commands than panes | `2-2` with `["nvim"]` | Fill remaining with empty? |
| More commands than panes | `2` with 4 commands | Ignore extras? Error? |

### Decisions (from review)

1. **Max pane limit** → **10 panes max, enforced**
   - Rationale: Beyond 10, panes become too small to be useful

2. **Command count mismatch** → **Option B: Fill missing with empty string**
   - Least surprising default; error is too strict; repeating is weird

3. **Legacy layout names** → **Yes, keep as aliases**
   - `duo`, `trio`, `3-col`, `main-bottom` all supported

4. **Validation timing** → **Parse time, fail fast**
   - Clear error message if layout string is invalid

5. **Row limit** → **Max 4 rows**
   - Combined with max 10 panes total

6. **Per-pane working directory** → **Out of scope**
   - Future enhancement, not in this RFC

### Known Limitations

**Timing Delays**: The AppleScript uses 15+ hardcoded delays (0.15s to 0.5s). For complex layouts like `3-3-3` (9 panes), this means ~30 keystrokes with delays. If any timing fails, the layout breaks silently.

Accepted trade-offs:
- This is inherent to the keystroke simulation approach
- Ghostty has no programmatic split API (see [Discussion #2480](https://github.com/ghostty-org/ghostty/discussions/2480))
- Document as known limitation
- Future: Consider `--slow` flag for accessibility/older machines

### Validation Rules

```
Layout string must match: ^[1-9](-[1-9])*$
Total panes: sum of all numbers ≤ 10
Rows: count of numbers ≤ 4
```

---

## Testing Plan

### Manual Testing Matrix

| Test | Layout | Commands | Verify |
|------|--------|----------|--------|
| Basic duo | `2` | `["nvim", ""]` | 2 side-by-side panes |
| Basic trio | `3` | `["a", "b", "c"]` | 3 side-by-side panes |
| Stacked | `1-1` | `["top", "bottom"]` | 2 stacked panes |
| Grid | `2-2` | `["tl", "tr", "bl", "br"]` | Commands in correct positions |
| Asymmetric | `1-3` | `["main", "a", "b", "c"]` | 1 top (full), 3 bottom |
| 3 rows | `1-2-1` | `["t", "ml", "mr", "b"]` | Correct arrangement |
| Max | `5-5` | 10 commands | All panes created |

### Automated Testing

- Unit tests for `compute_creation_to_spatial()` mapping function
- Integration test with `--dry-run` flag (print commands, don't execute)

---

## Rollout Plan

1. **Phase 1**: Implement and test `layout-dynamic.applescript`
2. **Phase 2**: Update config parsing for new format
3. **Phase 3**: Add backward compatibility aliases
4. **Phase 4**: Update documentation and examples
5. **Phase 5**: Deprecation notice for old format (optional)

---

## Appendix: Full Mapping Table

For reference, here are the creation→spatial mappings for common layouts:

```
Layout    Creation Order        Spatial Mapping
──────    ──────────────        ───────────────
2         [1,2]                 [0,1]
3         [1,2,3]               [0,1,2]
1-1       [1,2]                 [0,1]
2-1       [1,2,3]               [0,2,1]
1-2       [1,2,3]               [0,1,2]
2-2       [1,2,3,4]             [0,2,1,3]
3-1       [1,2,3,4]             [0,3,1,2]
1-3       [1,2,3,4]             [0,1,2,3]
1-2-1     [1,2,3,4]             [0,1,3,2]
2-2-2     [1,2,3,4,5,6]         [0,3,1,4,2,5]
3-3       [1,2,3,4,5,6]         [0,3,1,4,2,5]
```

---

## References

- [Ghostty Keybind Reference](https://ghostty.org/docs/config/keybind/reference)
- [Ghostty Layout Discussion #2480](https://github.com/ghostty-org/ghostty/discussions/2480)
- [Current gsx layouts implementation](../lib/layouts.zsh)

---

## Review Summary

**Reviewer Verdict**: Approved with amendments

**What was validated**:
- Row-based notation is the correct choice over alternatives
- Spine-first algorithm is necessary (row-by-row creates asymmetric trees)
- Mapping function is unavoidable given Ghostty's navigation constraints
- Validation rules are sensible

**Amendments incorporated**:
1. Added Config Format Migration section (support both old and new formats)
2. Added Preset Aliases section (quad, dashboard, stacked, wide)
3. Converted Open Questions to Decisions with final answers
4. Added Known Limitations section (timing delays)

**Ready for implementation**.
