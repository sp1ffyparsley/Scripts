; AutoHotkey v2 - Premiere Pro Effects Automation Enhanced
#Requires AutoHotkey v2.0+
TraySetIcon(A_ScriptDir . '\\..\\assets\\icons\\tray_premiere.ico')
SetWorkingDir(A_ScriptDir)

; Set coordinate mode at startup
CoordMode("Mouse", "Screen")
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)

; === CONFIGURATION SECTION ===
; Easy to edit - just set enabled to false to disable any hotkey
; Add new effects by following the pattern below

global effects := Map()
global DEFAULT_EFFECT_NAME := "__DEFAULT__"
global EFFECT_STATUS_ICONS := Map(
    'custom', 'Custom',
    'default', 'Default',
    'none', 'None'
)

CapsModifierDown() {
    return GetKeyState("CapsLock", "P")
}

CapsModifierActive(*) {
    return CapsModifierDown() && IsPremiereActive()
}

CapsModifierInactive(*) {
    return !CapsModifierDown() && IsPremiereActive()
}

; Function to easily add effects - name is what you type in search
AddEffect(key, modifiers, name, enabled := true) {
    global effects
    if (!enabled) {
        return  ; Skip disabled effects
    }
    
    fullKey := (modifiers != "" ? modifiers . "+" : "") . key
    effects[fullKey] := Map(
        "name", name,
        "key", key,
        "modifiers", modifiers,
        "enabled", enabled
    )
}

ShowTimedTray(title, message, duration := 2000) {
    TrayTip(title, message, "Mute")
    SetTimer(() => TrayTip(), -duration)
}

GetEffectDisplayName(effect) {
    if (!IsObject(effect) || !effect.Has("name")) {
        return ""
    }
    return effect["name"] = DEFAULT_EFFECT_NAME ? "Default Positions" : effect["name"]
}

GetEffectIniPath(effectName) {
    sanitized := StrReplace(effectName, " ", "_")
    return A_ScriptDir . "\" . "effect_" . sanitized . ".ini"
}

ReadEffectCoordinate(iniFile, key) {
    value := Trim(IniRead(iniFile, "Positions", key, ""))
    if (value = "" || !RegExMatch(value, "^-?\d+$")) {
        throw Error("Missing or invalid coordinate for " . key . " in " . iniFile)
    }
    return Integer(value)
}

MoveMouseInstant(x, y) {
    DllCall("SetCursorPos", "int", Round(x), "int", Round(y))
}

ClickAt(x, y) {
    MoveMouseInstant(x, y)
    Click()
}

DragInstant(x1, y1, x2, y2) {
    MoveMouseInstant(x1, y1)
    Click("L Down")
    Sleep(10)
    MoveMouseInstant(x2, y2)
    Sleep(10)
    Click("L Up")
}

GetEffectPositionStatus(effect) {
    if (!IsObject(effect) || !effect.Has("name")) {
        return "none"
    }
    effectFile := GetEffectIniPath(effect["name"])
    if FileExist(effectFile) {
        return "custom"
    }
    defaultFile := GetDefaultIniFile()
    if FileExist(defaultFile) {
        return "default"
    }
    return "none"
}

GetStatusLabel(status) {
    global EFFECT_STATUS_ICONS
    if EFFECT_STATUS_ICONS.Has(status) {
        return EFFECT_STATUS_ICONS[status]
    }
    return status
}

GetSortedEffects() {
    global effects
    sortedEffects := []
    modifierOrder := [
        "", "Shift", "Ctrl", "Alt",
        "Ctrl+Shift", "Ctrl+Alt", "Alt+Shift", "Ctrl+Shift+Alt",
        "Caps", "Caps+Shift", "Caps+Ctrl", "Caps+Alt",
        "Caps+Ctrl+Shift", "Caps+Ctrl+Alt", "Caps+Alt+Shift", "Caps+Ctrl+Alt+Shift"
    ]

    loop 24 {
        fNum := A_Index
        for modifier in modifierOrder {
            fullKey := (modifier != "" ? modifier . "+" : "") . "F" . fNum
            if (effects.Has(fullKey) && effects[fullKey]["enabled"]) {
                sortedEffects.Push(effects[fullKey])
            }
        }
    }
    return sortedEffects
}

