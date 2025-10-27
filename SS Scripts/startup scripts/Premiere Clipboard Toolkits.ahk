#Requires AutoHotkey v2.0
#SingleInstance Force

SetWorkingDir(A_ScriptDir)
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

EnsureSlideKeyHelper()

; Paths for Premiere Clipboard helper utility
global gPremiereClipboardExe := "C:\Users\Tavito\Documents\Tavito and Mac\Editing\PremiereClipboard\PremiereClipboard.exe"
global gPremiereClipboardDir := "C:\Users\Tavito\Documents\Tavito and Mac\Editing\PremiereClipboard\SS Clipboard\"

#HotIf WinActive("ahk_exe Adobe Premiere Pro.exe")

; ------ Save Current Clipboard (Ctrl+Alt+Shift+/)
^!+vkBF::SavePremiereClipboard("Example_Name")

; ------ Load Saved Clipboards via Win+Ctrl(+Shift) combos mapped to numpad
#^F13::LoadPremiereClipboard("SSWATERMARK")                  ; Num 0  (unused)
#^F14::LoadPremiereClipboard("SSnarratortext")       ; Num 1
#^F15::LoadPremiereClipboard("SSblurmoslideUP")      ; Num 2
#^F16::LoadPremiereClipboard("SSblurmoslideDOWN")    ; Num 3
#^F17::LoadPremiereClipboard("SSblurmoslideRIGHT")   ; Num 4
#^F18::LoadPremiereClipboard("SSblurmoslideLEFT")    ; Num 5
#^+F20::LoadPremiereClipboard("N/A")                 ; Num 6 (safe override)
#^F20::LoadPremiereClipboard("N/A")                  ; Num 7
#^+F21::LoadPremiereClipboard("N/A")                 ; Num 8 (safe override)
#^+F22::LoadPremiereClipboard("N/A")                 ; Num 9 (safe override)
#^F23::LoadPremiereClipboard("N/A")                  ; Num .  (unused)

; Numpad divide triggers Excalibur helper (Win+Alt+Shift+F20)
NumpadDiv::SendEvent("#!+{F20}")

; Pin to Clip helper (Ctrl+Shift+Win+F19 enforces disabled state)
^#+F19::EnsurePinToClipDisabled()

#HotIf

SavePremiereClipboard(clipName) {
    global gPremiereClipboardExe, gPremiereClipboardDir
    if (clipName = "" || clipName = "N/A") {
        MsgBox("Please supply a valid name before saving the Premiere clipboard.")
        return
    }

    WinActivate("Adobe Premiere Pro")
    Sleep(300)

    command := '"' . gPremiereClipboardExe . '" --save "' . gPremiereClipboardDir . clipName . '"'
    RunWait(command, , "Hide")
    Sleep(150)

    NotifyPinToClip("Premiere Clipboard", "Saved clipboard as " . clipName . ".", 2500)
}

LoadPremiereClipboard(clipName) {
    global gPremiereClipboardExe, gPremiereClipboardDir
    if (clipName = "" || clipName = "N/A") {
        MsgBox("No clipboard file assigned to this hotkey!")
        return
    }

    filePath := gPremiereClipboardDir . clipName
    if !FileExist(filePath) {
        MsgBox("Clipboard preset not found:`n" . filePath)
        return
    }

    WinActivate("Adobe Premiere Pro")
    Sleep(200)

    BlockInput("SendAndMouse")
    BlockInput("MouseMove")
    BlockInput("On")

    RunWait('"' . gPremiereClipboardExe . '" --fill', , "Hide")
    Sleep(200)
    Send("!{Tab}")
    Sleep(200)
    Send("!{Tab}")
    Sleep(100)

    RunWait('"' . gPremiereClipboardExe . '" --load "' . filePath . '"', , "Hide")
    Sleep(20)
    Send("^+a")
    Sleep(10)

    Send("{Shift down}")
    Send("{Shift up}")
    Send("{vkDE down}")
    Sleep(5)
    Send("{vkDE up}")
    Sleep(10)

    BlockInput("MouseMoveOff")
    BlockInput("Off")
}

EnsurePinToClipDisabled(*) {
    config := PinToClip_LoadConfig()
    if (!IsObject(config)) {
        NotifyPinToClip("Pin to Clip", "Capture positions in the Premiere Position Manager before using this hotkey.", 3200)
        return
    }

    WinActivate("Adobe Premiere Pro")
    Sleep(60)

    BlockInput("SendAndMouse")
    BlockInput("MouseMove")
    BlockInput("On")

    MouseGetPos(&originalX, &originalY)
    try {
        OpenPinToClipMenu(config)
        ClickPinToClipEntry(config)
        Sleep(120)
        Send("{Esc}")
        NotifyPinToClip("Pin to Clip", "Pin to Clip toggled.")
    } catch as err {
        try Send("{Esc}")
        NotifyPinToClip("Pin to Clip", "Error: " . err.Message, 3500)
    } finally {
        MoveMouseInstant(originalX, originalY)
        BlockInput("MouseMoveOff")
        BlockInput("Off")
    }
}
NotifyPinToClip(title, message, duration := 2500) {
    TrayTip(title, message)
    SetTimer(PinToClip_ClearTrayTip, -duration)
}

MoveMouseInstant(x, y) {
    DllCall("SetCursorPos", "int", Round(x), "int", Round(y))
}

OpenPinToClipMenu(config) {
    MoveMouseInstant(config["HamburgerX"], config["HamburgerY"])
    Sleep(70)
    Click()
    Sleep(180)
}

ClickPinToClipEntry(config) {
    x := config.Has("CheckX") ? config["CheckX"] : config["MenuX"]
    y := config.Has("CheckY") ? config["CheckY"] : config["MenuY"]
    MoveMouseInstant(x, y)
    Sleep(90)
    Click()
    Sleep(180)
}

PinToClip_LoadConfig() {
    iniPath := PinToClip_ConfigPath()
    if !FileExist(iniPath) {
        return false
    }

    required := ['HamburgerX', 'HamburgerY', 'MenuX', 'MenuY']
    config := Map()

    try {
        for key in required {
            value := IniRead(iniPath, 'Positions', key, '')
            if !PinToClip_IsInteger(value) {
                return false
            }
            config[key] := Integer(value)
        }

        for optionalKey in ['CheckX', 'CheckY'] {
            value := IniRead(iniPath, 'Positions', optionalKey, '')
            if PinToClip_IsInteger(value) {
                config[optionalKey] := Integer(value)
            }
        }
    } catch {
        return false
    }

    return config
}

PinToClip_ConfigPath() {
    return A_ScriptDir . '\PremierePinToClip.ini'
}

PinToClip_IsInteger(value) {
    return (value != '' && RegExMatch(value, '^[+-]?\d+$'))
}

PinToClip_ClearTrayTip(*) {
    TrayTip()
}

EnsureSlideKeyHelper() {
    scriptPath := A_ScriptDir . "\..\slidekey gusss.py"
    if !FileExist(scriptPath) {
        return
    }
    if WinExist("Mouse Axis Lock ahk_class TkTopLevel") {
        return
    }
    try {
        Run('pythonw.exe "' . scriptPath . '"', A_ScriptDir . "\..", "Hide")
        return
    } catch {
    }
    try {
        Run('python.exe "' . scriptPath . '"', A_ScriptDir . "\..", "Hide")
    } catch {
    }
}



