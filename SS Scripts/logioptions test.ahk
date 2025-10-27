#Requires AutoHotkey v2.0
F3:: {
    Sleep(2000)  ; Gives you 2 seconds to focus the shortcut field
    Send("{Ctrl down}{LWin down}{Alt down}{F24 down}")
    Sleep(100)
    Send("{F24 up}{Alt up}{LWin up}{Ctrl up}")
}