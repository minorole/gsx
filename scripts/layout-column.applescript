-- gpane column layout: column-first pane configuration
-- Supports both single-window and multi-tab modes
-- Single-window args: reuseWindow, projectDir, layoutSpec, cmd1, cmd2, ...
-- Multi-tab args:     reuseWindow, projectDir, layoutSpec, "tabs:N", cmd1, cmd2, ...
-- layoutSpec: "1|2" means col1 has 1 row, col2 has 2 rows (stacked vertically)
-- Commands are in SPATIAL order (column by column, top-to-bottom within each column)
-- Commands are typed DURING pane creation for reliability

on run argv
    set reuseWindow to item 1 of argv
    set projectDir to item 2 of argv
    set layoutSpec to item 3 of argv

    -- Detect tabs mode: item 4 starts with "tabs:"
    set tabsCount to 1
    set cmdStartIdx to 4
    if (count of argv) > 3 then
        set maybeTabsArg to item 4 of argv
        if maybeTabsArg starts with "tabs:" then
            set tabsCount to (text 6 thru -1 of maybeTabsArg) as integer
            set cmdStartIdx to 5
        end if
    end if

    -- Try to save current clipboard (may fail for some content types)
    set originalClipboard to missing value
    try
        set originalClipboard to the clipboard
    end try

    -- Parse commands
    set commands to {}
    if (count of argv) ≥ cmdStartIdx then
        repeat with i from cmdStartIdx to (count of argv)
            set end of commands to item i of argv
        end repeat
    end if

    -- Parse layout spec "1|2" into list {1, 2}
    set colCounts to parseColumnLayout(layoutSpec)
    set numCols to count of colCounts

    -- Calculate total panes per tab
    set panesPerTab to 0
    repeat with c in colCounts
        set panesPerTab to panesPerTab + c
    end repeat

    -- Activate Ghostty
    try
        tell application "Ghostty" to activate
    on error errMsg
        error "Cannot activate Ghostty: " & errMsg
    end try

    delay 0.3

    try
        tell application "System Events"
            if not (exists process "Ghostty") then
                error "Ghostty process not found. Is Ghostty running?"
            end if

            tell process "Ghostty"
                -- New window (unless reusing current)
                if reuseWindow is "false" then
                    keystroke "n" using {command down}
                    delay 1.0
                end if

                -- Ensure focused before starting setup
                set frontmost to true
                delay 0.5

                -- === TAB LOOP ===
                repeat with tabIdx from 1 to tabsCount

                    -- Create new tab if not the first tab
                    if tabIdx > 1 then
                        keystroke "t" using {command down}
                        delay 0.4
                    end if

                    -- Calculate command base index for this tab
                    set tabCmdBase to (tabIdx - 1) * panesPerTab

                    -- PHASE 1: Create column spine (n-1 horizontal splits)
                    if numCols > 1 then
                        repeat numCols - 1 times
                            keystroke "d" using {command down} -- Split right
                            delay 0.4
                        end repeat

                        -- Navigate to leftmost column
                        repeat numCols - 1 times
                            key code 123 using {command down, option down} -- Left
                            delay 0.3
                        end repeat
                    end if
                    delay 0.3

                    -- PHASE 2: Expand columns vertically and type commands inline
                    set spatialIdx to 1

                    repeat with colIdx from 1 to numCols
                        set rowsInCol to item colIdx of colCounts

                        -- Type command for this column's anchor (we're already here)
                        set cmdIndex to tabCmdBase + spatialIdx
                        if cmdIndex ≤ (count of commands) then
                            set cmd to item cmdIndex of commands
                            if cmd is not "" then
                                set the clipboard to cmd
                                keystroke "v" using {command down}
                                key code 36 -- Enter
                                delay 0.4
                            end if
                        end if
                        set spatialIdx to spatialIdx + 1

                        -- Create vertical splits and type commands for each new pane
                        if rowsInCol > 1 then
                            repeat rowsInCol - 1 times
                                keystroke "d" using {command down, shift down} -- Split down
                                delay 0.6

                                set cmdIndex to tabCmdBase + spatialIdx
                                if cmdIndex ≤ (count of commands) then
                                    set cmd to item cmdIndex of commands
                                    if cmd is not "" then
                                        set the clipboard to cmd
                                        keystroke "v" using {command down}
                                        key code 36 -- Enter
                                        delay 0.4
                                    end if
                                end if
                                set spatialIdx to spatialIdx + 1
                            end repeat
                        end if

                        -- Navigate to next column anchor (if not last column)
                        if colIdx < numCols then
                            delay 0.2
                            if rowsInCol > 1 then
                                repeat rowsInCol - 1 times
                                    key code 126 using {command down, option down} -- Up
                                    delay 0.15
                                end repeat
                            end if
                            key code 124 using {command down, option down} -- Right
                            delay 0.2
                        end if
                    end repeat

                    -- PHASE 3: Equalize splits
                    if panesPerTab > 1 then
                        key code 24 using {command down, control down}
                        delay 0.4
                    end if

                    -- PHASE 3.5: Resize columns with multiple rows
                    -- For each column that has >1 row, navigate to its top pane
                    -- and push the divider down to shrink the last row
                    -- First go to top-left
                    set maxRows to 0
                    repeat with c in colCounts
                        if c > maxRows then set maxRows to c
                    end repeat
                    repeat maxRows - 1 times
                        key code 126 using {command down, option down} -- Up
                        delay 0.1
                    end repeat
                    repeat numCols - 1 times
                        key code 123 using {command down, option down} -- Left
                        delay 0.1
                    end repeat
                    delay 0.2

                    repeat with colIdx from 1 to numCols
                        set rowsInCol to item colIdx of colCounts
                        if rowsInCol > 1 then
                            -- We're at the top pane of this column
                            -- Push divider down 8 times to shrink bottom pane
                            repeat 8 times
                                key code 125 using {command down, control down} -- Cmd+Ctrl+Down
                                delay 0.08
                            end repeat
                        end if
                        -- Move right to next column (if not last)
                        if colIdx < numCols then
                            key code 124 using {command down, option down} -- Right
                            delay 0.15
                        end if
                    end repeat

                    -- PHASE 4: Navigate to first pane (top-left)
                    delay 0.2
                    set maxRows to 0
                    repeat with c in colCounts
                        if c > maxRows then set maxRows to c
                    end repeat
                    repeat maxRows - 1 times
                        key code 126 using {command down, option down} -- Up
                        delay 0.12
                    end repeat
                    repeat numCols - 1 times
                        key code 123 using {command down, option down} -- Left
                        delay 0.12
                    end repeat

                end repeat
                -- === END TAB LOOP ===

                -- Return to Tab 1 for user convenience
                if tabsCount > 1 then
                    delay 0.2
                    keystroke "1" using {command down}
                    delay 0.2
                end if

            end tell
        end tell

        -- Success: Restore original clipboard if we saved it
        if originalClipboard is not missing value then
            try
                set the clipboard to originalClipboard
            end try
        end if

    on error errMsg
        -- Error: Restore clipboard before re-throwing
        if originalClipboard is not missing value then
            try
                set the clipboard to originalClipboard
            end try
        end if
        error errMsg
    end try
end run

-- Parse "1|2" into {1, 2}
on parseColumnLayout(spec)
    set AppleScript's text item delimiters to "|"
    set parts to text items of spec
    set AppleScript's text item delimiters to ""

    set colList to {}
    repeat with p in parts
        set end of colList to p as integer
    end repeat
    return colList
end parseColumnLayout
