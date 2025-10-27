#Requires AutoHotkey v2.0
#SingleInstance Force

TraySetIcon(A_ScriptDir . "\\..\\assets\\icons\\tray_premiere.ico")

SetKeyDelay(0)
SetMouseDelay(0)
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

global gAEConfigFile := A_ScriptDir . "\\..\\AE Scripts\\config\\afterfx_positions.ini"
global gAEColorRegion := Map("left", "", "top", "", "right", "", "bottom", "")
global gAEAlignPositions := Map(
    "start", Map("x", "", "y", ""),
    "end",   Map("x", "", "y", "")
)
global gAEColorHex := Map()
global gAEColorPositions := Map("label", Map(), "keyframe", Map())
global gAEColorOffset := Map(
    "label",    Map("x", 0, "y", 0),
    "keyframe", Map("x", 0, "y", 0)
)
global gAEConfigGui := Map()
global gAERegionCapture := {active: false, step: 0}
global gAEAlignCapture := Map("start", false, "end", false, "trimFirst", false, "trimLast", false)
global gAETrimKeyPositions := Map(
    "first", Map("x", "", "y", ""),
    "last", Map("x", "", "y", "")
)
global gAEColorPositionCapture := Map("active", false, "mode", "", "color", "")
global gAEColorSequenceCapture := Map("active", false, "mode", "", "index", 0)
global gAEColorMenuGuis := Map()
global gAEColorSearchVariation := 25

global gAEColorNames := [
    "Black",
    "Red",
    "Yellow",
    "Cyan",
    "Pink",
    "Lavender",
    "White",
    "Blue",
    "Green",
    "Dark Blue",
    "Orange",
    "Brown",
    "Hot Orange",
    "Teal",
    "Sandstone",
    "Dark Green"
]

global gAEColorDefaults := Map(
    "Black", "000000",
    "Red", "FF0000",
    "Yellow", "FFD602",
    "Cyan", "00D5FF",
    "Pink", "FF7EB9",
    "Lavender", "B26DF0",
    "White", "FFFFFF",
    "Blue", "0000EE",
    "Green", "33CD32",
    "Dark Blue", "0066CC",
    "Orange", "E8920D",
    "Brown", "7F452A",
    "Hot Orange", "E64E00",
    "Teal", "006B5B",
    "Sandstone", "A89677",
    "Dark Green", "008001"
)

gAEHotkeyRefs := []
gAERegisteredCombos := []
gAEHotkeySet := Map()
gAELabelHotkeys := InitAELabelHotkeys()
gAEKeyframeHotkeys := InitAEKeyframeHotkeys()

IsAfterEffectsActive(*) {
    return WinActive("ahk_exe AfterFX.exe")
}

LoadAEConfig()
RegisterAEHotkeys()
#HotIf WinActive("ahk_exe AfterFX.exe")
:*:fractal::Fractal Noise
:*:glowfx::Glow
^!+z::MoveMouseToPlayhead()
#^!F22::AlignKeyframeTo("start")
#^!F24::AlignKeyframeTo("end")
#^!+F13::AETrimToKey("first")
#^!F23::AETrimToKey("last")
#+F19::ToggleAEConfigPanel()
^!c::OpenAEColorMenu("label")
^!k::OpenAEColorMenu("keyframe")
~LButton::HandleAECaptureClicks()

RegisterAEHotkeys() {
    global gAEHotkeyRefs, gAERegisteredCombos, gAELabelHotkeys, gAEKeyframeHotkeys, gAEHotkeySet

    for combo in gAERegisteredCombos {
        try {
            Hotkey(combo, "Off")
        } catch {
        }
    }

    gAEHotkeyRefs := []
    gAERegisteredCombos := []
    gAEHotkeySet := Map()

    HotIf IsAfterEffectsActive

    for binding in gAELabelHotkeys {
        if !binding.Has("enabled") || !binding["enabled"] {
            continue
        }
        combo := binding["combo"]
        color := binding["color"]
        if (combo = "" || gAEHotkeySet.Has(combo)) {
            continue
        }
        handler := AEHotkeyHandler.Bind("label", color)
        gAEHotkeyRefs.Push(handler)
        Hotkey(combo, handler)
        gAERegisteredCombos.Push(combo)
        gAEHotkeySet[combo] := true
    }

    for binding in gAEKeyframeHotkeys {
        if !binding.Has("enabled") || !binding["enabled"] {
            continue
        }
        combo := binding["combo"]
        color := binding["color"]
        if (combo = "" || gAEHotkeySet.Has(combo)) {
            continue
        }
        handler := AEHotkeyHandler.Bind("keyframe", color)
        gAEHotkeyRefs.Push(handler)
        Hotkey(combo, handler)
        gAERegisteredCombos.Push(combo)
        gAEHotkeySet[combo] := true
    }

    HotIf
}

AEHotkeyHandler(mode, colorName, *) {
    AEApplyColor(mode, colorName)
}

InitAELabelHotkeys() {
    hotkeys := []
    hotkeys.Push(Map("combo", "!F13", "color", "Black", "enabled", true))
    hotkeys.Push(Map("combo", "!F14", "color", "Red", "enabled", true))
    hotkeys.Push(Map("combo", "!F15", "color", "Yellow", "enabled", true))
    hotkeys.Push(Map("combo", "!F16", "color", "Cyan", "enabled", true))
    hotkeys.Push(Map("combo", "!F17", "color", "Pink", "enabled", true))
    hotkeys.Push(Map("combo", "!F18", "color", "Lavender", "enabled", true))
    hotkeys.Push(Map("combo", "!F19", "color", "White", "enabled", true))
    hotkeys.Push(Map("combo", "!F20", "color", "Blue", "enabled", true))
    hotkeys.Push(Map("combo", "!F21", "color", "Green", "enabled", true))
    hotkeys.Push(Map("combo", "!F22", "color", "Dark Blue", "enabled", true))
    hotkeys.Push(Map("combo", "!F23", "color", "Orange", "enabled", true))
    hotkeys.Push(Map("combo", "!F24", "color", "Brown", "enabled", true))
    hotkeys.Push(Map("combo", "^!F13", "color", "Hot Orange", "enabled", true))
    hotkeys.Push(Map("combo", "^!F14", "color", "Sandstone", "enabled", true))
    hotkeys.Push(Map("combo", "^+!F16", "color", "Teal", "enabled", true))
    return hotkeys
}