PopulateEffectSelectors(gui) {
    sortedEffects := GetSortedEffects()
    try lv := gui["EffectList"]
    if IsObject(lv) {
        lv.Delete()
        for effect in sortedEffects {
            displayKey := effect["modifiers"] != "" ? effect["modifiers"] . "+" . effect["key"] : effect["key"]
            status := GetStatusLabel(GetEffectPositionStatus(effect))
            lv.Add("", displayKey, effect["name"], status)
        }
        lv.ModifyCol(1, "120")
        lv.ModifyCol(2, "300")
        lv.ModifyCol(3, "80")
    }

    try combo := gui["EffectChoice"]
    if IsObject(combo) {
        combo.Delete()
        for effect in sortedEffects {
            displayKey := effect["modifiers"] != "" ? effect["modifiers"] . "+" . effect["key"] : effect["key"]
            status := GetStatusLabel(GetEffectPositionStatus(effect))
            combo.Add([effect["name"] . " (" . displayKey . ")  " . status])
        }
        if (combo.Value = "" && sortedEffects.Length > 0) {
            combo.Choose(1)
        }
    }
    return sortedEffects
}

GetSelectedEffectFromGui(gui) {
    try combo := gui["EffectChoice"]
    if !IsObject(combo) {
        return ""
    }
    selectedText := combo.Text
    effectName := RegExReplace(selectedText, " \([^)]*\).*")
    return GetEffectByName(effectName)
}

LoadDefaultFields(gui) {
    fields := ["SearchX", "SearchY", "IconX", "IconY"]
    defaultFile := GetDefaultIniFile()
    for field in fields {
        controlName := "Default" . field
        try ctrl := gui[controlName]
        if IsObject(ctrl) {
            ctrl.Value := ""
        }
    }
    if !FileExist(defaultFile) {
        return
    }
    try {
        for field in fields {
            controlName := "Default" . field
            try ctrl := gui[controlName]
            if IsObject(ctrl) {
                ctrl.Value := ReadEffectCoordinate(defaultFile, field)
            }
        }
    } catch {
        ; leave fields blank on error
    }
}

SaveDefaultFields(gui) {
    fields := ["SearchX", "SearchY", "IconX", "IconY"]
    values := Map()
    for field in fields {
        controlName := "Default" . field
        try ctrl := gui[controlName]
        if !IsObject(ctrl) {
            continue
        }
        rawValue := Trim(ctrl.Value)
        if (rawValue = "" || !RegExMatch(rawValue, "^-?\d+$")) {
            MsgBox("Please enter a valid integer for " . field . ".", "Invalid Value", "OK Icon!")
            return
        }
        values[field] := Integer(rawValue)
    }

    if (values.Count != fields.Length) {
        MsgBox("All default position fields must be provided.", "Incomplete Data", "OK Icon!")
        return
    }

    defaultFile := GetDefaultIniFile()
    for field, value in values {
        IniWrite(value, defaultFile, "Positions", field)
    }
    ShowTimedTray("Effect Picker", "Default positions saved.", 2000)
    RefreshEffectGui()
}

ClearDefaultPositions(gui) {
    defaultFile := GetDefaultIniFile()
    if FileExist(defaultFile) {
        FileDelete(defaultFile)
    }
    LoadDefaultFields(gui)
    ShowTimedTray("Effect Picker", "Default positions cleared.", 2000)
    RefreshEffectGui()
}

ClearSelectedEffectPositions(gui) {
    effect := GetSelectedEffectFromGui(gui)
    if !IsObject(effect) {
        MsgBox("Please select a valid effect.", "Error", "OK Icon!")
        return
    }
    iniFile := GetEffectIniPath(effect["name"])
    if FileExist(iniFile) {
        FileDelete(iniFile)
        for key in ["searchX", "searchY", "iconX", "iconY"] {
            if effect.Has(key) {
                effect.Delete(key)
            }
        }
        ShowTimedTray("Effect Picker", "Positions cleared for " . effect["name"] . ".", 2000)
    } else {
        ShowTimedTray("Effect Picker", "No saved positions for " . effect["name"] . ".", 2000)
    }
    RefreshEffectGui()
}

RefreshEffectGui() {
    global effectGui
    if !(effectGui && IsObject(effectGui)) {
        return
    }
    PopulateEffectSelectors(effectGui)
    LoadDefaultFields(effectGui)
}

HasDefaultPositions() {
    defaultFile := GetDefaultIniFile()
    return FileExist(defaultFile)
}

; === ADD YOUR EFFECTS HERE - SUPER EASY! ===
; Format: AddEffect("Key", "Modifiers", "Exact Effect Name", enabled)
; Modifiers can be: "", "Shift", "Ctrl", "Alt", "Ctrl+Shift", "Ctrl+Alt", "Alt+Shift", "Ctrl+Shift+Alt", "Caps", and any Caps combinations.

