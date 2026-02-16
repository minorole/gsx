-- gpane hybrid layout: multiple tabs, each with pane splits
-- Args: reuseWindow, projectDir, layoutSpec, tabsCount, cmd1, cmd2, cmd3, ...
-- reuseWindow: "true" to use current window, "false" to create new
-- layoutSpec: "2" (duo), "3" (trio), "2-2" (quad) - applied to EACH tab
-- tabsCount: number of tabs to create (integer as string)
-- Commands are in order: tab1-pane1, tab1-pane2, ..., tab2-pane1, tab2-pane2, ...
-- Commands are typed DURING pane creation for reliability

on run argv
    set reuseWindow to item 1 of argv
    set projectDir to item 2 of argv
    set layoutSpec to item 3 of argv
    set tabsCount to (item 4 of argv) as integer

    -- Try to save current clipboard (may fail for some content types)
    set originalClipboard to missing value
    try
        set originalClipboard to the clipboard
    end try

    -- Parse commands (items 5 onward)
    set commands to {}
    if (count of argv) > 4 then
        repeat with i from 5 to (count of argv)
            set end of commands to item i of argv
        end repeat
    end if

    -- Parse layout spec "2-2" into list {2, 2}
    set rowCounts to parseLayout(layoutSpec)
    set numRows to count of rowCounts

    -- Calculate total panes per tab
    set panesPerTab to 0
    repeat with r in rowCounts
        set panesPerTab to panesPerTab + r
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
                    delay 1.0 -- Reliable window creation delay
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
                    -- cmdIndex = (tabIdx - 1) * panesPerTab + spatialIdx
                    set tabCmdBase to (tabIdx - 1) * panesPerTab

                    -- === PHASE 1: Create row spine (n-1 vertical splits) ===
                    -- This creates one anchor pane per row
                    if numRows > 1 then
                        repeat numRows - 1 times
                            keystroke "d" using {command down, shift down}
                            delay 0.4
                        end repeat

                        -- Navigate to top row using directional navigation
                        repeat numRows - 1 times
                            key code 126 using {command down, option down} -- Up
                            delay 0.3
                        end repeat
                    end if
                    delay 0.3

                    -- === PHASE 2: Expand rows and type commands inline ===
                    -- Visit order matches spatial order: row by row, left to right
                    -- We type each command immediately when we're in that pane
                    set spatialIdx to 1 -- 1-based index within current tab

                    repeat with rowIdx from 1 to numRows
                        set panesInRow to item rowIdx of rowCounts

                        -- Type command for this row's anchor (we're already here)
                        set cmdIndex to tabCmdBase + spatialIdx
                        if cmdIndex <= (count of commands) then
                            set cmd to item cmdIndex of commands
                            if cmd is not "" then
                                set the clipboard to cmd
                                keystroke "v" using {command down}
                                key code 36 -- Enter
                                delay 0.4 -- Reliable completion delay
                            end if
                        end if
                        set spatialIdx to spatialIdx + 1

                        -- Create horizontal splits and type commands for each new pane
                        if panesInRow > 1 then
                            repeat panesInRow - 1 times
                                keystroke "d" using {command down} -- Split right
                                delay 0.6 -- Increased for split stability

                                -- Now in the new split pane, type its command
                                set cmdIndex to tabCmdBase + spatialIdx
                                if cmdIndex <= (count of commands) then
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

                        -- Navigate to next row anchor (if not last row)
                        if rowIdx < numRows then
                            delay 0.2
                            -- Go LEFT back to col 0 of current row
                            if panesInRow > 1 then
                                repeat panesInRow - 1 times
                                    key code 123 using {command down, option down} -- Left
                                    delay 0.15
                                end repeat
                            end if
                            -- Go DOWN to next row
                            key code 125 using {command down, option down} -- Down
                            delay 0.2
                        end if
                    end repeat

                    -- === PHASE 3: Equalize splits ===
                    if panesPerTab > 1 then
                        key code 24 using {command down, control down}
                        delay 0.4
                    end if

                    -- === PHASE 4: Navigate to first pane of this tab ===
                    -- Position cursor at top-left for consistency
                    delay 0.2
                    repeat numRows - 1 times
                        key code 126 using {command down, option down} -- Up
                        delay 0.12
                    end repeat
                    set maxCols to 0
                    repeat with r in rowCounts
                        if r > maxCols then set maxCols to r
                    end repeat
                    repeat maxCols - 1 times
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

-- Parse "2-2" into {2, 2}, "3" into {3}
on parseLayout(spec)
    set AppleScript's text item delimiters to "-"
    set parts to text items of spec
    set AppleScript's text item delimiters to ""

    set rowList to {}
    repeat with p in parts
        set end of rowList to p as integer
    end repeat
    return rowList
end parseLayout