InitAEKeyframeHotkeys() {
    hotkeys := []
    hotkeys.Push(Map("combo", "!+F13", "color", "Black", "enabled", true))
    hotkeys.Push(Map("combo", "!+F14", "color", "Red", "enabled", true))
    hotkeys.Push(Map("combo", "!+F15", "color", "Yellow", "enabled", true))
    hotkeys.Push(Map("combo", "!+F16", "color", "Cyan", "enabled", true))
    hotkeys.Push(Map("combo", "!+F17", "color", "Pink", "enabled", true))
    hotkeys.Push(Map("combo", "!+F18", "color", "Lavender", "enabled", true))
    hotkeys.Push(Map("combo", "!+F19", "color", "White", "enabled", true))
    hotkeys.Push(Map("combo", "!+F20", "color", "Blue", "enabled", true))
    hotkeys.Push(Map("combo", "!+F21", "color", "Green", "enabled", true))
    hotkeys.Push(Map("combo", "!+F22", "color", "Dark Blue", "enabled", true))
    hotkeys.Push(Map("combo", "!+F23", "color", "Orange", "enabled", true))
    hotkeys.Push(Map("combo", "!+F24", "color", "Brown", "enabled", true))
    hotkeys.Push(Map("combo", "#!+F13", "color", "Hot Orange", "enabled", true))
    hotkeys.Push(Map("combo", "#!+F14", "color", "Teal", "enabled", true))
    return hotkeys
}

ApplyAELabelColor(colorName) {
    AEApplyColor("label", colorName)
}

ApplyAEKeyframeColor(colorName) {
    AEApplyColor("keyframe", colorName)
}

AEJumpMouse(x, y) {
    x := Round(x)
    y := Round(y)
    DllCall("SetCursorPos", "int", x, "int", y)
}

GetAEColorPositionText(colorName, mode) {
    global gAEColorPositions, gAEColorOffset
    if !gAEColorPositions.Has(mode) {
        return ""
    }
    modePositions := gAEColorPositions[mode]
    if !IsObject(modePositions) {
        return ""
    }
    if !modePositions.Has(colorName) {
        return ""
    }
    pos := modePositions[colorName]
    if !IsObject(pos) || !pos.Has("x") || !pos.Has("y") {
        return ""
    }
    x := pos["x"]
    y := pos["y"]
    if (x = "" || y = "") {
        return ""
    }
    offset := gAEColorOffset.Has(mode) ? gAEColorOffset[mode] : Map("x", 0, "y", 0)
    offsetX := IsObject(offset) && offset.Has("x") ? offset["x"] : 0
    offsetY := IsObject(offset) && offset.Has("y") ? offset["y"] : 0
    extra := (offsetX != 0 || offsetY != 0) ? Format(" (+{1},{2})", offsetX, offsetY) : ""
    return Format("{1},{2}{3}", x, y, extra)
}

MoveMouseToPlayhead() {
    MouseGetPos(&origX, &origY)
    primaryIndex := MonitorGetPrimary()
    MonitorGet(primaryIndex, &monLeft, &monTop, &monRight, &monBottom)

    targetX := origX
    targetY := monTop + 87

    refImage := A_ScriptDir . "\\..\\AE Scripts\\after effects timeline mouse script\\images\\AEcurver-2monitor.png"
    if FileExist(refImage) {
        result := ImageSearch(&foundX, &foundY, monLeft, monTop, monRight, monBottom, refImage)
        if (result = 0 && IsNumber(foundX) && IsNumber(foundY)) {
            targetX := foundX + 200
            targetY := foundY + 87
        } else {
            targetX := monLeft + ((monRight - monLeft) / 2)
            targetY := monTop + 87
        }
    }

    if (origX < monLeft || origX > monRight) {
        targetX := monLeft + ((monRight - monLeft) / 2)
    }

    MouseMove(targetX, targetY, 0)
    Click("L")
    MouseMove(origX, origY, 0)
}

EnsureAfterEffectsActive() {
    if WinActive("ahk_exe AfterFX.exe") {
        return true
    }
    try {
        WinActivate("ahk_exe AfterFX.exe")
        WinWaitActive("ahk_exe AfterFX.exe", , 0.4)
    } catch {
    }
    return WinActive("ahk_exe AfterFX.exe")
}

ToggleAEConfigPanel(*) {
    gui := EnsureAEConfigGui()
    if IsGuiVisible(gui) {
        gui.Hide()
    } else {
        UpdateAEConfigGui()
        gui.Show()
    }
}

