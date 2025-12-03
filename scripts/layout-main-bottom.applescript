-- gsx main+bottom layout: top | bottom
on run argv
  set projectDir to item 1 of argv
  set cmdTop to item 2 of argv
  set cmdBottom to item 3 of argv

  try
    tell application "Ghostty" to activate
  on error errMsg
    error "Cannot activate Ghostty: " & errMsg
  end try

  delay 0.3

  tell application "System Events"
    if not (exists process "Ghostty") then
      error "Ghostty process not found"
    end if

    tell process "Ghostty"
      keystroke "n" using {command down}
      delay 0.6

      set projectDirQuoted to "'" & projectDir & "'"
      keystroke "cd " & projectDirQuoted
      key code 36
      delay 0.3

      keystroke "d" using {command down, shift down}
      delay 0.25

      keystroke "[" using {command down}
      delay 0.2

      if cmdTop is not "" then
        keystroke cmdTop
        key code 36
        delay 0.35
      end if

      keystroke "]" using {command down}
      delay 0.2

      if cmdBottom is not "" then
        keystroke cmdBottom
        key code 36
        delay 0.35
      end if
    end tell
  end tell
end run
