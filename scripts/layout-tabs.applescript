-- gsx tabs layout: creates multiple tabs, one command per tab
-- Args: projectDir, cmd1, cmd2, cmd3, ...
-- First tab uses existing tab in new window, subsequent tabs use Cmd+T

on run argv
    set projectDir to item 1 of argv

    -- Parse commands (items 2 onward)
    set commands to {}
    if (count of argv) > 1 then
        repeat with i from 2 to (count of argv)
            set end of commands to item i of argv
        end repeat
    end if

    set numTabs to count of commands

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
            -- New window (this gives us the first tab)
            keystroke "n" using {command down}
            delay 0.6

            -- Process each tab
            repeat with tabIdx from 1 to numTabs
                -- For tabs after the first, create a new tab
                if tabIdx > 1 then
                    keystroke "t" using {command down}
                    delay 0.4
                end if

                -- cd to project directory
                keystroke "cd " & quoted form of projectDir
                key code 36 -- Enter
                delay 0.3

                -- Run command if provided
                if tabIdx <= (count of commands) then
                    set cmd to item tabIdx of commands
                    if cmd is not "" then
                        keystroke cmd
                        key code 36 -- Enter
                        delay 0.25
                    end if
                end if
            end repeat

            -- Go back to first tab (Cmd+1)
            delay 0.2
            keystroke "1" using {command down}
        end tell
    end tell
end run