EnsureAEConfigGui() {
    global gAEConfigGui

    if (gAEConfigGui.Has("gui") && IsObject(gAEConfigGui["gui"])) {
        return gAEConfigGui["gui"]
    }

    guiObj := Gui("+AlwaysOnTop +Resize +MinSize360x260", "After Effects Tools")
    guiObj.MarginX := 10
    guiObj.MarginY := 8

    tabs := guiObj.Add("Tab", "xm ym w420 h220", ["Alignment && Trim", "Color Hexes"])

    tabs.UseTab(1)
    guiObj.SetFont("bold")
    guiObj.Add("Text", "xm ym+8", "Align buttons")
    guiObj.SetFont()
    guiObj.Add("Text", "xm y+6", "Start X:")
    ctrlStartX := guiObj.Add("Edit", "x+4 w60 ReadOnly Center")
    guiObj.Add("Text", "x+10", "Start Y:")
    ctrlStartY := guiObj.Add("Edit", "x+4 w60 ReadOnly Center")
    btnCaptureStart := guiObj.Add("Button", "x+12 w150", "Capture Align-to-Begin")
    btnCaptureStart.OnEvent("Click", AECaptureAlignStart)

    guiObj.Add("Text", "xm y+10", "End X:")
    ctrlEndX := guiObj.Add("Edit", "x+4 w60 ReadOnly Center")
    guiObj.Add("Text", "x+10", "End Y:")
    ctrlEndY := guiObj.Add("Edit", "x+4 w60 ReadOnly Center")
    btnCaptureEnd := guiObj.Add("Button", "x+12 w150", "Capture Align-to-End")
    btnCaptureEnd.OnEvent("Click", AECaptureAlignEnd)

    guiObj.SetFont("bold")
    guiObj.Add("Text", "xm y+12", "Trim helpers")
    guiObj.SetFont()
    guiObj.Add("Text", "xm y+6", "First Key X:")
    ctrlTrimFirstX := guiObj.Add("Edit", "x+4 w60 ReadOnly Center")
    guiObj.Add("Text", "x+10", "First Key Y:")
    ctrlTrimFirstY := guiObj.Add("Edit", "x+4 w60 ReadOnly Center")
    btnCaptureTrimFirst := guiObj.Add("Button", "x+12 w170", "Capture Trim First Key")
    btnCaptureTrimFirst.OnEvent("Click", AECaptureTrimFirst)

    guiObj.Add("Text", "xm y+10", "Last Key X:")
    ctrlTrimLastX := guiObj.Add("Edit", "x+4 w60 ReadOnly Center")
    guiObj.Add("Text", "x+10", "Last Key Y:")
    ctrlTrimLastY := guiObj.Add("Edit", "x+4 w60 ReadOnly Center")
    btnCaptureTrimLast := guiObj.Add("Button", "x+12 w170", "Capture Trim Last Key")
    btnCaptureTrimLast.OnEvent("Click", AECaptureTrimLast)

    btnSaveAlign := guiObj.Add("Button", "xm y+12 w140", "Save Alignment")
    btnSaveAlign.OnEvent("Click", AESaveAlignmentFromGui)
    btnReloadAlign := guiObj.Add("Button", "x+10 w110", "Reload")
    btnReloadAlign.OnEvent("Click", (*) => UpdateAEConfigGui())

    tabs.UseTab(2)
    guiObj.SetFont("bold")
    guiObj.Add("Text", "xm ym+8", "Label/keyframe colours")
    guiObj.SetFont()

    lvColors := guiObj.Add("ListView", "xm y+6 w260 h140 vColorList", ["Color", "Hex", "Label Pos", "Keyframe Pos"])
    lvColors.OnEvent("DoubleClick", AEEditColorHex)

    sidePanel := guiObj.Add("GroupBox", "x+272 ys w150 h140", "Sequence / Hex")
    btnCaptureAllLabel := guiObj.Add("Button", "xp+10 yp+20 w120", "Capture All Labels")
    btnCaptureAllLabel.OnEvent("Click", AECaptureColorSequence.Bind("label"))
    btnCaptureAllKey := guiObj.Add("Button", "xp y+8 w120", "Capture All Keyframes")
    btnCaptureAllKey.OnEvent("Click", AECaptureColorSequence.Bind("keyframe"))
    btnCancelSequence := guiObj.Add("Button", "xp y+8 w120", "Cancel Sequence")
    btnCancelSequence.OnEvent("Click", AECancelColorSequence)
    btnEditHex := guiObj.Add("Button", "xp y+12 w120", "Edit Selected Hex")
    btnEditHex.OnEvent("Click", AEEditColorHex)
    btnResetHex := guiObj.Add("Button", "xp y+8 w120", "Reset Hex Defaults")
    btnResetHex.OnEvent("Click", AEResetColorHexes)
    btnSaveHex := guiObj.Add("Button", "xp y+8 w120", "Save Hex Values")
    btnSaveHex.OnEvent("Click", AESaveColorHexes)

    guiObj.SetFont("bold")
    guiObj.Add("Text", "xm y+12", "Global offsets")
    guiObj.SetFont()
    guiObj.Add("Text", "xm y+4", "Label Offset X:")
    ctrlLabelOffsetX := guiObj.Add("Edit", "x+4 w70 Center")
    guiObj.Add("Text", "x+10", "Label Offset Y:")
    ctrlLabelOffsetY := guiObj.Add("Edit", "x+4 w70 Center")
    guiObj.Add("Text", "x+14", "Keyframe Offset X:")
    ctrlKeyOffsetX := guiObj.Add("Edit", "x+4 w70 Center")
    guiObj.Add("Text", "x+10", "Keyframe Offset Y:")
    ctrlKeyOffsetY := guiObj.Add("Edit", "x+4 w70 Center")
    btnApplyOffset := guiObj.Add("Button", "x+14 w140", "Save Offsets")
    btnApplyOffset.OnEvent("Click", AESaveColorOffsetFromGui)

    tabs.UseTab()

    btnClose := guiObj.Add("Button", "xm y+14 w110", "Close")
    btnClose.OnEvent("Click", (*) => guiObj.Hide())

    guiObj.OnEvent("Close", (*) => guiObj.Hide())
    guiObj.OnEvent("Escape", (*) => guiObj.Hide())

    gAEConfigGui := Map(
        "gui", guiObj,
        "tabs", tabs,
        "closeBtn", btnClose,
        "alignEdits", Map(
            "startX", ctrlStartX,
            "startY", ctrlStartY,
            "endX", ctrlEndX,
            "endY", ctrlEndY,
            "trimFirstX", ctrlTrimFirstX,
            "trimFirstY", ctrlTrimFirstY,
            "trimLastX", ctrlTrimLastX,
            "trimLastY", ctrlTrimLastY
        ),
        "colorList", lvColors,
        "colorSide", sidePanel,
        "colorActions", [btnCaptureAllLabel, btnCaptureAllKey, btnCancelSequence, btnEditHex, btnResetHex, btnSaveHex],
        "offsetEdits", Map(
            "labelX", ctrlLabelOffsetX,
            "labelY", ctrlLabelOffsetY,
            "keyframeX", ctrlKeyOffsetX,
            "keyframeY", ctrlKeyOffsetY
        )
    )

    guiObj.OnEvent("Size", AEConfigGui_OnSize)
    return guiObj
}

UpdateAEConfigGui() {
    global gAEConfigGui, gAEAlignPositions, gAETrimKeyPositions, gAEColorHex, gAEColorNames, gAEColorOffset

    EnsureAEConfigGui()
    alignEdits := gAEConfigGui["alignEdits"]
    alignEdits["startX"].Value := gAEAlignPositions["start"]["x"]
    alignEdits["startY"].Value := gAEAlignPositions["start"]["y"]
    alignEdits["endX"].Value := gAEAlignPositions["end"]["x"]
    alignEdits["endY"].Value := gAEAlignPositions["end"]["y"]
    alignEdits["trimFirstX"].Value := gAETrimKeyPositions["first"]["x"]
    alignEdits["trimFirstY"].Value := gAETrimKeyPositions["first"]["y"]
    alignEdits["trimLastX"].Value := gAETrimKeyPositions["last"]["x"]
    alignEdits["trimLastY"].Value := gAETrimKeyPositions["last"]["y"]

    offsetEdits := gAEConfigGui["offsetEdits"]
    offsetEdits["labelX"].Value := gAEColorOffset["label"]["x"]
    offsetEdits["labelY"].Value := gAEColorOffset["label"]["y"]
    offsetEdits["keyframeX"].Value := gAEColorOffset["keyframe"]["x"]
    offsetEdits["keyframeY"].Value := gAEColorOffset["keyframe"]["y"]

    lv := gAEConfigGui["colorList"]
    lv.Delete()
    for colorName in gAEColorNames {
        hex := gAEColorHex.Has(colorName) ? gAEColorHex[colorName] : ""
        labelPos := GetAEColorPositionText(colorName, "label")
        keyframePos := GetAEColorPositionText(colorName, "keyframe")
        lv.Add("", colorName, hex, labelPos, keyframePos)
    }

    if gAEConfigGui.Has("gui") {
        gui := gAEConfigGui["gui"]
        try {
            gui.GetPos(&guiX, &guiY, &guiW, &guiH)
            AEConfigGui_OnSize(gui, 0, guiW, guiH)
        }
    }
}

AECaptureColorRegion(*) {
    if !EnsureAfterEffectsActive() {
        return
    }
    global gAERegionCapture
    gAERegionCapture.active := true
    gAERegionCapture.step := 1
    TrayTip("AE Color Panel", "Click the TOP-LEFT corner of the swatch panel.", "Mute")
    SetTimer(() => TrayTip(), -2000)
}

