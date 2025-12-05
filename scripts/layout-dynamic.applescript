-- gsx dynamic layout: handles any row-based pane configuration
-- Args: projectDir, layoutSpec, cmd1, cmd2, cmd3, ...
-- layoutSpec: "2-2" or "1-3" etc.
-- Commands are in SPATIAL order (left-to-right, top-to-bottom)
-- Commands are typed DURING Phase 2, eliminating unreliable Phase 4 navigation

on run argv
    set projectDir to item 1 of argv
    set layoutSpec to item 2 of argv

    -- Parse commands (items 3 onward)
    set commands to {}
    if (count of argv) > 2 then
        repeat with i from 3 to (count of argv)
            set end of commands to item i of argv
        end repeat
    end if

    -- Parse layout spec "2-2" into list {2, 2}
    set rowCounts to parseLayout(layoutSpec)
    set numRows to count of rowCounts

    -- Calculate total panes
    set totalPanes to 0
    repeat with r in rowCounts
        set totalPanes to totalPanes + r
    end repeat

    -- Activate Ghostty
    try
        tell application "Ghostty" to activate
    on error errMsg
        error "Cannot activate Ghostty: " & errMsg
    end try

    delay 0.3

    tell application "System Events"
        if not (exists process "Ghostty") then
            error "Ghostty process not found. Is Ghostty running?"
        end if

        tell process "Ghostty"
            -- New window
            keystroke "n" using {command down}
            delay 0.6

            -- cd to project directory (this is pane 1, spatial position 0)
            -- Use quoted form to safely handle paths with apostrophes/special chars
            keystroke "cd " & quoted form of projectDir
            key code 36 -- Enter
            delay 0.3

            -- PHASE 1: Create row spine (n-1 vertical splits)
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

            -- PHASE 2: Expand rows and type commands inline
            -- Visit order matches spatial order: row by row, left to right
            -- We type each command immediately when we're in that pane
            set spatialIdx to 1 -- 1-based index into commands array

            repeat with rowIdx from 1 to numRows
                set panesInRow to item rowIdx of rowCounts

                -- Type command for this row's anchor (we're already here)
                if spatialIdx <= (count of commands) then
                    set cmd to item spatialIdx of commands
                    if cmd is not "" then
                        keystroke cmd
                        key code 36 -- Enter
                        delay 0.25
                    end if
                end if
                set spatialIdx to spatialIdx + 1

                -- Create horizontal splits and type commands for each new pane
                if panesInRow > 1 then
                    repeat panesInRow - 1 times
                        keystroke "d" using {command down} -- Split right
                        delay 0.4

                        -- Now in the new split pane, type its command
                        if spatialIdx <= (count of commands) then
                            set cmd to item spatialIdx of commands
                            if cmd is not "" then
                                keystroke cmd
                                key code 36 -- Enter
                                delay 0.25
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

            -- PHASE 3: Equalize splits
            if totalPanes > 1 then
                key code 24 using {command down, control down}
                delay 0.4
            end if

            -- PHASE 4: Navigate to first pane (optional, for user convenience)
            -- Go to top-left pane so user starts at a predictable position
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
        end tell
    end tell
end run

-- Parse "2-2" into {2, 2}
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
