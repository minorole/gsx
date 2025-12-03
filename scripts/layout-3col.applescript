-- gsx 3-column layout: left | middle | right
on run argv
  set projectDir to item 1 of argv
  set cmdLeft to item 2 of argv
  set cmdMiddle to item 3 of argv
  set cmdRight to item 4 of argv

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
      keystroke "n" using {command down}
      delay 0.6

      set projectDirQuoted to "'" & projectDir & "'"
      keystroke "cd " & projectDirQuoted
      key code 36
      delay 0.3

      keystroke "d" using {command down}
      delay 0.25
      keystroke "d" using {command down}
      delay 0.25

      key code 24 using {command down, control down}
      delay 0.6

      keystroke "[" using {command down}
      delay 0.2
      keystroke "[" using {command down}
      delay 0.2

      if cmdLeft is not "" then
        keystroke cmdLeft
        key code 36
        delay 0.35
      end if

      keystroke "]" using {command down}
      delay 0.2

      if cmdMiddle is not "" then
        keystroke cmdMiddle
        key code 36
        delay 0.35
      end if

      keystroke "]" using {command down}
      delay 0.2

      if cmdRight is not "" then
        keystroke cmdRight
        key code 36
        delay 0.35
      end if
    end tell
  end tell
end run