AECaptureAlignStart(*) {
    if !EnsureAfterEffectsActive() {
        return
    }
    global gAEAlignCapture
    gAEAlignCapture["start"] := true
    TrayTip("AE Alignment", Format("Click the {1}align to beginning{1} button.", Chr(34)), "Mute")
    SetTimer(() => TrayTip(), -2000)
}

AECaptureAlignEnd(*) {
    if !EnsureAfterEffectsActive() {
        return
    }
    global gAEAlignCapture
    gAEAlignCapture["end"] := true
    TrayTip("AE Alignment", Format("Click the {1}align to end{1} button.", Chr(34)), "Mute")
    SetTimer(() => TrayTip(), -2000)
}

AECaptureTrimFirst(*) {
    if !EnsureAfterEffectsActive() {
        return
    }
    global gAEAlignCapture
    gAEAlignCapture["trimFirst"] := true
    TrayTip("AE Trim", "Click the TRIM-TO-FIRST-KEY button.", "Mute")
    SetTimer(() => TrayTip(), -2000)
}

AECaptureTrimLast(*) {
    if !EnsureAfterEffectsActive() {
        return
    }
    global gAEAlignCapture
    gAEAlignCapture["trimLast"] := true
    TrayTip("AE Trim", "Click the TRIM-TO-LAST-KEY button.", "Mute")
    SetTimer(() => TrayTip(), -2000)
}

AESaveRegionFromGui(*) {
    SaveAEColorRegion()
    UpdateAEConfigGui()
}

AESaveAlignmentFromGui(*) {
    SaveAEAlignPositions()
    SaveAETrimPositions()
    UpdateAEConfigGui()
}

AEEditColorHex(ctrl, *) {
    global gAEConfigGui, gAEColorHex
    lv := gAEConfigGui["colorList"]
    row := lv.GetNext()
    if (row = 0) {
        return
    }
    colorName := lv.GetText(row, 1)
    current := lv.GetText(row, 2)

    result := InputBox("Enter hex value (e.g. FF0000). Leave blank to disable search.", colorName, , current)
    if (result.Result != "OK") {
        return
    }
    value := StrUpper(Trim(result.Value))
    if (value != "" && !RegExMatch(value, "^[0-9A-F]{6}$")) {
        MsgBox("Hex must be six hexadecimal characters (0-9, A-F).", "Hex", "OK Icon!")
        return
    }

    gAEColorHex[colorName] := value
    labelPos := GetAEColorPositionText(colorName, "label")
    keyframePos := GetAEColorPositionText(colorName, "keyframe")
    lv.Modify(row, , colorName, value, labelPos, keyframePos)
}

AECaptureColorPositionButton(mode, *) {
    global gAEConfigGui, gAEColorPositionCapture, gAEColorSequenceCapture
    if (mode != "label" && mode != "keyframe") {
        return
    }
    if gAEColorSequenceCapture["active"] {
        AECancelColorSequence()
    }
    lv := gAEConfigGui["colorList"]
    row := lv.GetNext()
    if (row = 0) {
        MsgBox("Select a color first.", "AE Colors", "OK Icon!")
        return
    }
    colorName := lv.GetText(row, 1)
    if !EnsureAfterEffectsActive() {
        return
    }
    gAEColorPositionCapture["active"] := true
    gAEColorPositionCapture["mode"] := mode
    gAEColorPositionCapture["color"] := colorName
    label := mode = "label" ? "label" : "keyframe"
    TrayTip("AE Colors", Format("Click the {1}{2}{1} {3} swatch.", Chr(34), colorName, label), "Mute")
    SetTimer(() => TrayTip(), -2000)
}

AEClearColorPosition(mode, *) {
    global gAEConfigGui, gAEColorPositions
    if (mode != "label" && mode != "keyframe") {
        return
    }
    lv := gAEConfigGui["colorList"]
    row := lv.GetNext()
    if (row = 0) {
        MsgBox("Select a color first.", "AE Colors", "OK Icon!")
        return
    }
    colorName := lv.GetText(row, 1)
    if RemoveAEColorPosition(colorName, mode) {
        TrayTip("AE Colors", Format("{1}{2}{1} {3} position cleared.", Chr(34), colorName, mode), "Mute")
        SetTimer(() => TrayTip(), -1500)
    }
}

AECaptureColorSequence(mode, *) {
    global gAEColorSequenceCapture, gAEColorPositionCapture
    if (mode != "label" && mode != "keyframe") {
        return
    }
    if !EnsureAfterEffectsActive() {
        return
    }
    gAEColorPositionCapture["active"] := false
    gAEColorPositionCapture["mode"] := ""
    gAEColorPositionCapture["color"] := ""
    gAEColorSequenceCapture["active"] := true
    gAEColorSequenceCapture["mode"] := mode
    gAEColorSequenceCapture["index"] := 1
    AEPromptNextSequenceColor()
}

AEPromptNextSequenceColor() {
    global gAEColorSequenceCapture, gAEColorNames
    if !gAEColorSequenceCapture["active"] {
        return
    }
    idx := gAEColorSequenceCapture["index"]
    if (idx > gAEColorNames.Length) {
        gAEColorSequenceCapture["active"] := false
        gAEColorSequenceCapture["mode"] := ""
        gAEColorSequenceCapture["index"] := 0
        TrayTip("AE Colors", "Capture sequence complete.", "Mute")
        SetTimer(() => TrayTip(), -1500)
        return
    }
    mode := gAEColorSequenceCapture["mode"]
    label := mode = "label" ? "label" : "keyframe"
    colorName := gAEColorNames[idx]
    quote := Chr(34)
    TrayTip("AE Colors", Format("[{1}/{2}] Click the {3}{4}{3} {5} swatch.", idx, gAEColorNames.Length, quote, colorName, label), "Mute")
    SetTimer(() => TrayTip(), -3000)
}

AECancelColorSequence(*) {
    global gAEColorSequenceCapture
    if !gAEColorSequenceCapture["active"] {
        return
    }
    gAEColorSequenceCapture["active"] := false
    gAEColorSequenceCapture["mode"] := ""
    gAEColorSequenceCapture["index"] := 0
    TrayTip("AE Colors", "Capture sequence cancelled.", "Mute")
    SetTimer(() => TrayTip(), -1500)
}