; F1 Effects
AddEffect("F1", "", "Transform", true)
AddEffect("F1", "Shift", "S_Shake", true)
AddEffect("F1", "Ctrl", "S_BlurMoCurves", true)
AddEffect("F1", "Alt", "HFLIP", true)
AddEffect("F1", "Ctrl+Shift", "SS beg zoom out fast", true)
AddEffect("F1", "Ctrl+Alt", "SS txt deep glow", true)
AddEffect("F1", "Alt+Shift", "N/A", false)
AddEffect("F1", "Ctrl+Shift+Alt", "Tint", true)
AddEffect("F1", "Caps", "N/A", false)
AddEffect("F1", "Caps+Shift", "N/A", false)
AddEffect("F1", "Caps+Ctrl", "N/A", false)
AddEffect("F1", "Caps+Alt", "N/A", false)
AddEffect("F1", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F1", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F1", "Caps+Alt+Shift", "N/A", false)
AddEffect("F1", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F2 Effects
AddEffect("F2", "", "SS txt blrmo .75-1 ST", true)
AddEffect("F2", "Shift", "SS txt blrmo 1.5-.8", true)
AddEffect("F2", "Ctrl", "SS Fade In", true)
AddEffect("F2", "Alt", "SS Fade Out", true)
AddEffect("F2", "Ctrl+Shift", "SS txt blrmo zoom out END", true)
AddEffect("F2", "Ctrl+Alt", "SS txt blrmo zoom out END", true)
AddEffect("F2", "Alt+Shift", "SS txt normal to zoom in", true)
AddEffect("F2", "Ctrl+Shift+Alt", "SS txt Narrator Effects", true)
AddEffect("F2", "Caps", "SS txt blrmo big to normal", true)
AddEffect("F2", "Caps+Shift", "N/A", false)
AddEffect("F2", "Caps+Ctrl", "N/A", false)
AddEffect("F2", "Caps+Alt", "N/A", false)
AddEffect("F2", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F2", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F2", "Caps+Alt+Shift", "N/A", false)
AddEffect("F2", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F3 Effects
AddEffect("F3", "", "N/A", false)
AddEffect("F3", "Shift", "N/A", false)
AddEffect("F3", "Ctrl", "N/A", false)
AddEffect("F3", "Alt", "N/A", false)
AddEffect("F3", "Ctrl+Shift", "N/A", false)
AddEffect("F3", "Ctrl+Alt", "N/A", false)
AddEffect("F3", "Alt+Shift", "N/A", false)
AddEffect("F3", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F3", "Caps", "N/A", false)
AddEffect("F3", "Caps+Shift", "N/A", false)
AddEffect("F3", "Caps+Ctrl", "N/A", false)
AddEffect("F3", "Caps+Alt", "N/A", false)
AddEffect("F3", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F3", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F3", "Caps+Alt+Shift", "N/A", false)
AddEffect("F3", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F4 Effects
AddEffect("F4", "", "ss sigma shaky", true)
AddEffect("F4", "Shift", "SS Soft r shake #1", true)
AddEffect("F4", "Ctrl", "SS Y shke K-S", true)
AddEffect("F4", "Alt", "N/A", false)
AddEffect("F4", "Ctrl+Shift", "N/A", false)
AddEffect("F4", "Ctrl+Alt", "N/A", false)
AddEffect("F4", "Alt+Shift", "N/A", false)
AddEffect("F4", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F4", "Caps", "N/A", false)
AddEffect("F4", "Caps+Shift", "N/A", false)
AddEffect("F4", "Caps+Ctrl", "N/A", false)
AddEffect("F4", "Caps+Alt", "N/A", false)
AddEffect("F4", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F4", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F4", "Caps+Alt+Shift", "N/A", false)
AddEffect("F4", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F5 Effects
AddEffect("F5", "", "N/A", false)
AddEffect("F5", "Shift", "N/A", false)
AddEffect("F5", "Ctrl", "N/A", false)
AddEffect("F5", "Alt", "N/A", false)
AddEffect("F5", "Ctrl+Shift", "N/A", false)
AddEffect("F5", "Ctrl+Alt", "N/A", false)
AddEffect("F5", "Alt+Shift", "N/A", false)
AddEffect("F5", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F5", "Caps", "N/A", false)
AddEffect("F5", "Caps+Shift", "N/A", false)
AddEffect("F5", "Caps+Ctrl", "N/A", false)
AddEffect("F5", "Caps+Alt", "N/A", false)
AddEffect("F5", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F5", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F5", "Caps+Alt+Shift", "N/A", false)
AddEffect("F5", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F6 Effects
AddEffect("F6", "", "SS txt blrmo right", true)
AddEffect("F6", "Shift", "SS txt blrmo left", true)
AddEffect("F6", "Ctrl", "SS txt blrmo UP", true)
AddEffect("F6", "Alt", "SS txt blrmo down END", true)
AddEffect("F6", "Ctrl+Shift", "N/A", false)
AddEffect("F6", "Ctrl+Alt", "N/A", false)
AddEffect("F6", "Alt+Shift", "N/A", false)
AddEffect("F6", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F6", "Caps", "N/A", false)
AddEffect("F6", "Caps+Shift", "N/A", false)
AddEffect("F6", "Caps+Ctrl", "N/A", false)
AddEffect("F6", "Caps+Alt", "N/A", false)
AddEffect("F6", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F6", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F6", "Caps+Alt+Shift", "N/A", false)
AddEffect("F6", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F7 Effects*
AddEffect("F7", "", "N/A", false)
AddEffect("F7", "Shift", "N/A", false)
AddEffect("F7", "Ctrl", "N/A", false)
AddEffect("F7", "Alt", "N/A", false)
AddEffect("F7", "Ctrl+Shift", "N/A", false)
AddEffect("F7", "Ctrl+Alt", "N/A", false)
AddEffect("F7", "Alt+Shift", "N/A", false)
AddEffect("F7", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F7", "Caps", "N/A", false)
AddEffect("F7", "Caps+Shift", "N/A", false)
AddEffect("F7", "Caps+Ctrl", "N/A", false)
AddEffect("F7", "Caps+Alt", "N/A", false)
AddEffect("F7", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F7", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F7", "Caps+Alt+Shift", "N/A", false)
AddEffect("F7", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F8 Effects*
AddEffect("F8", "", "N/A", false)
AddEffect("F8", "Shift", "N/A", false)
AddEffect("F8", "Ctrl", "N/A", false)
AddEffect("F8", "Alt", "N/A", false)
AddEffect("F8", "Ctrl+Shift", "N/A", false)
AddEffect("F8", "Ctrl+Alt", "N/A", false)
AddEffect("F8", "Alt+Shift", "N/A", false)
AddEffect("F8", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F8", "Caps", "N/A", false)
AddEffect("F8", "Caps+Shift", "N/A", false)
AddEffect("F8", "Caps+Ctrl", "N/A", false)
AddEffect("F8", "Caps+Alt", "N/A", false)
AddEffect("F8", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F8", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F8", "Caps+Alt+Shift", "N/A", false)
AddEffect("F8", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F9 Effects*
AddEffect("F9", "", "N/A", false)
AddEffect("F9", "Shift", "N/A", false)
AddEffect("F9", "Ctrl", "N/A", false)
AddEffect("F9", "Alt", "N/A", false)
AddEffect("F9", "Ctrl+Shift", "N/A", false)
AddEffect("F9", "Ctrl+Alt", "N/A", false)
AddEffect("F9", "Alt+Shift", "N/A", false)
AddEffect("F9", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F9", "Caps", "N/A", false)
AddEffect("F9", "Caps+Shift", "N/A", false)
AddEffect("F9", "Caps+Ctrl", "N/A", false)
AddEffect("F9", "Caps+Alt", "N/A", false)
AddEffect("F9", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F9", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F9", "Caps+Alt+Shift", "N/A", false)
AddEffect("F9", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F10 Effects*
AddEffect("F10", "", "N/A", false)
AddEffect("F10", "Shift", "N/A", false)
AddEffect("F10", "Ctrl", "N/A", false)
AddEffect("F10", "Alt", "N/A", false)
AddEffect("F10", "Ctrl+Shift", "N/A", false)
AddEffect("F10", "Ctrl+Alt", "N/A", false)
AddEffect("F10", "Alt+Shift", "N/A", false)
AddEffect("F10", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F10", "Caps", "N/A", false)
AddEffect("F10", "Caps+Shift", "N/A", false)
AddEffect("F10", "Caps+Ctrl", "N/A", false)
AddEffect("F10", "Caps+Alt", "N/A", false)
AddEffect("F10", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F10", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F10", "Caps+Alt+Shift", "N/A", false)
AddEffect("F10", "Caps+Ctrl+Alt+Shift", "N/A", false)

;TRANSITIONS  F11 Effects*
AddEffect("F11", "", "Morph Cut", true)
AddEffect("F11", "Shift", "N/A", false)
AddEffect("F11", "Ctrl", "N/A", false)
AddEffect("F11", "Alt", "N/A", false)
AddEffect("F11", "Ctrl+Shift", "N/A", false)
AddEffect("F11", "Ctrl+Alt", "N/A", false)
AddEffect("F11", "Alt+Shift", "N/A", false)
AddEffect("F11", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F11", "Caps", "N/A", false)
AddEffect("F11", "Caps+Shift", "N/A", false)
AddEffect("F11", "Caps+Ctrl", "N/A", false)
AddEffect("F11", "Caps+Alt", "N/A", false)
AddEffect("F11", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F11", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F11", "Caps+Alt+Shift", "N/A", false)
AddEffect("F11", "Caps+Ctrl+Alt+Shift", "N/A", false)

; TINTS F12 Effects*
AddEffect("F12", "", "SS blck and whte tint", true)
AddEffect("F12", "Shift", "ss SS Green TINT", true)
AddEffect("F12", "Ctrl", "ss Red TINT", true)
AddEffect("F12", "Alt", "ss Pink TINT", true)
AddEffect("F12", "Ctrl+Shift", "N/A", false)
AddEffect("F12", "Ctrl+Alt", "N/A", false)
AddEffect("F12", "Alt+Shift", "N/A", false)
AddEffect("F12", "Ctrl+Shift+Alt", "N/A", false)
AddEffect("F12", "Caps", "N/A", false)
AddEffect("F12", "Caps+Shift", "N/A", false)
AddEffect("F12", "Caps+Ctrl", "N/A", false)
AddEffect("F12", "Caps+Alt", "N/A", false)
AddEffect("F12", "Caps+Ctrl+Shift", "N/A", false)
AddEffect("F12", "Caps+Ctrl+Alt", "N/A", false)
AddEffect("F12", "Caps+Alt+Shift", "N/A", false)
AddEffect("F12", "Caps+Ctrl+Alt+Shift", "N/A", false)

; F13 Effects*
AddEffect("F13", "", "N/A", false)
AddEffect("F13", "Shift", "N/A", false)
AddEffect("F13", "Ctrl", "N/A", false)
AddEffect("F13", "Alt", "N/A", false)
AddEffect("F13", "Shift+Ctrl+Alt", "N/A", false)

; F14 Effects*
AddEffect("F14", "", "N/A", false)
AddEffect("F14", "Shift", "N/A", false)
AddEffect("F14", "Ctrl", "N/A", false)
AddEffect("F14", "Alt", "N/A", false)
AddEffect("F14", "Shift+Ctrl+Alt", "N/A", false)

; F15 Effects*
AddEffect("F15", "", "N/A", false)
AddEffect("F15", "Shift", "N/A", false)
AddEffect("F15", "Ctrl", "N/A", false)
AddEffect("F15", "Alt", "N/A", false)
AddEffect("F15", "Shift+Ctrl+Alt", "N/A", false)

; F16 Effects*
AddEffect("F16", "", "N/A", false)
AddEffect("F16", "Shift", "N/A", false)
AddEffect("F16", "Ctrl", "N/A", false)
AddEffect("F16", "Alt", "N/A", false)
AddEffect("F16", "Shift+Ctrl+Alt", "N/A", false)

; F17 Effects*
AddEffect("F17", "", "N/A", false)
AddEffect("F17", "Shift", "N/A", false)
AddEffect("F17", "Ctrl", "N/A", false)
AddEffect("F17", "Alt", "N/A", false)
AddEffect("F17", "Shift+Ctrl+Alt", "N/A", false)

; F18 Effects*
AddEffect("F18", "", "N/A", false)
AddEffect("F18", "Shift", "N/A", false)
AddEffect("F18", "Ctrl", "N/A", false)
AddEffect("F18", "Alt", "N/A", false)
AddEffect("F18", "Shift+Ctrl+Alt", "N/A", false)

; F19 Effects*
AddEffect("F19", "", "N/A", false)
AddEffect("F19", "Shift", "N/A", false)
AddEffect("F19", "Ctrl", "N/A", false)
AddEffect("F19", "Alt", "N/A", false)
AddEffect("F19", "Shift+Ctrl+Alt", "N/A", false)

; F20 Effects*
AddEffect("F20", "", "N/A", false)
AddEffect("F20", "Shift", "N/A", false)
AddEffect("F20", "Ctrl", "N/A", false)
AddEffect("F20", "Alt", "N/A", false)
AddEffect("F20", "Shift+Ctrl+Alt", "N/A", false)

; F21 Effects*
AddEffect("F21", "", "N/A", false)
AddEffect("F21", "Shift", "N/A", false)
AddEffect("F21", "Ctrl", "N/A", false)
AddEffect("F21", "Alt", "N/A", false)
AddEffect("F21", "Shift+Ctrl+Alt", "N/A", false)

; F22 Effects*
AddEffect("F22", "", "N/A", false)
AddEffect("F22", "Shift", "N/A", false)
AddEffect("F22", "Ctrl", "N/A", false)
AddEffect("F22", "Alt", "N/A", false)
AddEffect("F22", "Shift+Ctrl+Alt", "N/A", false)

; F23 Effects*
AddEffect("F23", "", "N/A", false)
AddEffect("F23", "Shift", "N/A", false)
AddEffect("F23", "Ctrl", "N/A", false)
AddEffect("F23", "Alt", "N/A", false)
AddEffect("F23", "Shift+Ctrl+Alt", "N/A", false)

; F24 Effects*
AddEffect("F24", "", "N/A", false)
AddEffect("F24", "Shift", "N/A", false)
AddEffect("F24", "Ctrl", "N/A", false)
AddEffect("F24", "Alt", "N/A", false)
AddEffect("F24", "Shift+Ctrl+Alt", "N/A", false)

IsPremiereActive(*) {
    return WinActive("ahk_exe Adobe Premiere Pro.exe")
}

; === REGISTER HOTKEYS DYNAMICALLY WITH PREMIERE PRO CHECK ===
RegisterHotkeys() {
    global effects
    HotIf
    for fullKey, effect in effects {
        if (!effect["enabled"]) {
            continue
        }
        
        modifiers := effect["modifiers"]
        hotkeyStr := ""
        requiresCaps := false
        if (modifiers != "") {
            for mod in StrSplit(modifiers, "+") {
                switch mod {
                    case "Ctrl":
                        hotkeyStr .= "^"
                    case "Shift":
                        hotkeyStr .= "+"
                    case "Alt":
                        hotkeyStr .= "!"
                    case "Win":
                        hotkeyStr .= "#"
                    case "Caps":
                        requiresCaps := true
                }
            }
        }
        if (requiresCaps) {
            HotIf CapsModifierActive
        } else {
            HotIf CapsModifierInactive
        }
        
        baseKey := effect["key"]
        finalKey := hotkeyStr . baseKey
        
        Hotkey(finalKey, ApplyEffectClosure(effect))
    }
    HotIf
}

ApplyEffectClosure(effect) {
    return ApplyEffectWrapper.Bind(effect)
}

ApplyEffectWrapper(effect, *) {
    ; CHECK IF PREMIERE PRO IS ACTIVE - EXIT IF NOT
    if (!WinActive("ahk_exe Adobe Premiere Pro.exe")) {
        return
    }
    modifiers := effect.Has("modifiers") ? effect["modifiers"] : ""
    requiresCaps := (modifiers != "" && InStr(modifiers, "Caps"))
    capsDown := CapsModifierDown()
    if (requiresCaps && !capsDown) {
        return
    }
    if (!requiresCaps && capsDown) {
        return
    }
    ApplyEffect(effect)
}

; === GLOBAL STATE ===
global captureMode := false
global positionIndex := 0
global activeEffect := Map()
global effectGui := ""

; === GUI FUNCTIONS ===
OpenCaptureGUI() {
    ; CHECK IF PREMIERE PRO IS ACTIVE - EXIT IF NOT
    if (!WinActive("ahk_exe Adobe Premiere Pro.exe")) {
        MsgBox("This script only works in Adobe Premiere Pro!", "Wrong Application", "OK Icon!")
        return
    }
    
    global effects, effectGui
    
    if (effectGui && IsObject(effectGui)) {
        effectGui.Destroy()
    }
    
    effectGui := Gui("+AlwaysOnTop", "Effects Automation")
    effectGui.SetFont("s9")

    effectGui.Add("Text", "w420 Center", "Premiere Pro Effects Configuration").SetFont("s11 Bold")

    effectGui.Add("ListView", "vEffectList w520 h260 -Multi ReadOnly", ["Hotkey", "Effect Name", "Status"])

    effectGui.Add("Text", "xm Section y+10", "Select Effect to Configure:")
    effectCombo := effectGui.Add("ComboBox", "vEffectChoice w420")
    if (effectCombo.HasMethod("SetCueBanner")) {
        effectCombo.SetCueBanner("Type to search effects...")
    }

    captureBtn := effectGui.Add("Button", "xm y+8 w130", "Capture Positions")
    captureBtn.OnEvent("Click", (*) => StartCapture(effectGui))
    clearBtn := effectGui.Add("Button", "x+10 w130", "Clear Positions")
    clearBtn.OnEvent("Click", (*) => ClearSelectedEffectPositions(effectGui))
    closeBtn := effectGui.Add("Button", "x+10 w90", "Close")
    closeBtn.OnEvent("Click", (*) => effectGui.Destroy())

    defaultGroup := effectGui.Add("GroupBox", "xm y+15 w520 h150", "Default Positions")
    defaultGroup.GetPos(&grpX, &grpY, &grpW, &grpH)
    rowY1 := grpY + 25
    rowY2 := rowY1 + 30
    col1X := grpX + 20
    col2X := grpX + 220

    effectGui.Add("Text", Format("x{1} y{2}", col1X, rowY1), "Search X:")
    effectGui.Add("Edit", Format("vDefaultSearchX w100 x{1} y{2}", col1X + 90, rowY1 - 3))

    effectGui.Add("Text", Format("x{1} y{2}", col2X, rowY1), "Search Y:")
    effectGui.Add("Edit", Format("vDefaultSearchY w100 x{1} y{2}", col2X + 90, rowY1 - 3))

    effectGui.Add("Text", Format("x{1} y{2}", col1X, rowY2), "Icon X:")
    effectGui.Add("Edit", Format("vDefaultIconX w100 x{1} y{2}", col1X + 90, rowY2 - 3))

    effectGui.Add("Text", Format("x{1} y{2}", col2X, rowY2), "Icon Y:")
    effectGui.Add("Edit", Format("vDefaultIconY w100 x{1} y{2}", col2X + 90, rowY2 - 3))

    buttonY := rowY2 + 40
    loadDefaultsBtn := effectGui.Add("Button", Format("x{1} y{2} w90", col1X, buttonY), "Load")
    loadDefaultsBtn.OnEvent("Click", (*) => LoadDefaultFields(effectGui))
    saveDefaultsBtn := effectGui.Add("Button", Format("x{1} y{2} w90", col1X + 100, buttonY), "Save")
    saveDefaultsBtn.OnEvent("Click", (*) => SaveDefaultFields(effectGui))
    captureDefaultsBtn := effectGui.Add("Button", Format("x{1} y{2} w110", col1X + 210, buttonY), "Capture")
    captureDefaultsBtn.OnEvent("Click", StartDefaultCapture)
    clearDefaultsBtn := effectGui.Add("Button", Format("x{1} y{2} w90", col1X + 330, buttonY), "Clear")
    clearDefaultsBtn.OnEvent("Click", (*) => ClearDefaultPositions(effectGui))

    PopulateEffectSelectors(effectGui)
    LoadDefaultFields(effectGui)

    effectGui.Show("w560 h520")
}

StartCapture(gui) {
    global effects, captureMode, positionIndex, activeEffect
    
    gui.Submit()
    selectedText := gui["EffectChoice"].Text
    
    ; Extract effect name from selection
    effectName := RegExReplace(selectedText, " \([^)]*\).*$", "")
    
    ; Find the effect
    effect := GetEffectByName(effectName)
    if (!IsObject(effect)) {
        MsgBox("Please select a valid effect.", "Error", "OK Icon!")
        return
    }

    try gui.Destroy()
    global effectGui
    effectGui := ""
    
    BeginCaptureForEffect(effect)
}

StartDefaultCapture(*) {
    global effectGui
    if (effectGui && IsObject(effectGui)) {
        try effectGui.Destroy()
        effectGui := ""
    }
    BeginCaptureForEffect(CreateDefaultEffect())
}

; === CAPTURE FUNCTIONS ===
OnLeftClick() {
    global captureMode, positionIndex, activeEffect
    
    if (!captureMode) {
        return
    }
    
    ; CHECK IF PREMIERE PRO IS ACTIVE - EXIT IF NOT
    if (!WinActive("ahk_exe Adobe Premiere Pro.exe")) {
        return
    }
    
    MouseGetPos(&x, &y)
    effectLabel := GetEffectDisplayName(activeEffect)
    
    if (positionIndex = 1) {
        activeEffect["searchX"] := x
        activeEffect["searchY"] := y
        positionIndex := 2
        ShowTimedTray("Effect Capture", "Search bar saved for " . effectLabel . ".`nStep 2: Click the effect icon.", 2500)
    } else if (positionIndex = 2) {
        activeEffect["iconX"] := x
        activeEffect["iconY"] := y
        SaveEffectPositions(activeEffect)
        captureMode := false
        positionIndex := 0
        ShowTimedTray("Effect Capture", "Capture complete for " . effectLabel . ".", 2500)
    }
}

SaveEffectPositions(effect) {
    if (!IsObject(effect) || !effect.Has("name")) {
        return
    }
    iniFile := GetEffectIniPath(effect["name"])
    
    IniWrite(Round(effect["searchX"]), iniFile, "Positions", "SearchX")
    IniWrite(Round(effect["searchY"]), iniFile, "Positions", "SearchY")
    IniWrite(Round(effect["iconX"]), iniFile, "Positions", "IconX")
    IniWrite(Round(effect["iconY"]), iniFile, "Positions", "IconY")
    IniWrite(effect["name"], iniFile, "Effect", "Name")
    RefreshEffectGui()
}

LoadEffectPositions(effect, allowDefault := false) {
    if (!IsObject(effect) || !effect.Has("name")) {
        return false
    }

    iniFile := GetEffectIniPath(effect["name"])
    if (FileExist(iniFile)) {
        try {
            effect["searchX"] := ReadEffectCoordinate(iniFile, "SearchX")
            effect["searchY"] := ReadEffectCoordinate(iniFile, "SearchY")
            effect["iconX"] := ReadEffectCoordinate(iniFile, "IconX")
            effect["iconY"] := ReadEffectCoordinate(iniFile, "IconY")
            return true
        } catch {
        }
    }

    if (allowDefault) {
        return LoadDefaultPositions(effect)
    }
    return false
}

LoadDefaultPositions(effect) {
    defaultFile := GetDefaultIniFile()
    if (!FileExist(defaultFile)) {
        return false
    }
    try {
        effect["searchX"] := ReadEffectCoordinate(defaultFile, "SearchX")
        effect["searchY"] := ReadEffectCoordinate(defaultFile, "SearchY")
        effect["iconX"] := ReadEffectCoordinate(defaultFile, "IconX")
        effect["iconY"] := ReadEffectCoordinate(defaultFile, "IconY")
        return true
    } catch {
        return false
    }
}

GetDefaultIniFile() {
    return GetEffectIniPath(DEFAULT_EFFECT_NAME)
}

GetEffectByName(effectName) {
    global effects
    for fullKey, effect in effects {
        if (effect["name"] = effectName) {
            return effect
        }
    }
    return ""
}

CreateDefaultEffect() {
    return Map(
        "name", DEFAULT_EFFECT_NAME,
        "key", "",
        "modifiers", "",
        "enabled", true
    )
}

BeginCaptureForEffect(effect) {
    if (!IsObject(effect)) {
        return false
    }

    premiereWindow := "ahk_exe Adobe Premiere Pro.exe"
    if (!WinExist(premiereWindow)) {
        MsgBox("Adobe Premiere Pro must be running to capture effect positions.", "Application Not Found", "OK Icon!")
        return false
    }

    effectLabel := GetEffectDisplayName(effect)

    if (!WinActive(premiereWindow)) {
        WinActivate(premiereWindow)
        ShowTimedTray("Effect Capture", "Switch to Premiere to capture " . effectLabel . ".", 2000)
    }

    global captureMode, positionIndex, activeEffect
    activeEffect := effect
    captureMode := true
    positionIndex := 1

    ShowTimedTray("Effect Capture", "Step 1: Click the effects search bar for " . effectLabel . ".", 2500)
    return true
}

EnsureEffectPositions(effect) {
    if (LoadEffectPositions(effect, false)) {
        return true
    }

    effectLabel := GetEffectDisplayName(effect)
    defaultAvailable := HasDefaultPositions()

    message := effectLabel . " has no current position.`n`nSelect an option:`nYes = Capture manually"
    if (defaultAvailable) {
        message .= "`nNo = Use default positions"
    }
    message .= "`nCancel = Exit"

    buttons := defaultAvailable ? "YesNoCancel" : "YesCancel"
    response := MsgBox(message, "Effect Positions Missing", buttons . " Icon!")

    if (response = "Yes") {
        BeginCaptureForEffect(effect)
        return false
    }

    if (response = "No" && defaultAvailable) {
        if (LoadDefaultPositions(effect)) {
            SaveEffectPositions(effect)
            ShowTimedTray("Effect Picker", "Using default positions for " . effectLabel . ".", 2000)
            return true
        }
        MsgBox("Default positions are not available.", "Effect Picker", "OK Icon!")
    }

    return false
}

; === EFFECT APPLICATION ===
ApplyEffect(effect) {
    ; DOUBLE CHECK IF PREMIERE PRO IS ACTIVE - EXIT IF NOT
    if (!WinActive("ahk_exe Adobe Premiere Pro.exe")) {
        return
    }
    
    CoordMode("Mouse", "Screen")
    
    if (!EnsureEffectPositions(effect)) {
        return
    }
    
    ; Save original mouse position
    MouseGetPos(&originalMouseX, &originalMouseY)
    
    ; Click search bar
    ClickAt(effect["searchX"], effect["searchY"])
    Sleep(30)
    Send("^a")
    Sleep(20)
    
    ; Type effect name
    A_Clipboard := effect["name"]
    Sleep(20)
    Send("^v")
    Sleep(100)
    
    ; Drag effect to original position
    DragInstant(effect["iconX"], effect["iconY"], originalMouseX, originalMouseY)
}

; === INITIALIZATION ===
RegisterHotkeys()

; Function for GUI hotkey
ConfigHotkey(*) {
    if (!WinActive("ahk_exe Adobe Premiere Pro.exe")) {
        return
    }
    OpenCaptureGUI()
}

; Function for click handler
ClickHandler(*) {
    if (!WinActive("ahk_exe Adobe Premiere Pro.exe")) {
        return
    }
    OnLeftClick()
}

; Register GUI hotkey WITH PREMIERE PRO CHECK
HotIf IsPremiereActive
Hotkey("!+c", ConfigHotkey)

; Register click handler WITH PREMIERE PRO CHECK
Hotkey("~LButton", ClickHandler)
HotIf