AESaveColorOffsetFromGui(*) {
    global gAEConfigGui, gAEColorOffset
    edits := gAEConfigGui["offsetEdits"]

    labelXText := Trim(edits["labelX"].Value)
    labelYText := Trim(edits["labelY"].Value)
    keyXText := Trim(edits["keyframeX"].Value)
    keyYText := Trim(edits["keyframeY"].Value)

    if (labelXText != "" && !RegExMatch(labelXText, "^-?\d+$")) {
        MsgBox("Label offset X must be an integer.", "AE Colors", "OK Icon!")
        return
    }
    if (labelYText != "" && !RegExMatch(labelYText, "^-?\d+$")) {
        MsgBox("Label offset Y must be an integer.", "AE Colors", "OK Icon!")
        return
    }
    if (keyXText != "" && !RegExMatch(keyXText, "^-?\d+$")) {
        MsgBox("Keyframe offset X must be an integer.", "AE Colors", "OK Icon!")
        return
    }
    if (keyYText != "" && !RegExMatch(keyYText, "^-?\d+$")) {
        MsgBox("Keyframe offset Y must be an integer.", "AE Colors", "OK Icon!")
        return
    }

    gAEColorOffset["label"]["x"] := (labelXText = "") ? 0 : Round(labelXText)
    gAEColorOffset["label"]["y"] := (labelYText = "") ? 0 : Round(labelYText)
    gAEColorOffset["keyframe"]["x"] := (keyXText = "") ? 0 : Round(keyXText)
    gAEColorOffset["keyframe"]["y"] := (keyYText = "") ? 0 : Round(keyYText)

    SaveAEColorPositions()
    UpdateAEConfigGui()
    TrayTip("AE Colors", "Offsets saved.", "Mute")
    SetTimer(() => TrayTip(), -1500)
}

AEResetColorOffset(*) {
    global gAEConfigGui, gAEColorOffset
    gAEColorOffset["label"]["x"] := 0
    gAEColorOffset["label"]["y"] := 0
    gAEColorOffset["keyframe"]["x"] := 0
    gAEColorOffset["keyframe"]["y"] := 0
    edits := gAEConfigGui["offsetEdits"]
    edits["labelX"].Value := 0
    edits["labelY"].Value := 0
    edits["keyframeX"].Value := 0
    edits["keyframeY"].Value := 0
    SaveAEColorPositions()
    UpdateAEConfigGui()
    TrayTip("AE Colors", "Offsets reset to 0,0.", "Mute")
    SetTimer(() => TrayTip(), -1500)
}

SetAEColorPosition(mode, colorName, x, y) {
    global gAEColorPositions, gAEConfigGui
    if (mode != "label" && mode != "keyframe") {
        return false
    }
    if (colorName = "" || !IsNumber(x) || !IsNumber(y)) {
        return false
    }
    x := Round(x)
    y := Round(y)
    positions := gAEColorPositions.Has(mode) ? gAEColorPositions[mode] : Map()
    if !IsObject(positions) {
        positions := Map()
    }
    positions[colorName] := Map("x", x, "y", y)
    gAEColorPositions[mode] := positions
    SaveAEColorPositions()
    if (gAEConfigGui.Has("gui")) {
        UpdateAEConfigGui()
    }
    return true
}

AEResetColorHexes(*) {
    global gAEColorHex, gAEColorDefaults
    for name, hex in gAEColorDefaults {
        gAEColorHex[name] := hex
    }
    UpdateAEConfigGui()
}

AESaveColorHexes(*) {
    SaveAEColorHexes()
    TrayTip("After Effects", "Color hex values saved.", "Mute")
    SetTimer(() => TrayTip(), -1500)
}

HandleAECaptureClicks(*) {
    if !WinActive("ahk_exe AfterFX.exe") {
        return
    }

    global gAERegionCapture, gAEColorRegion, gAEAlignCapture, gAEAlignPositions, gAETrimKeyPositions
    global gAEColorPositionCapture, gAEColorSequenceCapture, gAEColorNames

    if gAEColorSequenceCapture["active"] {
        mode := gAEColorSequenceCapture["mode"]
        index := gAEColorSequenceCapture["index"]
        if (mode = "" || index <= 0 || index > gAEColorNames.Length) {
            gAEColorSequenceCapture["active"] := false
            gAEColorSequenceCapture["mode"] := ""
            gAEColorSequenceCapture["index"] := 0
            return
        }
        colorName := gAEColorNames[index]
        MouseGetPos(&x, &y)
        if SetAEColorPosition(mode, colorName, Round(x), Round(y)) {
            TrayTip("AE Colors", Format("{1}{2}{1} {3} saved.", Chr(34), colorName, mode), "Mute")
            SetTimer(() => TrayTip(), -1200)
        }
        gAEColorSequenceCapture["index"] := index + 1
        AEPromptNextSequenceColor()
        return
    }

    if gAEColorPositionCapture["active"] {
        gAEColorPositionCapture["active"] := false
        mode := gAEColorPositionCapture["mode"]
        colorName := gAEColorPositionCapture["color"]
        gAEColorPositionCapture["mode"] := ""
        gAEColorPositionCapture["color"] := ""
        if (mode != "" && colorName != "") {
            MouseGetPos(&x, &y)
            if SetAEColorPosition(mode, colorName, Round(x), Round(y)) {
                TrayTip("AE Colors", Format("{1}{2}{1} {3} position saved.", Chr(34), colorName, mode), "Mute")
                SetTimer(() => TrayTip(), -1500)
            }
        }
        return
    }

    if gAERegionCapture.active {
        MouseGetPos(&x, &y)
        if (gAERegionCapture.step = 1) {
            gAEColorRegion["left"] := x
            gAEColorRegion["top"] := y
            gAERegionCapture.step := 2
            TrayTip("AE Color Panel", "Now click the BOTTOM-RIGHT corner.", "Mute")
            SetTimer(() => TrayTip(), -2000)
        } else {
            left := Min(gAEColorRegion["left"], x)
            right := Max(gAEColorRegion["left"], x)
            top := Min(gAEColorRegion["top"], y)
            bottom := Max(gAEColorRegion["top"], y)

            gAEColorRegion["left"] := left
            gAEColorRegion["top"] := top
            gAEColorRegion["right"] := right
            gAEColorRegion["bottom"] := bottom
            gAERegionCapture.active := false
            gAERegionCapture.step := 0
            SaveAEColorRegion()
            UpdateAEConfigGui()
            TrayTip("AE Color Panel", "Panel region saved.", "Mute")
            SetTimer(() => TrayTip(), -1500)
        }
        return
    }

    if gAEAlignCapture["start"] {
        gAEAlignCapture["start"] := false
        MouseGetPos(&x, &y)
        gAEAlignPositions["start"]["x"] := x
        gAEAlignPositions["start"]["y"] := y
        SaveAEAlignPositions()
        UpdateAEConfigGui()
        TrayTip("AE Alignment", "Beginning button saved.", "Mute")
        SetTimer(() => TrayTip(), -1500)
        return
    }

    if gAEAlignCapture["end"] {
        gAEAlignCapture["end"] := false
        MouseGetPos(&x, &y)
        gAEAlignPositions["end"]["x"] := x
        gAEAlignPositions["end"]["y"] := y
        SaveAEAlignPositions()
        UpdateAEConfigGui()
        TrayTip("AE Alignment", "End button saved.", "Mute")
        SetTimer(() => TrayTip(), -1500)
        return
    }

    if gAEAlignCapture.Has("trimFirst") && gAEAlignCapture["trimFirst"] {
        gAEAlignCapture["trimFirst"] := false
        MouseGetPos(&x, &y)
        gAETrimKeyPositions["first"]["x"] := x
        gAETrimKeyPositions["first"]["y"] := y
        SaveAETrimPositions()
        UpdateAEConfigGui()
        TrayTip("AE Trim", "First-key trim button saved.", "Mute")
        SetTimer(() => TrayTip(), -1500)
        return
    }

    if gAEAlignCapture.Has("trimLast") && gAEAlignCapture["trimLast"] {
        gAEAlignCapture["trimLast"] := false
        MouseGetPos(&x, &y)
        gAETrimKeyPositions["last"]["x"] := x
        gAETrimKeyPositions["last"]["y"] := y
        SaveAETrimPositions()
        UpdateAEConfigGui()
        TrayTip("AE Trim", "Last-key trim button saved.", "Mute")
        SetTimer(() => TrayTip(), -1500)
        return
    }
}


AEConfigGui_OnSize(guiObj, minMax, width, height) {
    global gAEConfigGui
    if !IsObject(guiObj) || !IsObject(gAEConfigGui) || !gAEConfigGui.Has("tabs") {
        return
    }

    if (minMax = 1 || minMax = 2)
        return

    tabs := gAEConfigGui["tabs"]
    closeBtn := gAEConfigGui.Has("closeBtn") ? gAEConfigGui["closeBtn"] : ""
    sidePanel := gAEConfigGui.Has("colorSide") ? gAEConfigGui["colorSide"] : ""
    colorActions := gAEConfigGui.Has("colorActions") ? gAEConfigGui["colorActions"] : []
    marginX := guiObj.MarginX
    marginY := guiObj.MarginY

    availableWidth := Max(width - marginX * 2, 300)
    btnW := 0
    btnH := 0
    if IsObject(closeBtn) {
        closeBtn.GetPos(, , &btnW, &btnH)
    }
    footerGap := IsObject(closeBtn) ? (btnH + 18) : 16
    availableHeight := Max(height - marginY * 2 - footerGap, 200)

    tabs.Move(marginX, marginY, availableWidth, availableHeight)

    if IsObject(closeBtn) {
        closeBtn.Move(Round((width - btnW) / 2), marginY + availableHeight + 4)
    }

    if gAEConfigGui.Has("colorList") {
        lv := gAEConfigGui["colorList"]
        lvTop := marginY + 6
        sideWidth := 150
        gap := 12
        minList := 220
        minSide := 120
        maxList := Max(minList, availableWidth - minSide - gap)
        listWidth := availableWidth - sideWidth - gap
        listWidth := Max(minList, Min(listWidth, maxList))
        sideWidth := Max(minSide, availableWidth - listWidth - gap)
        listHeight := Max(availableHeight - 20, 160)
        lv.Move(marginX, lvTop, listWidth, listHeight)

        if IsObject(sidePanel) {
            sidePanel.Move(marginX + listWidth + gap, lvTop, sideWidth, listHeight)
            if IsObject(colorActions) {
                actionX := marginX + listWidth + gap + 10
                actionY := lvTop + 20
                for action in colorActions {
                    try action.Move(actionX, actionY, sideWidth - 20)
                    actionY += 26
                }
            }
        }
    }
}

OpenAEColorMenu(mode) {
    info := EnsureAEColorMenu(mode)
    UpdateAEColorMenu(info)
    info["gui"].Show()
}

EnsureAEColorMenu(mode) {
    global gAEColorMenuGuis, gAEColorNames

    if (gAEColorMenuGuis.Has(mode) && IsObject(gAEColorMenuGuis[mode]["gui"])) {
        return gAEColorMenuGuis[mode]
    }

    title := mode = "label" ? "Layer Label Colors" : "Keyframe Colors"
    menuGui := Gui("+AlwaysOnTop", "AE " . title)
    menuGui.MarginX := 10
    menuGui.MarginY := 8
    menuGui.SetFont("s9")

    menuGui.Add("Text", "xm", "Choose a color to apply:")
    list := menuGui.Add("ListBox", "xm y+6 w220 r12", gAEColorNames)
    list.OnEvent("DoubleClick", AEApplySelectedColor.Bind(mode))

    btnApply := menuGui.Add("Button", "xm y+10 w90", "Apply")
    btnApply.OnEvent("Click", AEApplySelectedColor.Bind(mode))
    btnClose := menuGui.Add("Button", "x+10 w90", "Close")
    btnClose.OnEvent("Click", (*) => menuGui.Hide())

    menuGui.OnEvent("Close", (*) => menuGui.Hide())
    menuGui.OnEvent("Escape", (*) => menuGui.Hide())

    info := Map("gui", menuGui, "list", list, "mode", mode)
    gAEColorMenuGuis[mode] := info
    return info
}

UpdateAEColorMenu(info) {
    global gAEColorHex, gAEColorNames
    list := info["list"]
    current := list.Text
    list.Delete()
    for colorName in gAEColorNames {
        label := colorName
        if gAEColorHex.Has(colorName) && gAEColorHex[colorName] != "" {
            label .= "  (" . gAEColorHex[colorName] . ")"
        }
        list.Add(label)
    }
    if (current != "") {
        list.Text := current
    } else {
        list.Choose(1)
    }
}

AEApplySelectedColor(mode, ctrl, *) {
    global gAEColorMenuGuis
    info := gAEColorMenuGuis[mode]
    list := info["list"]
    selected := list.Text
    if (selected = "") {
        return
    }

    colorName := Trim(RegExReplace(selected, "\s*\(.*\)$"))
    AEApplyColor(mode, colorName)
}

AEApplyColor(mode, colorName) {
    if !EnsureAfterEffectsActive() {
        return
    }

    global gAEColorRegion, gAEColorHex, gAEColorSearchVariation, gAEColorPositions, gAEConfigGui, gAEColorOffset

    if (gAEColorRegion["left"] = "" || gAEColorRegion["right"] = "" || gAEColorRegion["top"] = "" || gAEColorRegion["bottom"] = "") {
        MsgBox("Capture the color panel region first in the AE config panel.", "After Effects", "OK Icon!")
        return
    }

    if !gAEColorHex.Has(colorName) {
        MsgBox(Format("Color {1}{2}{1} has no hex value configured.", Chr(34), colorName), "After Effects", "OK Icon!")
        return
    }

    hexValue := gAEColorHex[colorName]
    if (hexValue = "") {
        MsgBox(Format("Color {1}{2}{1} does not have a hex value. Edit it in the AE config panel.", Chr(34), colorName), "After Effects", "OK Icon!")
        return
    }

    colorInt := RGBHexToBGR(hexValue)

    left := Round(gAEColorRegion["left"])
    top := Round(gAEColorRegion["top"])
    right := Round(gAEColorRegion["right"])
    bottom := Round(gAEColorRegion["bottom"])

    modePositions := gAEColorPositions.Has(mode) ? gAEColorPositions[mode] : Map()
    if !IsObject(modePositions) {
        modePositions := Map()
        gAEColorPositions[mode] := modePositions
    }

    targetX := ""
    targetY := ""

    if modePositions.Has(colorName) {
        pos := modePositions[colorName]
        if (IsObject(pos) && pos.Has("x") && pos.Has("y")) {
            targetX := pos["x"]
            targetY := pos["y"]
        }
    }

    if (targetX = "" || targetY = "" || !IsNumber(targetX) || !IsNumber(targetY)) {
        result := PixelSearch(&foundX, &foundY, left, top, right, bottom, colorInt, gAEColorSearchVariation)
        if (result != 0) {
            MsgBox(Format("Could not locate color {1}{2}{1} inside the saved panel region.", Chr(34), colorName), "After Effects", "OK Icon!")
            return
        }
        targetX := foundX
        targetY := foundY
        modePositions[colorName] := Map("x", Round(targetX), "y", Round(targetY))
        gAEColorPositions[mode] := modePositions
        SaveAEColorPositions()
        if (gAEConfigGui.Has("gui")) {
            UpdateAEConfigGui()
        }
    }

    if (!IsNumber(targetX) || !IsNumber(targetY)) {
        MsgBox(Format("Saved position for color {1}{2}{1} is invalid. Capture it again from the AE config panel.", Chr(34), colorName), "After Effects", "OK Icon!")
        return
    }

    offset := gAEColorOffset.Has(mode) ? gAEColorOffset[mode] : Map("x", 0, "y", 0)
    offsetX := IsObject(offset) && offset.Has("x") ? offset["x"] : 0
    offsetY := IsObject(offset) && offset.Has("y") ? offset["y"] : 0
    if !IsNumber(offsetX)
        offsetX := 0
    if !IsNumber(offsetY)
        offsetY := 0

    targetX := Round(targetX) + offsetX
    targetY := Round(targetY) + offsetY

    MouseGetPos(&origX, &origY)
    AEJumpMouse(targetX, targetY)
    Sleep(30)
    Click()
    Sleep(20)
    AEJumpMouse(origX, origY)
}

AlignKeyframeTo(mode) {
    if !EnsureAfterEffectsActive() {
        return
    }

    global gAEAlignPositions

    pos := gAEAlignPositions.Has(mode) ? gAEAlignPositions[mode] : ""
    if !IsObject(pos) || pos["x"] = "" || pos["y"] = "" {
        label := mode = "start" ? "beginning" : "end"
        MsgBox(Format("Capture the {1}align to {2}{1} button first in the AE config panel.", Chr(34), label), "After Effects", "OK Icon!")
        return
    }

    MouseGetPos(&origX, &origY)
    AEJumpMouse(pos["x"], pos["y"])
    Sleep(30)
    Click()
    Sleep(40)
    AEJumpMouse(origX, origY)
}

AETrimToKey(which) {
    if !EnsureAfterEffectsActive() {
        return
    }

    global gAETrimKeyPositions
    if !IsObject(gAETrimKeyPositions) {
        gAETrimKeyPositions := Map(
            "first", Map("x", "", "y", ""),
            "last", Map("x", "", "y", "")
        )
    }

    if !gAETrimKeyPositions.Has(which) {
        gAETrimKeyPositions[which] := Map("x", "", "y", "")
    }

    pos := gAETrimKeyPositions[which]
    if !IsObject(pos) || pos["x"] = "" || pos["y"] = "" {
        label := (which = "first") ? "first key" : "last key"
        MsgBox(Format("Capture the {1} trim position in the AE config panel.", label), "After Effects", "OK Icon!")
        return
    }

    MouseGetPos(&origX, &origY)
    AEJumpMouse(pos["x"], pos["y"])
    Sleep(30)
    Click()
    Sleep(40)
    AEJumpMouse(origX, origY)
}

SaveAEColorRegion() {
    global gAEConfigFile, gAEColorRegion
    IniWrite(gAEColorRegion["left"], gAEConfigFile, "ColorPanel", "Left")
    IniWrite(gAEColorRegion["top"], gAEConfigFile, "ColorPanel", "Top")
    IniWrite(gAEColorRegion["right"], gAEConfigFile, "ColorPanel", "Right")
    IniWrite(gAEColorRegion["bottom"], gAEConfigFile, "ColorPanel", "Bottom")
}

SaveAEAlignPositions() {
    global gAEConfigFile, gAEAlignPositions
    IniWrite(gAEAlignPositions["start"]["x"], gAEConfigFile, "Alignment", "StartX")
    IniWrite(gAEAlignPositions["start"]["y"], gAEConfigFile, "Alignment", "StartY")
    IniWrite(gAEAlignPositions["end"]["x"], gAEConfigFile, "Alignment", "EndX")
    IniWrite(gAEAlignPositions["end"]["y"], gAEConfigFile, "Alignment", "EndY")
}

SaveAETrimPositions() {
    global gAEConfigFile, gAETrimKeyPositions
    IniWrite(gAETrimKeyPositions["first"]["x"], gAEConfigFile, "TrimKeys", "FirstX")
    IniWrite(gAETrimKeyPositions["first"]["y"], gAEConfigFile, "TrimKeys", "FirstY")
    IniWrite(gAETrimKeyPositions["last"]["x"], gAEConfigFile, "TrimKeys", "LastX")
    IniWrite(gAETrimKeyPositions["last"]["y"], gAEConfigFile, "TrimKeys", "LastY")
}

SaveAEColorHexes() {
    global gAEConfigFile, gAEColorHex
    for name, hex in gAEColorHex {
        IniWrite(hex, gAEConfigFile, "ColorHex", name)
    }
}

SaveAEColorPositions() {
    global gAEConfigFile, gAEColorPositions, gAEColorOffset
    sections := Map("label", "ColorPosition_Label", "keyframe", "ColorPosition_Keyframe")
    for mode, section in sections {
        try IniDelete(gAEConfigFile, section)
        offset := gAEColorOffset.Has(mode) ? gAEColorOffset[mode] : Map("x", 0, "y", 0)
        offsetX := IsObject(offset) && offset.Has("x") ? offset["x"] : 0
        offsetY := IsObject(offset) && offset.Has("y") ? offset["y"] : 0
        IniWrite(offsetX, gAEConfigFile, section, "OffsetX")
        IniWrite(offsetY, gAEConfigFile, section, "OffsetY")

        positions := gAEColorPositions.Has(mode) ? gAEColorPositions[mode] : Map()
        if !IsObject(positions) {
            continue
        }
        for name, pos in positions {
            if !IsObject(pos) {
                continue
            }
            x := pos.Has("x") ? pos["x"] : ""
            y := pos.Has("y") ? pos["y"] : ""
            if (x = "" || y = "") {
                continue
            }
            IniWrite(x, gAEConfigFile, section, name . "X")
            IniWrite(y, gAEConfigFile, section, name . "Y")
        }
    }
}

RemoveAEColorPosition(colorName, mode := "") {
    global gAEColorPositions, gAEConfigGui
    removed := false
    modes := (mode = "") ? ["label", "keyframe"] : [mode]
    for idx, m in modes {
        if !gAEColorPositions.Has(m) {
            continue
        }
        positions := gAEColorPositions[m]
        if (IsObject(positions) && positions.Has(colorName)) {
            positions.Delete(colorName)
            removed := true
        }
    }
    if removed {
        SaveAEColorPositions()
        if (gAEConfigGui.Has("gui")) {
            UpdateAEConfigGui()
        }
    }
    return removed
}

LoadAEConfig() {
    global gAEConfigFile, gAEColorRegion, gAEAlignPositions, gAEColorHex, gAEColorDefaults, gAEColorNames, gAEColorPositions, gAEColorOffset

    for name, hex in gAEColorDefaults {
        gAEColorHex[name] := hex
    }

    if !FileExist(gAEConfigFile) {
        SaveAEColorRegion()
        SaveAEAlignPositions()
        SaveAETrimPositions()
        SaveAEColorHexes()
        SaveAEColorPositions()
        return
    }

    gAEColorRegion["left"] := IniRead(gAEConfigFile, "ColorPanel", "Left", gAEColorRegion["left"])
    gAEColorRegion["top"] := IniRead(gAEConfigFile, "ColorPanel", "Top", gAEColorRegion["top"])
    gAEColorRegion["right"] := IniRead(gAEConfigFile, "ColorPanel", "Right", gAEColorRegion["right"])
    gAEColorRegion["bottom"] := IniRead(gAEConfigFile, "ColorPanel", "Bottom", gAEColorRegion["bottom"])

    gAEAlignPositions["start"]["x"] := IniRead(gAEConfigFile, "Alignment", "StartX", gAEAlignPositions["start"]["x"])
    gAEAlignPositions["start"]["y"] := IniRead(gAEConfigFile, "Alignment", "StartY", gAEAlignPositions["start"]["y"])
    gAEAlignPositions["end"]["x"] := IniRead(gAEConfigFile, "Alignment", "EndX", gAEAlignPositions["end"]["x"])
    gAEAlignPositions["end"]["y"] := IniRead(gAEConfigFile, "Alignment", "EndY", gAEAlignPositions["end"]["y"])

    gAETrimKeyPositions["first"]["x"] := IniRead(gAEConfigFile, "TrimKeys", "FirstX", gAETrimKeyPositions["first"]["x"])
    gAETrimKeyPositions["first"]["y"] := IniRead(gAEConfigFile, "TrimKeys", "FirstY", gAETrimKeyPositions["first"]["y"])
    gAETrimKeyPositions["last"]["x"] := IniRead(gAEConfigFile, "TrimKeys", "LastX", gAETrimKeyPositions["last"]["x"])
    gAETrimKeyPositions["last"]["y"] := IniRead(gAEConfigFile, "TrimKeys", "LastY", gAETrimKeyPositions["last"]["y"])

    for name in gAEColorNames {
        value := IniRead(gAEConfigFile, "ColorHex", name, gAEColorHex[name])
        gAEColorHex[name] := StrUpper(Trim(value))
    }

    gAEColorPositions := Map("label", Map(), "keyframe", Map())

    sections := Map("label", "ColorPosition_Label", "keyframe", "ColorPosition_Keyframe")
    for mode, section in sections {
        offsetX := IniRead(gAEConfigFile, section, "OffsetX", gAEColorOffset[mode]["x"])
        offsetY := IniRead(gAEConfigFile, section, "OffsetY", gAEColorOffset[mode]["y"])
        gAEColorOffset[mode]["x"] := IsNumber(offsetX) ? Round(offsetX) : 0
        gAEColorOffset[mode]["y"] := IsNumber(offsetY) ? Round(offsetY) : 0

        positions := Map()
        for name in gAEColorNames {
            x := IniRead(gAEConfigFile, section, name . "X", "")
            y := IniRead(gAEConfigFile, section, name . "Y", "")
            if (IsNumber(x) && IsNumber(y)) {
                positions[name] := Map("x", Round(x), "y", Round(y))
            }
        }
        gAEColorPositions[mode] := positions
    }

    ; Legacy migration (from single ColorPosition section)
    labelPositions := gAEColorPositions["label"]
    if (labelPositions.Count = 0) {
        legacyPositions := Map()
        legacyFound := false
        for name in gAEColorNames {
            legacyX := IniRead(gAEConfigFile, "ColorPosition", name . "X", "")
            legacyY := IniRead(gAEConfigFile, "ColorPosition", name . "Y", "")
            if (IsNumber(legacyX) && IsNumber(legacyY)) {
                legacyPositions[name] := Map("x", Round(legacyX), "y", Round(legacyY))
                legacyFound := true
            }
        }
        if legacyFound {
            gAEColorPositions["label"] := legacyPositions
            offsetXLegacy := IniRead(gAEConfigFile, "ColorPosition", "OffsetX", "")
            offsetYLegacy := IniRead(gAEConfigFile, "ColorPosition", "OffsetY", "")
            if (offsetXLegacy != "" && IsNumber(offsetXLegacy)) {
                gAEColorOffset["label"]["x"] := Round(offsetXLegacy)
            }
            if (offsetYLegacy != "" && IsNumber(offsetYLegacy)) {
                gAEColorOffset["label"]["y"] := Round(offsetYLegacy)
            }
            SaveAEColorPositions()
        }
        try IniDelete(gAEConfigFile, "ColorPosition")
    }
    try IniDelete(gAEConfigFile, "ColorPosition")
}

RGBHexToBGR(hex) {
    hex := StrUpper(Trim(hex))
    if (StrLen(hex) != 6) {
        return 0
    }
    r := Integer("0x" . SubStr(hex, 1, 2))
    g := Integer("0x" . SubStr(hex, 3, 2))
    b := Integer("0x" . SubStr(hex, 5, 2))
    return (b << 16) | (g << 8) | r
}

IsGuiVisible(gui) {
    try {
        return (IsObject(gui) && DllCall("IsWindowVisible", "ptr", gui.Hwnd, "int"))
    } catch {
        return false
    }
}





