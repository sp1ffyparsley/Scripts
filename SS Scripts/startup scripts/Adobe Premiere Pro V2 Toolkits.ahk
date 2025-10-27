#Requires AutoHotkey v2.0
TraySetIcon(A_ScriptDir . '\..\assets\icons\tray_premiere.ico')

; Optimize input speeds for quicker macro execution
SetKeyDelay(0)
SetMouseDelay(0)
CoordMode('Mouse', 'Screen')

; Shared state and persistence
global gHidePositionsFile := A_ScriptDir . '\..\positions.ini'
global gHideCapture := {active: false, step: 0}
global gColorCapture := {active: false, step: 0, index: 0, data: Map()}
global gExCapture := {active: false, step: 0, data: Map()}
global gMotionCapture := {active: false, step: 0, data: Map()}
global gPinCapture := {active: false, step: 0, data: Map()}
global gTextCapture := {active: false, step: 0, data: Map()}
global gCapturePanel := Map()
global gCaptureSectionOrder := ['hide', 'color', 'gradient', 'excalibur', 'motion', 'text', 'pin']

global gPremiereMotionDragActive := false
global gPremiereColorLookup := Map()
global gPremiereColorPalette := InitPremiereColorPalette()
global gPremiereHotkeyRefs := []
global gPremiereRegisteredCombos := []
global gTextGradientHotkeyCombo := '+F16'
global gTextGradientHotkeysEnabled := true
global gTextGradientHotkeyRefs := []
global gTextGradientRegisteredCombos := []
global gTextGradientDefinitions := InitPremiereTextGradients()
global gGradientCapture := {active: false, step: 0, gradientId: '', data: Map()}

InitPremiereGradientSupport()

InitPremiereColorPalette() {
    global gPremiereColorLookup

    if !IsObject(gPremiereColorLookup) {
        gPremiereColorLookup := Map()
    }

    palette := []
    palette.Push(Map('name', 'Black', 'key', 'Black', 'hex', '000000', 'combo', '!+F13'))
    palette.Push(Map('name', 'Red', 'key', 'Red', 'hex', 'FF0000', 'combo', '!+F14'))
    palette.Push(Map('name', 'Yellow', 'key', 'Yellow', 'hex', 'FFB400', 'combo', '!+F15'))
    palette.Push(Map('name', 'Cyan', 'key', 'Cyan', 'hex', '00C4FF', 'combo', '!+F16'))
    palette.Push(Map('name', 'Pink', 'key', 'Pink', 'hex', 'FF1F8B', 'combo', '!+F17'))
    palette.Push(Map('name', 'Lavender', 'key', 'Lavender', 'hex', '8A30FF', 'combo', '!+F18'))
    palette.Push(Map('name', 'White', 'key', 'White', 'hex', 'FFFFFF', 'combo', '!+F19'))
    palette.Push(Map('name', 'Blue', 'key', 'Blue', 'hex', '0038FF', 'combo', '!+F20'))
    palette.Push(Map('name', 'Green', 'key', 'Green', 'hex', '00D420', 'combo', '!+F21'))
    palette.Push(Map('name', 'Dark Blue', 'key', 'DarkBlue', 'hex', '001E9A', 'combo', '!+F22'))
    palette.Push(Map('name', 'Orange', 'key', 'Orange', 'hex', 'FF6300', 'combo', '!+F23'))
    palette.Push(Map('name', 'Brown', 'key', 'Brown', 'hex', '6A2A10', 'combo', '!+F24'))
    palette.Push(Map('name', 'Hot Orange', 'key', 'HotOrange', 'hex', 'FF3700', 'combo', '#!+F13'))
    palette.Push(Map('name', 'Teal', 'key', 'Teal', 'hex', '007F6A', 'combo', '#!+F14'))
    palette.Push(Map('name', 'Sandstone', 'key', 'Sandstone', 'hex', 'B06A28', 'combo', ''))
    palette.Push(Map('name', 'Dark Green', 'key', 'DarkGreen', 'hex', '006214', 'combo', ''))

    overrides := LoadPremiereColorOverrides()
    for item in palette {
        name := item['name']
        if overrides.Has(name) {
            overrideHex := NormalizePremiereHex(overrides[name])
            if (overrideHex != '') {
                item['hex'] := overrideHex
            }
        }
    }

    gPremiereColorLookup.Clear()
    for item in palette {
        nameLower := StrLower(item['name'])
        keyLower := StrLower(item['key'])
        gPremiereColorLookup[nameLower] := item
        gPremiereColorLookup[keyLower] := item
    }

    EnsurePremiereColorConfig(palette)
    return palette
}

LoadPremiereColorOverrides() {
    result := Map()
    configPath := GetPremiereColorConfigPath()
    if !FileExist(configPath) {
        return result
    }

    try {
        text := FileRead(configPath, 'UTF-8')
    } catch {
        return result
    }

    pos := 1
    while RegExMatch(text, '"([^"\\]+)"\s*:\s*"([^"\\]*)"', &match, pos) {
        pos := match.Pos + match.Len
        name := match[1]
        hex := match[2]
        result[name] := hex
    }
    return result
}

EnsurePremiereColorConfig(palette) {
    if !IsObject(palette) {
        return
    }
    configPath := GetPremiereColorConfigPath()
    SplitPath(configPath, , &configDir)
    if (configDir = '') {
        configDir := A_ScriptDir
    }
    if !DirExist(configDir) {
        DirCreate(configDir)
    }

    lines := []
    lines.Push('{')
    count := palette.Length
    for index, item in palette {
        name := item['name']
        hex := item['hex']
        line := '    "' . name . '": "' . hex . '"'
        if (index < count) {
            line .= ','
        }
        lines.Push(line)
    }
    lines.Push('}')
    newContent := ''
    for i, line in lines {
        if (i > 1) {
            newContent .= '`n'
        }
        newContent .= line
    }

    current := ''
    if FileExist(configPath) {
        try current := FileRead(configPath, 'UTF-8')
    }
    if (Trim(current) = Trim(newContent)) {
        return
    }

    file := FileOpen(configPath, 'w', 'UTF-8')
    if !IsObject(file) {
        return
    }
    file.Write(newContent)
    file.Close()
}

GetPremiereColorConfigPath() {
    return A_ScriptDir . '\.ahkconfig\premiere_colors.json'
}

NormalizePremiereHex(hexValue) {
    hexValue := Trim(hexValue)
    if (hexValue = '') {
        return ''
    }
    if (SubStr(hexValue, 1, 1) = '#') {
        hexValue := SubStr(hexValue, 2)
    } else if (SubStr(StrLower(hexValue), 1, 2) = '0x') {
        hexValue := SubStr(hexValue, 3)
    }
    hexValue := StrUpper(hexValue)
    if RegExMatch(hexValue, '^[0-9A-F]{6}$') {
        return hexValue
    }
    if RegExMatch(hexValue, '^[0-9A-F]{3}$') {
        expanded := ''
        Loop Parse hexValue {
            expanded .= A_LoopField A_LoopField
        }
        return expanded
    }
    return ''
}

PremiereReadActiveHex(maxAttempts := 3) {
    savedClip := ClipboardAll()
    result := ''
    try {
        Loop maxAttempts {
            A_Clipboard := ''
            Sleep(10)
            SendInput('^a')
            Sleep(20)
            SendInput('^c')
            Sleep(30)
            result := NormalizePremiereHex(A_Clipboard)
            if (result != '') {
                break
            }
            Sleep(45)
        }
    } catch {
        result := ''
    } finally {
        try {
            A_Clipboard := savedClip
        } catch {
        }
    }
    return result
}

PremiereHexIsAllowed(hexValue) {
    hexValue := NormalizePremiereHex(hexValue)
    if (hexValue = '') {
        return false
    }
    if (hexValue = '232323') {
        return false
    }
    if (hexValue = 'FFFFFF') {
        return true
    }
    global gPremiereColorPalette
    for item in gPremiereColorPalette {
        if (NormalizePremiereHex(item['hex']) = hexValue) {
            return true
        }
    }
    return false
}

PremiereActivateFillSlot(fill) {
    if !IsObject(fill) {
        return false
    }
    if (fill.Has('x') && fill.Has('y')) {
        x := fill['x']
        y := fill['y']
    } else {
        return false
    }
    if (x = '' || y = '') {
        return false
    }

    ClickAt(x, y)
    Sleep(120)
    normalizedFill := NormalizePremiereHex(PremiereReadActiveHex())
    if (normalizedFill = '232323') {
        return false
    }
    if (normalizedFill != '' && !PremiereHexIsAllowed(normalizedFill)) {
        return false
    }
    return true
}

PremiereReplaceActiveHex(hexValue) {
    normalized := NormalizePremiereHex(hexValue)
    if (normalized = '') {
        return
    }
    Sleep(40)
    SendInput('^a')
    Sleep(20)
    SendInput('{Backspace}')
    Sleep(20)
    SendText(normalized)
}

PremiereDragBetweenPoints(start, target) {
    if !IsObject(start) || !IsObject(target) {
        return
    }
    if !(start.Has('x') && start.Has('y') && target.Has('x') && target.Has('y')) {
        return
    }
    if (start['x'] = '' || start['y'] = '' || target['x'] = '' || target['y'] = '') {
        return
    }
    MouseClickDrag('Left', start['x'], start['y'], target['x'], target['y'], 0)
}

PremiereColorNameToKey(name) {
    clean := RegExReplace(name, '\s+', '')
    return clean
}

GetPremiereColorDefinition(identifier) {
    global gPremiereColorLookup
    if !IsObject(gPremiereColorLookup) {
        return ''
    }
    key := StrLower(Trim(identifier))
    if gPremiereColorLookup.Has(key) {
        return gPremiereColorLookup[key]
    }
    return ''
}

GetPremiereColorKeyList(includeFill := true, includeConfirm := true) {
    keys := []
    if includeFill {
        keys.Push('Fill')
    }
    global gPremiereColorPalette
    for item in gPremiereColorPalette {
        keys.Push(item['key'])
    }
    if includeConfirm {
        keys.Push('Confirm')
    }
    return keys
}

RegisterPremiereColorHotkeys() {
    global gPremiereHotkeyRefs, gPremiereRegisteredCombos, gPremiereColorPalette

    for combo in gPremiereRegisteredCombos {
        try {
            Hotkey(combo, 'Off')
        } catch {
        }
    }

    gPremiereHotkeyRefs := []
    gPremiereRegisteredCombos := []
    seen := Map()

    HotIf IsPremiereWindowActive

    for item in gPremiereColorPalette {
        if !item.Has('combo') {
            continue
        }
        combo := Trim(item['combo'])
        if (combo = '' || seen.Has(combo)) {
            continue
        }
        handler := ApplyPremiereColor.Bind(item['name'])
        gPremiereHotkeyRefs.Push(handler)
        Hotkey(combo, handler)
        gPremiereRegisteredCombos.Push(combo)
        seen[combo] := true
    }

    HotIf
}

InitPremiereTextGradients() {
    gradients := []
    gradients.Push(Map(
        'id', 'RedWhite',
        'name', 'Red to White',
        'hotkey', '+F16',
        'stops', Map('Stop1', 'FF0000', 'Stop2', 'FFFFFF')
    ))
    return gradients
}

InitPremiereGradientSupport() {
    RegisterPremiereGradientHotkeys()
}

RegisterPremiereGradientHotkeys() {
    global gTextGradientHotkeysEnabled, gTextGradientHotkeyRefs, gTextGradientRegisteredCombos, gTextGradientDefinitions, gTextGradientHotkeyCombo

    for combo in gTextGradientRegisteredCombos {
        try {
            Hotkey(combo, 'Off')
        } catch {
        }
    }
    gTextGradientHotkeyRefs := []
    gTextGradientRegisteredCombos := []

    if !gTextGradientHotkeysEnabled {
        return
    }

    HotIf IsPremiereWindowActive

    seen := Map()
    for definition in gTextGradientDefinitions {
        combo := ''
        if definition.Has('hotkey') {
            combo := Trim(definition['hotkey'])
        }
        if (combo = '') {
            combo := gTextGradientHotkeyCombo
        }
        if (combo = '' || seen.Has(combo)) {
            continue
        }
        gradientId := definition.Has('id') ? definition['id'] : ''
        handler := ApplyPremiereTextGradient.Bind(gradientId)
        gTextGradientHotkeyRefs.Push(handler)
        Hotkey(combo, handler)
        gTextGradientRegisteredCombos.Push(combo)
        seen[combo] := true
    }

    HotIf
}

SetTextGradientHotkeysEnabled(enabled) {
    global gTextGradientHotkeysEnabled
    enabled := !!enabled
    if (gTextGradientHotkeysEnabled = enabled) {
        return
    }
    gTextGradientHotkeysEnabled := enabled
    RegisterPremiereGradientHotkeys()
}

GetTextGradientDefinitions() {
    global gTextGradientDefinitions
    return gTextGradientDefinitions
}

GetTextGradientDefinition(identifier := '') {
    definitions := GetTextGradientDefinitions()
    if (definitions.Length = 0) {
        return ''
    }
    if (identifier = '') {
        return definitions[1]
    }
    key := StrLower(Trim(identifier))
    for def in definitions {
        if !def.Has('id') {
            continue
        }
        if (StrLower(def['id']) = key) {
            return def
        }
        if def.Has('name') && (StrLower(def['name']) = key) {
            return def
        }
    }
    return definitions[1]
}

GetTextGradientKeyList() {
    return ['Dropdown', 'Linear', 'Stop1', 'Stop2', 'Hex', 'Midpoint', 'MidpointTarget']
}

GetGradientCaptureSteps() {
    return [
        Map('key', 'Dropdown', 'label', 'Solid dropdown'),
        Map('key', 'Linear', 'label', 'Linear option'),
        Map('key', 'Stop1', 'label', 'First color stop'),
        Map('key', 'Stop2', 'label', 'Second color stop'),
        Map('key', 'Hex', 'label', 'Hex field'),
        Map('key', 'Midpoint', 'label', 'Midpoint handle'),
        Map('key', 'MidpointTarget', 'label', 'Midpoint target')
    ]
}

GetSelectedGradientId(controlMap) {
    if !IsObject(controlMap) || !controlMap.Has('Selector') {
        def := GetTextGradientDefinition()
        return def.Has('id') ? def['id'] : ''
    }
    selector := controlMap['Selector']
    selected := Trim(selector.Value)
    if (selected != '') && controlMap.Has('NameToId') {
        map := controlMap['NameToId']
        if IsObject(map) {
            key := StrLower(selected)
            if map.Has(key) {
                return map[key]
            }
        }
    }
    if controlMap.Has('GradientIds') {
        ids := controlMap['GradientIds']
        if IsObject(ids) && (ids.Length >= 1) {
            if (ids[1] != '') {
                return ids[1]
            }
        }
    }
    def := GetTextGradientDefinition()
    return def.Has('id') ? def['id'] : ''
}

SetSelectedGradientId(controlMap, gradientId) {
    if !IsObject(controlMap) || !controlMap.Has('Selector') {
        return
    }
    selector := controlMap['Selector']
    target := StrLower(Trim(gradientId))
    if (target = '') {
        selector.Choose(1)
        return
    }
    if controlMap.Has('IdToName') {
        map := controlMap['IdToName']
        if IsObject(map) && map.Has(target) {
            selector.Value := map[target]
            return
        }
    }
    selector.Choose(1)
}

UpdateGradientFields(controlMap, gradientId := '') {
    if !IsObject(controlMap) || !controlMap.Has('Fields') {
        return
    }
    if (gradientId != '') {
        SetSelectedGradientId(controlMap, gradientId)
    } else {
        gradientId := GetSelectedGradientId(controlMap)
    }
    data := ReadGradientPositions(gradientId)
    keys := GetTextGradientKeyList()
    FillCapturePanelFields(controlMap['Fields'], data, keys)
}

; Panel focus helper shortcuts (update to match Premiere keyboard shortcuts)
global gPremierePanelShortcuts := Map(
    'timeline', '^!+3',
    'effects', '^!+7',
    'effect controls', '^!+5'
)

EnsurePremiereActive() {
    if WinActive('ahk_exe Adobe Premiere Pro.exe') {
        return true
    }

    try {
        WinActivate('ahk_exe Adobe Premiere Pro.exe')
        WinWaitActive('ahk_exe Adobe Premiere Pro.exe', , 0.4)
    } catch {
    }

    return WinActive('ahk_exe Adobe Premiere Pro.exe')
}

IsPremiereWindowActive(*) {
    return WinActive('ahk_exe Adobe Premiere Pro.exe')
}

FocusPremierePanel(panel) {
    global gPremierePanelShortcuts

    panel := StrLower(panel)
    if !gPremierePanelShortcuts.Has(panel) {
        return false
    }

    Send(gPremierePanelShortcuts[panel])
    Sleep(80)
    return true
}

EnsureTimelineReady() {
    if !EnsurePremiereActive() {
        return false
    }

    return FocusPremierePanel('timeline')
}

; Dismiss the Premiere "delete existing keyframes" warning automatically
SetTimer(ConfirmKeyframeWarning, 200)
RegisterPremiereColorHotkeys()

#HotIf WinActive('ahk_exe Adobe Premiere Pro.exe')
!Numpad0::AdjustmentLayerCrop()
^!k::MuteWithKeyframes()
RButton::HandleTimelineRightClick()
^!j::ToggleHideSelectedWord()
^Backspace::SendInput("^+{Left}{Del}")
#+F19::ToggleCapturePanel()
~LButton::HandlePremiereCaptureClicks()

; Effect Controls – Motion
F13::PremiereToggleMotion()
F14::PremiereAdjustMotionControl('positionX')
F15::PremiereAdjustMotionControl('positionY')
F16::PremiereAdjustMotionControl('scale')
F17::PremiereAdjustMotionControl('rotation')
F18::PremiereAdjustMotionControl('anchorx')
F19::PremiereAdjustMotionControl('anchory')

; Effect Controls – Text
#^+F15::PremiereClickTextEffect()

; Panel & Utility Actions
#F18::PinToClip()
#+F20::ReopenExcalibur()
:*:twx::Twixtor Pro
#HotIf

AdjustmentLayerCrop() {
    if !EnsureTimelineReady() {
        return
    }

    Sleep(1325)
    Send('+{Down}')
    Send('^+d')
    Send('^{Down}')
    Send('{Delete}')
}

MuteWithKeyframes() {
    if !EnsureTimelineReady() {
        return
    }

    Send('p')
    Sleep(50)

    MouseGetPos(&xStart, &yStart)
    xOffset := 55
    yDip := 50

    MouseMove(xStart, yStart, 0)
    Click()
    Sleep(25)

    x2 := xStart + xOffset
    MouseMove(x2, yStart, 0)
    Click()
    Sleep(25)

    x3 := xStart + 2 * xOffset
    MouseMove(x3, yStart, 0)
    Click()
    Sleep(25)

    MouseMove(x2, yStart, 0)
    Send('{LButton down}')
    Sleep(25)
    MouseMove(x2, yStart + yDip, 0)
    Sleep(25)
    Send('{LButton up}')
    Sleep(25)

    MouseMove(xStart, yStart, 50)
}

HandleTimelineRightClick(*) {
    static timelineColors := [0x424242, 0x414141, 0x313131, 0x1b1b1b, 0x202020, 0xDFDFDF, 0xE4E4E4, 0xBEBEBE]
    static selectedColors := [0xDFDFDF, 0xE4E4E4, 0xBEBEBE]

    MouseGetPos(&x, &y)
    color := PixelGetColor(x, y, 'RGB')

    if !ValueInArray(timelineColors, color) {
        SendEvent('{Blind}{RButton}')
        return
    }

    if ValueInArray(selectedColors, color) {
        Send('^+a')
    }

    Send('{MButton}')
    ToolTip('Timeline Playhead Mode')

    while GetKeyState('RButton', 'P') {
        Send('^+!{,}')
        Sleep(16)
    }

    ToolTip()
    Send('{Escape}')
}

ToggleHideSelectedWord(*) {
    if !EnsurePremiereActive() {
        return
    }
    positions := ReadHidePositions()
    if (positions = false) {
        MsgBox('No capture saved yet. Open the capture panel (Win+Shift+F19) to record fill/stroke/shadow toggles.', 'Hide', 'OK Icon!')
        return
    }

    MouseGetPos(&originalX, &originalY)

    ClickAt(positions['fillX'], positions['fillY'])
    ClickAt(positions['strokeX'], positions['strokeY'])
    ClickAt(positions['shadowX'], positions['shadowY'])

    MouseMove(originalX, originalY, 0)
    TrayTip('Word Hidden', 'Fill/Stroke/Shadow toggled off.', 'Mute')
    SetTimer(HideTrayTip, -1500)
}

StartHideCapturePrompt() {
    if !EnsurePremiereActive() {
        return
    }
    if gHideCapture.active {
        MsgBox('Hide capture already running. Finish the clicks or cancel from the capture panel.', 'Capture', 'OK Icon!')
        return
    }

    gHideCapture.active := true
    gHideCapture.step := 1
    TrayTip('Position Capture', 'Click on FILL toggle.', 'Mute')
}

CancelHideCapture() {
    if !gHideCapture.active {
        return
    }
    gHideCapture.active := false
    gHideCapture.step := 0
    TrayTip()
    MsgBox('Cancelled hide position capture.', 'Capture', 'OK Icon!')
}

HandleHideCaptureClick(*) {
    if !gHideCapture.active {
        return
    }

    MouseGetPos(&x, &y)

    switch gHideCapture.step {
        case 1:
            IniWrite(x, gHidePositionsFile, 'Positions', 'FillX')
            IniWrite(y, gHidePositionsFile, 'Positions', 'FillY')
            gHideCapture.step := 2
            TrayTip('Position Capture', 'Click on STROKE toggle.', 'Mute')
            UpdateCapturePanelField('hide', 'FillX', x)
            UpdateCapturePanelField('hide', 'FillY', y)
        case 2:
            IniWrite(x, gHidePositionsFile, 'Positions', 'StrokeX')
            IniWrite(y, gHidePositionsFile, 'Positions', 'StrokeY')
            gHideCapture.step := 3
            TrayTip('Position Capture', 'Click on SHADOW toggle.', 'Mute')
            UpdateCapturePanelField('hide', 'StrokeX', x)
            UpdateCapturePanelField('hide', 'StrokeY', y)
        case 3:
            IniWrite(x, gHidePositionsFile, 'Positions', 'ShadowX')
            IniWrite(y, gHidePositionsFile, 'Positions', 'ShadowY')
            gHideCapture.active := false
            gHideCapture.step := 0
            TrayTip()
            UpdateCapturePanelField('hide', 'ShadowX', x)
            UpdateCapturePanelField('hide', 'ShadowY', y)
            LoadCapturePanelSection('hide')
            MsgBox('Positions saved! Use Ctrl+Alt+J to hide the selected word.', 'Capture', 'OK Icon!')
    }
}

ConfirmKeyframeWarning(*) {
    if WinExist('Warning ahk_exe Adobe Premiere Pro.exe') {
        Send('{Enter}')
        Sleep(100)
    }
}

ReadHidePositions() {
    if !FileExist(gHidePositionsFile) {
        return false
    }

    try {
        fillX := IniRead(gHidePositionsFile, 'Positions', 'FillX', '')
        fillY := IniRead(gHidePositionsFile, 'Positions', 'FillY', '')
        strokeX := IniRead(gHidePositionsFile, 'Positions', 'StrokeX', '')
        strokeY := IniRead(gHidePositionsFile, 'Positions', 'StrokeY', '')
        shadowX := IniRead(gHidePositionsFile, 'Positions', 'ShadowX', '')
        shadowY := IniRead(gHidePositionsFile, 'Positions', 'ShadowY', '')
    } catch {
        return false
    }

    if (fillX = '' || fillY = '' || strokeX = '' || strokeY = '' || shadowX = '' || shadowY = '') {
        return false
    }

    return Map(
        'fillX', fillX,
        'fillY', fillY,
        'strokeX', strokeX,
        'strokeY', strokeY,
        'shadowX', shadowX,
        'shadowY', shadowY
    )
}

ClickAt(x, y) {
    if (x = '' || y = '') {
        return
    }
    MouseMove(x, y, 0)
    Click()
}

ValueInArray(arr, value) {
    for item in arr {
        if (item = value) {
            return true
        }
    }
    return false
}

HandlePremiereCaptureClicks(*) {
    HandleHideCaptureClick()
    HandleColorCaptureClick()
    HandleGradientCaptureClick()
    HandleExCaptureClick()
    HandleMotionCaptureClick()
    HandleTextEffectCaptureClick()
    HandlePinCaptureClick()
}

ToggleCapturePanel(*) {
    if !EnsurePremiereActive() {
        return
    }

    panel := EnsureCapturePanelGui()
    if IsGuiVisible(panel) {
        panel.Hide()
    } else {
        LoadCapturePanelData()
        panel.Show()
    }
}

EnsureCapturePanelGui() {
    global gCapturePanel

    if (IsObject(gCapturePanel) && gCapturePanel.Has('gui') && IsObject(gCapturePanel['gui'])) {
        return gCapturePanel['gui']
    }

    gCapturePanel := Map()
    controls := Map()

    panelGui := Gui('+AlwaysOnTop', 'Premiere Position Manager')
    panelGui.MarginX := 12
    panelGui.MarginY := 12
    panelGui.SetFont('s9')

    tabs := panelGui.Add('Tab', 'w480 h300', ['Hide Toggles', 'Color Presets', 'Text Gradients', 'Excalibur Panel', 'Effect Controls', 'Pin to Clip'])

    controls['hide'] := BuildHideTab(panelGui, tabs)
    controls['color'] := BuildColorTab(panelGui, tabs)
    controls['gradient'] := BuildGradientTab(panelGui, tabs)
    controls['excalibur'] := BuildExcaliburTab(panelGui, tabs)
    effectControls := BuildEffectControlsTab(panelGui, tabs)
    controls['motion'] := effectControls['motion']
    controls['text'] := effectControls['text']
    controls['pin'] := BuildPinTab(panelGui, tabs)

    tabs.UseTab()
    btnClose := panelGui.Add('Button', 'xm y+10 w110', 'Close')
    btnClose.OnEvent('Click', (*) => panelGui.Hide())

    panelGui.OnEvent('Close', (*) => panelGui.Hide())
    panelGui.OnEvent('Escape', (*) => panelGui.Hide())

    gCapturePanel['gui'] := panelGui
    gCapturePanel['controls'] := controls
    return panelGui
}

BuildHideTab(gui, tabs) {
    tabs.UseTab(1)
    controls := Map()

    AddCoordinateRow(gui, 'FILL', controls, 'hide', 'Fill')
    AddCoordinateRow(gui, 'STROKE', controls, 'hide', 'Stroke')
    AddCoordinateRow(gui, 'SHADOW', controls, 'hide', 'Shadow')

    btnCapture := gui.Add('Button', 'xm y+10 w90', 'Capture')
    btnCapture.OnEvent('Click', CapturePanel_HideCapture)
    btnSave := gui.Add('Button', 'x+10 w90', 'Save')
    btnSave.OnEvent('Click', CapturePanel_HideSave)
    btnReload := gui.Add('Button', 'x+10 w90', 'Reload')
    btnReload.OnEvent('Click', (*) => LoadCapturePanelSection('hide'))
    btnCancel := gui.Add('Button', 'x+10 w110', 'Cancel Capture')
    btnCancel.OnEvent('Click', (*) => CancelHideCapture())

    AddOffsetControls(gui, controls, 'hide')
    return controls
}

BuildColorTab(gui, tabs) {
    tabs.UseTab(2)
    controls := Map()

    AddCoordinateRow(gui, 'FILL', controls, 'color', 'Fill')

    global gPremiereColorPalette
    for item in gPremiereColorPalette {
        labelName := StrUpper(item['name'])
        labelText := labelName . ' (#' . item['hex'] . ')'
        AddCoordinateRow(gui, labelText, controls, 'color', item['key'])
    }
    AddCoordinateRow(gui, 'CONFIRM', controls, 'color', 'Confirm')

    btnCapture := gui.Add('Button', 'xm y+10 w90', 'Capture')
    btnCapture.OnEvent('Click', CapturePanel_ColorCapture)
    btnSave := gui.Add('Button', 'x+10 w90', 'Save')
    btnSave.OnEvent('Click', CapturePanel_ColorSave)
    btnReload := gui.Add('Button', 'x+10 w90', 'Reload')
    btnReload.OnEvent('Click', (*) => LoadCapturePanelSection('color'))

    AddOffsetControls(gui, controls, 'color')
    return controls
}

BuildGradientTab(gui, tabs) {
    tabs.UseTab(3)
    controls := Map()

    defs := GetTextGradientDefinitions()
    names := []
    gradientIds := []
    nameToId := Map()
    idToName := Map()
    for def in defs {
        id := def.Has('id') ? def['id'] : ''
        display := ''
        if def.Has('name') {
            display := def['name']
        } else if def.Has('id') {
            display := def['id']
        } else {
            display := 'Gradient ' . (gradientIds.Length + 1)
        }
        gradientIds.Push(id)
        names.Push(display)
        nameToId[StrLower(display)] := id
        if (id != '') {
            idToName[StrLower(id)] := display
        }
    }
    if (names.Length = 0) {
        names.Push('Gradient 1')
        gradientIds.Push('Gradient1')
        nameToId['gradient 1'] := 'Gradient1'
        idToName['gradient1'] := 'Gradient 1'
    }

    gui.Add('Text', 'xm y+10', 'Select gradient:')
    selector := gui.Add('DropDownList', 'x+10 w220', names)
    selector.Choose(1)
    selector.OnEvent('Change', CapturePanel_GradientSelectionChanged)
    controls['Selector'] := selector
    controls['GradientIds'] := gradientIds
    controls['NameToId'] := nameToId
    controls['IdToName'] := idToName

    info := gui.Add('Text', 'xm y+10 w360', 'Fill coordinates are shared with the Color Presets tab.')
    info.SetFont('italic')

    fieldControls := Map()
    AddCoordinateRow(gui, 'SOLID DROPDOWN', fieldControls, 'gradient', 'Dropdown')
    AddCoordinateRow(gui, 'LINEAR OPTION', fieldControls, 'gradient', 'Linear')
    AddCoordinateRow(gui, 'COLOR STOP 1', fieldControls, 'gradient', 'Stop1')
    AddCoordinateRow(gui, 'COLOR STOP 2', fieldControls, 'gradient', 'Stop2')
    AddCoordinateRow(gui, 'HEX FIELD', fieldControls, 'gradient', 'Hex')
    AddCoordinateRow(gui, 'MIDPOINT START', fieldControls, 'gradient', 'Midpoint')
    AddCoordinateRow(gui, 'MIDPOINT TARGET', fieldControls, 'gradient', 'MidpointTarget')
    controls['Fields'] := fieldControls

    btnCapture := gui.Add('Button', 'xm y+12 w200', 'Set positions for this gradient')
    btnCapture.OnEvent('Click', CapturePanel_GradientCapture)
    controls['Capture'] := btnCapture

    btnSave := gui.Add('Button', 'xm y+10 w90', 'Save')
    btnSave.OnEvent('Click', CapturePanel_GradientSave)
    btnReload := gui.Add('Button', 'x+10 w90', 'Reload')
    btnReload.OnEvent('Click', (*) => LoadCapturePanelSection('gradient'))
    controls['Save'] := btnSave
    controls['Reload'] := btnReload

    return controls
}

BuildExcaliburTab(gui, tabs) {
    tabs.UseTab(4)
    controls := Map()

    AddCoordinateRow(gui, 'WINDOW', controls, 'excalibur', 'Window')
    AddCoordinateRow(gui, 'EXTENSIONS', controls, 'excalibur', 'Extensions')
    AddCoordinateRow(gui, 'EXCALIBUR', controls, 'excalibur', 'Excalibur')
    AddCoordinateRow(gui, 'CLOSE', controls, 'excalibur', 'Close')

    btnCapture := gui.Add('Button', 'xm y+10 w90', 'Capture')
    btnCapture.OnEvent('Click', CapturePanel_ExCapture)
    btnSave := gui.Add('Button', 'x+10 w90', 'Save')
    btnSave.OnEvent('Click', CapturePanel_ExSave)
    btnReload := gui.Add('Button', 'x+10 w90', 'Reload')
    btnReload.OnEvent('Click', (*) => LoadCapturePanelSection('excalibur'))

    AddOffsetControls(gui, controls, 'excalibur')
    return controls
}

BuildEffectControlsTab(gui, tabs) {
    tabs.UseTab(5)
    result := Map()

    motionControls := Map()
    motionLabel := gui.Add('Text', 'xm y+8 w140', 'MOTION CONTROLS')
    motionLabel.SetFont('bold')
    motionX := gui.Add('Edit', 'x+10 w70 number')
    gui.Add('Text', 'x+5', 'X')
    motionY := gui.Add('Edit', 'x+10 w70 number')
    gui.Add('Text', 'x+5', 'Y')
    motionControls['MotionToggleX'] := motionX
    motionControls['MotionToggleY'] := motionY

    AddCoordinateRow(gui, 'POSITION X', motionControls, 'motion', 'PositionX')
    AddCoordinateRow(gui, 'POSITION Y', motionControls, 'motion', 'PositionY')
    AddCoordinateRow(gui, 'SCALE', motionControls, 'motion', 'Scale')
    AddCoordinateRow(gui, 'ROTATION', motionControls, 'motion', 'Rotation')
    AddCoordinateRow(gui, 'ANCHOR X', motionControls, 'motion', 'AnchorX')
    AddCoordinateRow(gui, 'ANCHOR Y', motionControls, 'motion', 'AnchorY')

    btnMotionCapture := gui.Add('Button', 'xm y+10 w90', 'Capture')
    btnMotionCapture.OnEvent('Click', CapturePanel_MotionCapture)
    btnMotionSave := gui.Add('Button', 'x+10 w90', 'Save')
    btnMotionSave.OnEvent('Click', CapturePanel_MotionSave)
    btnMotionReload := gui.Add('Button', 'x+10 w90', 'Reload')
    btnMotionReload.OnEvent('Click', (*) => LoadCapturePanelSection('motion'))

    AddOffsetControls(gui, motionControls, 'motion')

    textControls := Map()
    textLabel := gui.Add('Text', 'xm y+20 w140', 'TEXT EFFECT')
    textLabel.SetFont('bold')
    textX := gui.Add('Edit', 'x+10 w70 number')
    gui.Add('Text', 'x+5', 'X')
    textY := gui.Add('Edit', 'x+10 w70 number')
    gui.Add('Text', 'x+5', 'Y')
    textControls['TextEffectX'] := textX
    textControls['TextEffectY'] := textY

    btnTextCapture := gui.Add('Button', 'xm y+10 w90', 'Capture')
    btnTextCapture.OnEvent('Click', CapturePanel_TextCapture)
    btnTextSave := gui.Add('Button', 'x+10 w90', 'Save')
    btnTextSave.OnEvent('Click', CapturePanel_TextSave)
    btnTextReload := gui.Add('Button', 'x+10 w90', 'Reload')
    btnTextReload.OnEvent('Click', (*) => LoadCapturePanelSection('text'))

    result['motion'] := motionControls
    result['text'] := textControls
    return result
}

BuildPinTab(gui, tabs) {
    tabs.UseTab(6)
    controls := Map()

    AddCoordinateRow(gui, 'HAMBURGER MENU', controls, 'pin', 'Hamburger')
    AddCoordinateRow(gui, 'PIN TO CLIP', controls, 'pin', 'Pin')

    btnCapture := gui.Add('Button', 'xm y+10 w90', 'Capture')
    btnCapture.OnEvent('Click', CapturePanel_PinCapture)
    btnSave := gui.Add('Button', 'x+10 w90', 'Save')
    btnSave.OnEvent('Click', CapturePanel_PinSave)
    btnReload := gui.Add('Button', 'x+10 w90', 'Reload')
    btnReload.OnEvent('Click', (*) => LoadCapturePanelSection('pin'))

    AddOffsetControls(gui, controls, 'pin')
    return controls
}

AddCoordinateRow(gui, label, controls, section, prefix) {
    rowLabel := gui.Add('Text', 'xm y+8 w120', label)
    rowLabel.SetFont('bold')
    ctrlX := gui.Add('Edit', 'x+10 w70 number')
    gui.Add('Text', 'x+5', 'X')
    ctrlY := gui.Add('Edit', 'x+10 w70 number')
    gui.Add('Text', 'x+5', 'Y')
    controls[prefix . 'X'] := ctrlX
    controls[prefix . 'Y'] := ctrlY
}

AddOffsetControls(gui, controls, section) {
    gui.Add('Text', 'xm y+15', 'Offset axis:')
    axisCtrl := gui.Add('DropDownList', 'x+5 w80', ['x', 'y', 'both']).Choose(1)
    gui.Add('Text', 'x+10', 'Pixels:')
    amountCtrl := gui.Add('Edit', 'x+5 w60')
    applyBtn := gui.Add('Button', 'x+10 w110', 'Apply Offset')
    applyBtn.OnEvent('Click', (*) => CapturePanel_ApplyOffset(section))
    controls['OffsetAxis'] := axisCtrl
    controls['OffsetAmount'] := amountCtrl
}

LoadCapturePanelData() {
    for section in gCaptureSectionOrder {
        LoadCapturePanelSection(section)
    }
}

LoadCapturePanelSection(section) {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return
    }
    controls := gCapturePanel['controls']
    if !controls.Has(section) {
        return
    }

    switch section {
        case 'hide':
            data := ReadHidePositions()
            FillCapturePanelFields(controls[section], data, ['Fill', 'Stroke', 'Shadow'])
        case 'color':
            data := ReadColorPositions()
            FillCapturePanelFields(controls[section], data, GetPremiereColorKeyList())
        case 'gradient':
            controlMap := controls[section]
            def := GetTextGradientDefinition(GetSelectedGradientId(controlMap))
            if IsObject(def) && def.Has('id') {
                UpdateGradientFields(controlMap, def['id'])
            } else {
                UpdateGradientFields(controlMap)
            }
        case 'excalibur':
            data := ReadExcaliburPositions()
            FillCapturePanelFields(controls[section], data, ['Window', 'Extensions', 'Excalibur', 'Close'])
        case 'motion':
            data := ReadMotionControlPositions()
            FillMotionPanelFields(controls[section], data)
        case 'text':
            data := ReadTextEffectPosition()
            FillCapturePanelFields(controls[section], data, ['TextEffect'])
        case 'pin':
            data := ReadPinPositions()
            FillCapturePanelFields(controls[section], data, ['Hamburger', 'Pin'])
    }
}

FillCapturePanelFields(controlMap, data, keys) {
    if (data = false) {
        for key in keys {
            sx := key . 'X'
            sy := key . 'Y'
            if controlMap.Has(sx)
                controlMap[sx].Value := ''
            if controlMap.Has(sy)
                controlMap[sy].Value := ''
        }
        if controlMap.Has('OffsetAmount')
            controlMap['OffsetAmount'].Value := '5'
        return
    }

    for key in keys {
        lower := StrLower(key)
        if !data.Has(lower) {
            continue
        }
        point := data[lower]
        sx := key . 'X'
        sy := key . 'Y'
        if controlMap.Has(sx)
            controlMap[sx].Value := point['x']
        if controlMap.Has(sy)
            controlMap[sy].Value := point['y']
    }
    if controlMap.Has('OffsetAmount')
        controlMap['OffsetAmount'].Value := '5'
    if controlMap.Has('OffsetAxis') {
        axisCtrl := controlMap['OffsetAxis']
        if IsObject(axisCtrl)
            axisCtrl.Choose(1)
    }
}

FillMotionPanelFields(controlMap, data) {
    if (data = false) {
        for key in ['MotionToggleX', 'MotionToggleY', 'PositionXX', 'PositionXY', 'PositionYX', 'PositionYY', 'ScaleX', 'ScaleY', 'RotationX', 'RotationY', 'AnchorXX', 'AnchorXY', 'AnchorYX', 'AnchorYY'] {
            if controlMap.Has(key)
                controlMap[key].Value := ''
        }
        if controlMap.Has('OffsetAmount')
            controlMap['OffsetAmount'].Value := '5'
        if controlMap.Has('OffsetAxis') {
        axisCtrl := controlMap['OffsetAxis']
        if IsObject(axisCtrl)
            axisCtrl.Choose(1)
    }
        return
    }

    if data.Has('motiontoggle') {
        toggle := data['motiontoggle']
        if controlMap.Has('MotionToggleX')
            controlMap['MotionToggleX'].Value := toggle['x']
        if controlMap.Has('MotionToggleY')
            controlMap['MotionToggleY'].Value := toggle['y']
    }

    for key, mapKey in Map('PositionX', 'positionx', 'PositionY', 'positiony', 'Scale', 'scale', 'Rotation', 'rotation', 'AnchorX', 'anchorx', 'AnchorY', 'anchory') {
        if !controlMap.Has(key . 'X')
            continue
        if !data.Has(mapKey)
            continue
        point := data[mapKey]
        controlMap[key . 'X'].Value := point['x']
        controlMap[key . 'Y'].Value := point['y']
    }

    if controlMap.Has('OffsetAmount')
        controlMap['OffsetAmount'].Value := '5'
    if controlMap.Has('OffsetAxis') {
        axisCtrl := controlMap['OffsetAxis']
        if IsObject(axisCtrl)
            axisCtrl.Choose(1)
    }
}

UpdateCapturePanelField(section, key, value) {
    global gCapturePanel
    if !IsObject(gCapturePanel) || !gCapturePanel.Has('controls') {
        return
    }
    controls := gCapturePanel['controls']
    if !controls.Has(section) {
        return
    }
    sectionControls := controls[section]
    if !sectionControls.Has(key) {
        return
    }
    sectionControls[key].Value := value
}
CapturePanel_HideCapture(*) {
    if !EnsurePremiereActive() {
        MsgBox('Activate Premiere Pro before capturing positions.', 'Capture', 'OK Icon!')
        return
    }
    CancelHideCapture()
    StartHideCapturePrompt()
}

CapturePanel_HideSave(*) {
    if SaveHidePositionsFromGui() {
        TrayTip('Hide Positions', 'Positions saved to positions.ini', 'Mute')
        SetTimer(HideTrayTip, -1500)
    }
}

SaveHidePositionsFromGui() {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return false
    }
    controls := gCapturePanel['controls']['hide']
    required := ['Fill', 'Stroke', 'Shadow']
    values := Map()
    for key in required {
        sx := key . 'X'
        sy := key . 'Y'
        xVal := Trim(controls[sx].Value)
        yVal := Trim(controls[sy].Value)
        if !IsIntegerString(xVal) || !IsIntegerString(yVal) {
            MsgBox('All coordinates must be integers.', 'Hide', 'OK Icon!')
            return false
        }
        values[sx] := xVal
        values[sy] := yVal
    }

    for key, val in values {
        IniWrite(val, gHidePositionsFile, 'Positions', key)
    }
    return true
}

CapturePanel_ColorCapture(*) {
    if !EnsurePremiereActive() {
        MsgBox('Activate Premiere Pro before capturing colors.', 'Color', 'OK Icon!')
        return
    }
    global gColorCapture
    gColorCapture.active := false
    gColorCapture.step := 0
    gColorCapture.index := 0
    gColorCapture.data := Map()
    StartColorCapture()
}

CapturePanel_ColorSave(*) {
    if SaveColorPositionsFromGui() {
        TrayTip('Color Presets', 'Color coordinates saved.', 'Mute')
        SetTimer(HideTrayTip, -1500)
    }
}

CapturePanel_GradientSave(*) {
    if SaveGradientPositionsFromGui() {
        TrayTip('Text Gradients', 'Gradient coordinates saved.', 'Mute')
        SetTimer(HideTrayTip, -1500)
    }
}

CapturePanel_GradientSelectionChanged(ctrl, *) {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return
    }
    controls := gCapturePanel['controls']
    if !controls.Has('gradient') {
        return
    }
    controlMap := controls['gradient']
    UpdateGradientFields(controlMap)
}

CapturePanel_GradientCapture(*) {
    if !EnsurePremiereActive() {
        MsgBox('Activate Premiere Pro before capturing gradient positions.', 'Text Gradients', 'OK Icon!')
        return
    }
    global gCapturePanel, gGradientCapture
    if gGradientCapture.active {
        MsgBox('Gradient capture already running. Complete the capture or wait before starting a new one.', 'Text Gradients', 'OK Icon!')
        return
    }
    if !gCapturePanel.Has('controls') {
        return
    }
    controls := gCapturePanel['controls']
    if !controls.Has('gradient') {
        return
    }
    controlMap := controls['gradient']
    definition := GetTextGradientDefinition(GetSelectedGradientId(controlMap))
    if !IsObject(definition) || !definition.Has('id') {
        MsgBox('Select a gradient before capturing positions.', 'Text Gradients', 'OK Icon!')
        return
    }
    StartGradientCapture(definition['id'])
}

StartGradientCapture(gradientId) {
    global gGradientCapture
    if (gradientId = '') {
        return
    }
    gGradientCapture.active := true
    gGradientCapture.step := 1
    gGradientCapture.gradientId := gradientId
    gGradientCapture.data := Map()
    steps := GetGradientCaptureSteps()
    if (steps.Length >= 1) {
        first := steps[1]
        TrayTip('Text Gradients', 'Step 1: Click the ' . first['label'] . '.', 'Mute')
    }
}

CancelGradientCapture(showMessage := true) {
    global gGradientCapture
    if !gGradientCapture.active {
        return
    }
    gGradientCapture.active := false
    gGradientCapture.step := 0
    gGradientCapture.gradientId := ''
    gGradientCapture.data := Map()
    if showMessage {
        TrayTip('Text Gradients', 'Gradient capture cancelled.', 'Mute')
        SetTimer(HideTrayTip, -1500)
    }
}

HandleGradientCaptureClick(*) {
    global gGradientCapture, gCapturePanel
    if !gGradientCapture.active {
        return
    }
    steps := GetGradientCaptureSteps()
    currentStep := gGradientCapture.step
    if (currentStep < 1 || currentStep > steps.Length) {
        CancelGradientCapture(false)
        return
    }
    stepInfo := steps[currentStep]
    MouseGetPos(&mx, &my)
    gGradientCapture.data[stepInfo['key'] . 'X'] := Integer(mx)
    gGradientCapture.data[stepInfo['key'] . 'Y'] := Integer(my)
    gGradientCapture.step += 1

    if (gGradientCapture.step > steps.Length) {
        gradientId := gGradientCapture.gradientId
        data := gGradientCapture.data
        gGradientCapture.active := false
        gGradientCapture.step := 0
        gGradientCapture.gradientId := ''
        gGradientCapture.data := Map()
        SaveGradientPositions(data, gradientId)
        if gCapturePanel.Has('controls') && gCapturePanel['controls'].Has('gradient') {
            UpdateGradientFields(gCapturePanel['controls']['gradient'], gradientId)
        }
        TrayTip('Text Gradients', 'Gradient coordinates captured.', 'Mute')
        SetTimer(HideTrayTip, -1500)
    } else {
        nextInfo := steps[gGradientCapture.step]
        TrayTip('Text Gradients', 'Next: Click the ' . nextInfo['label'] . '.', 'Mute')
    }
}

SaveColorPositionsFromGui() {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return false
    }
    controls := gCapturePanel['controls']['color']
    keys := GetPremiereColorKeyList()
    data := Map()
    for key in keys {
        sx := key . 'X'
        sy := key . 'Y'
        xVal := Trim(controls[sx].Value)
        yVal := Trim(controls[sy].Value)
        if !IsIntegerString(xVal) || !IsIntegerString(yVal) {
            MsgBox('All color coordinates must be integers.', 'Color', 'OK Icon!')
            return false
        }
        data[sx] := xVal
        data[sy] := yVal
    }

    SaveColorPositions(data)
    return true
}

SaveGradientPositionsFromGui() {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return false
    }
    controls := gCapturePanel['controls']
    if !controls.Has('gradient') {
        return false
    }
    controlMap := controls['gradient']
    if !controlMap.Has('Fields') {
        return false
    }
    fields := controlMap['Fields']
    definition := GetTextGradientDefinition(GetSelectedGradientId(controlMap))
    if !IsObject(definition) || !definition.Has('id') {
        MsgBox('Select a gradient before saving coordinates.', 'Text Gradients', 'OK Icon!')
        return false
    }
    gradientId := definition['id']
    keys := GetTextGradientKeyList()
    data := Map()
    for key in keys {
        sx := key . 'X'
        sy := key . 'Y'
        if !fields.Has(sx) || !fields.Has(sy) {
            MsgBox('Missing gradient coordinate control: ' . key, 'Text Gradients', 'OK Icon!')
            return false
        }
        xVal := Trim(fields[sx].Value)
        yVal := Trim(fields[sy].Value)
        if !IsIntegerString(xVal) || !IsIntegerString(yVal) {
            MsgBox('All gradient coordinates must be integers.', 'Text Gradients', 'OK Icon!')
            return false
        }
        data[sx] := Integer(xVal)
        data[sy] := Integer(yVal)
    }
    SaveGradientPositions(data, gradientId)
    UpdateGradientFields(controlMap, gradientId)
    return true
}

CapturePanel_ExCapture(*) {
    if !EnsurePremiereActive() {
        MsgBox('Activate Premiere Pro before capturing positions.', 'Capture', 'OK Icon!')
        return
    }
    global gExCapture
    gExCapture.active := false
    gExCapture.step := 0
    gExCapture.data := Map()
    StartExcaliburCapture()
}

CapturePanel_ExSave(*) {
    if SaveExcaliburPositionsFromGui() {
        TrayTip('Excalibur', 'Positions saved to positions.ini', 'Mute')
        SetTimer(HideTrayTip, -1500)
    }
}

SaveExcaliburPositionsFromGui() {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return false
    }
    controls := gCapturePanel['controls']['excalibur']
    keys := ['Window', 'Extensions', 'Excalibur', 'Close']
    data := Map()
    for key in keys {
        sx := key . 'X'
        sy := key . 'Y'
        xVal := Trim(controls[sx].Value)
        yVal := Trim(controls[sy].Value)
        if !IsIntegerString(xVal) || !IsIntegerString(yVal) {
            MsgBox('All coordinates must be integers.', 'Excalibur', 'OK Icon!')
            return false
        }
        data[sx] := xVal
        data[sy] := yVal
    }

    ini := gHidePositionsFile
    IniWrite(data['WindowX'], ini, 'Excalibur', 'WindowX')
    IniWrite(data['WindowY'], ini, 'Excalibur', 'WindowY')
    IniWrite(data['ExtensionsX'], ini, 'Excalibur', 'ExtensionsX')
    IniWrite(data['ExtensionsY'], ini, 'Excalibur', 'ExtensionsY')
    IniWrite(data['ExcaliburX'], ini, 'Excalibur', 'ExcaliburX')
    IniWrite(data['ExcaliburY'], ini, 'Excalibur', 'ExcaliburY')
    IniWrite(data['CloseX'], ini, 'Excalibur', 'CloseX')
    IniWrite(data['CloseY'], ini, 'Excalibur', 'CloseY')
    return true
}

CapturePanel_MotionCapture(*) {
    if !EnsurePremiereActive() {
        MsgBox('Activate Premiere Pro before capturing positions.', 'Capture', 'OK Icon!')
        return
    }
    global gMotionCapture
    gMotionCapture.active := false
    gMotionCapture.step := 0
    gMotionCapture.data := Map()
    StartMotionCapture()
}

CapturePanel_MotionSave(*) {
    if SaveMotionPositionsFromGui() {
        TrayTip('Motion Controls', 'Positions saved to positions.ini', 'Mute')
        SetTimer(HideTrayTip, -1500)
    }
}

CapturePanel_TextCapture(*) {
    if !EnsurePremiereActive() {
        MsgBox('Activate Premiere Pro before capturing positions.', 'Capture', 'OK Icon!')
        return
    }
    global gTextCapture
    gTextCapture.active := true
    gTextCapture.step := 1
    gTextCapture.data := Map()
    TrayTip('Text Effect Capture', 'Click the text effect control.', 'Mute')
}

CapturePanel_TextSave(*) {
    if SaveTextEffectPositionFromGui() {
        TrayTip('Text Effect', 'Position saved to positions.ini', 'Mute')
        SetTimer(HideTrayTip, -1500)
    }
}

SaveMotionPositionsFromGui() {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return false
    }
    controls := gCapturePanel['controls']['motion']

    coords := Map(
        'MotionToggleX', Trim(controls['MotionToggleX'].Value),
        'MotionToggleY', Trim(controls['MotionToggleY'].Value),
        'PositionXX', Trim(controls['PositionXX'].Value),
        'PositionXY', Trim(controls['PositionXY'].Value),
        'PositionYX', Trim(controls['PositionYX'].Value),
        'PositionYY', Trim(controls['PositionYY'].Value),
        'ScaleX', Trim(controls['ScaleX'].Value),
        'ScaleY', Trim(controls['ScaleY'].Value),
        'RotationX', Trim(controls['RotationX'].Value),
        'RotationY', Trim(controls['RotationY'].Value),
        'AnchorXX', Trim(controls['AnchorXX'].Value),
        'AnchorXY', Trim(controls['AnchorXY'].Value),
        'AnchorYX', Trim(controls['AnchorYX'].Value),
        'AnchorYY', Trim(controls['AnchorYY'].Value)
    )

    for key, val in coords {
        if !IsIntegerString(val) {
            MsgBox('All motion coordinates must be integers.', 'Motion', 'OK Icon!')
            return false
        }
    }

    ini := gHidePositionsFile
    for key, val in coords {
        IniWrite(val, ini, 'MotionControls', key)
    }
    IniDelete(ini, 'MotionControls', 'AnchorX')
    IniDelete(ini, 'MotionControls', 'AnchorY')
    IniDelete(ini, 'MotionControls', 'MotionToggleColor')
    return true
}

SaveTextEffectPositionFromGui() {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return false
    }
    controls := gCapturePanel['controls']['text']
    if !controls.Has('TextEffectX') || !controls.Has('TextEffectY') {
        return false
    }

    xVal := Trim(controls['TextEffectX'].Value)
    yVal := Trim(controls['TextEffectY'].Value)
    if !IsIntegerString(xVal) || !IsIntegerString(yVal) {
        MsgBox('Text effect coordinates must be integers.', 'Text Effect', 'OK Icon!')
        return false
    }

    SaveTextEffectPosition(Map('x', Integer(xVal), 'y', Integer(yVal)))
    return true
}

ReadTextEffectPosition() {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    try {
        posX := IniRead(ini, 'TextEffect', 'TextEffectX', '')
        posY := IniRead(ini, 'TextEffect', 'TextEffectY', '')
    } catch {
        return false
    }

    if (posX = '' || posY = '') {
        return false
    }

    return Map('texteffect', Map('x', posX, 'y', posY))
}

SaveTextEffectPosition(data) {
    if !IsObject(data) || !data.Has('x') || !data.Has('y') {
        return
    }
    ini := gHidePositionsFile
    IniWrite(Integer(data['x']), ini, 'TextEffect', 'TextEffectX')
    IniWrite(Integer(data['y']), ini, 'TextEffect', 'TextEffectY')
}

CapturePanel_PinCapture(*) {
    if !EnsurePremiereActive() {
        MsgBox('Activate Premiere Pro before capturing positions.', 'Capture', 'OK Icon!')
        return
    }
    global gPinCapture
    gPinCapture.active := false
    gPinCapture.step := 0
    gPinCapture.data := Map()
    StartPinCapture()
}

CapturePanel_PinSave(*) {
    if SavePinPositionsFromGui() {
        TrayTip('Pin to Clip', 'Positions saved to positions.ini', 'Mute')
        SetTimer(HideTrayTip, -1500)
    }
}

SavePinPositionsFromGui() {
    global gCapturePanel
    if !gCapturePanel.Has('controls') {
        return false
    }
    controls := gCapturePanel['controls']['pin']

    coords := Map(
        'HamburgerX', Trim(controls['HamburgerX'].Value),
        'HamburgerY', Trim(controls['HamburgerY'].Value),
        'PinX', Trim(controls['PinX'].Value),
        'PinY', Trim(controls['PinY'].Value)
    )

    for key, val in coords {
        if !IsIntegerString(val) {
            MsgBox('All pin-to-clip coordinates must be integers.', 'Pin to Clip', 'OK Icon!')
            return false
        }
    }

    SavePinPositions(coords)
    return true
}

CapturePanel_ApplyOffset(section) {
    axis := GetOffsetAxis(section)
    if (axis = '') {
        return
    }
    amount := GetOffsetAmount(section)
    if (amount = '') {
        return
    }

    if !OffsetPremierePositions(section, axis, amount) {
        MsgBox('No saved positions for "' . section . '" yet.', 'Offset', 'OK Icon!')
        return
    }

    TrayTip('Offset Applied', StrTitle(section) . ' ' . axis . ' ' . Format('{:+d}px', amount), 'Mute')
    SetTimer(HideTrayTip, -1500)
    LoadCapturePanelSection(section)
}

GetOffsetAxis(section) {
    global gCapturePanel
    controls := gCapturePanel['controls'][section]
    if !controls.Has('OffsetAxis') {
        return ''
    }
    axis := StrLower(Trim(controls['OffsetAxis'].Text))
    if (axis = 'xy' || axis = 'yx')
        axis := 'both'
    if !(axis = 'x' || axis = 'y' || axis = 'both') {
        MsgBox('Axis must be x, y, or both.', 'Offset', 'OK Icon!')
        return ''
    }
    return axis
}

GetOffsetAmount(section) {
    global gCapturePanel
    controls := gCapturePanel['controls'][section]
    if !controls.Has('OffsetAmount') {
        return ''
    }
    amountStr := Trim(controls['OffsetAmount'].Value)
    if !IsIntegerString(amountStr) {
        MsgBox('Offset must be an integer.', 'Offset', 'OK Icon!')
        return ''
    }
    return Integer(amountStr)
}

StartColorCapture() {
    if !EnsurePremiereActive() {
        return
    }
    global gColorCapture
    gColorCapture.active := true
    gColorCapture.step := 1
    gColorCapture.index := 0
    gColorCapture.data := Map()
    TrayTip('Color Capture', 'Step 1: Click the Fill color swatch.', 'Mute')
}

StartExcaliburCapture() {
    if !EnsurePremiereActive() {
        return
    }
    global gExCapture
    gExCapture.active := true
    gExCapture.step := 1
    gExCapture.data := Map()
    TrayTip('Excalibur Capture', 'Step 1: Click the Window menu.', 'Mute')
}

StartMotionCapture() {
    if !EnsurePremiereActive() {
        return
    }
    global gMotionCapture
    gMotionCapture.active := true
    gMotionCapture.step := 1
    gMotionCapture.data := Map()
    TrayTip('Motion Capture', 'Step 1: Click the Motion toggle (ensure it is ON).', 'Mute')
}

StartPinCapture() {
    if !EnsurePremiereActive() {
        return
    }
    global gPinCapture
    gPinCapture.active := true
    gPinCapture.step := 1
    gPinCapture.data := Map()
    TrayTip('Pin Capture', 'Step 1: Click the hamburger menu.', 'Mute')
}

HandleColorCaptureClick(*) {
    global gColorCapture, gPremiereColorPalette
    if !gColorCapture.active {
        return
    }

    MouseGetPos(&x, &y)
    data := gColorCapture.data
    colorCount := gPremiereColorPalette.Length

    switch gColorCapture.step {
        case 1:
            data['FillX'] := x
            data['FillY'] := y
            gColorCapture.step := 2
            gColorCapture.index := 0
            UpdateCapturePanelField('color', 'FillX', x)
            UpdateCapturePanelField('color', 'FillY', y)
            if (colorCount >= 1) {
                nextColor := gPremiereColorPalette[1]
                TrayTip('Color Capture', Format('Step 2: Click {1} (#{2}).', StrUpper(nextColor['name']), nextColor['hex']), 'Mute')
            } else {
                TrayTip('Color Capture', 'Final step: Click the Confirm/OK button.', 'Mute')
            }
        default:
            colorStepMax := colorCount + 1
            if (gColorCapture.step >= 2 && gColorCapture.step <= colorStepMax) {
                colorIndex := gColorCapture.step - 1
                color := gPremiereColorPalette[colorIndex]
                key := color['key']
                data[key . 'X'] := x
                data[key . 'Y'] := y
                UpdateCapturePanelField('color', key . 'X', x)
                UpdateCapturePanelField('color', key . 'Y', y)
                gColorCapture.step += 1
                if (gColorCapture.step <= colorStepMax) {
                    nextColor := gPremiereColorPalette[gColorCapture.step - 1]
                    TrayTip('Color Capture', Format('Next: Click {1} (#{2}).', StrUpper(nextColor['name']), nextColor['hex']), 'Mute')
                } else {
                    TrayTip('Color Capture', 'Final step: Click the Confirm/OK button.', 'Mute')
                }
            } else if (gColorCapture.step = colorStepMax + 1) {
                data['ConfirmX'] := x
                data['ConfirmY'] := y
                gColorCapture.active := false
                gColorCapture.step := 0
                SaveColorPositions(data)
                TrayTip('Color Capture', 'Color presets saved!', 'Mute')
                SetTimer(HideTrayTip, -1600)
                UpdateCapturePanelField('color', 'ConfirmX', x)
                UpdateCapturePanelField('color', 'ConfirmY', y)
                LoadCapturePanelSection('color')
            }
    }
}

HandleExCaptureClick(*) {
    global gExCapture
    if !gExCapture.active {
        return
    }

    MouseGetPos(&x, &y)
    data := gExCapture.data

    switch gExCapture.step {
        case 1:
            data['WindowX'] := x
            data['WindowY'] := y
            gExCapture.step := 2
            TrayTip('Excalibur Capture', 'Step 2: Click Extensions.', 'Mute')
            UpdateCapturePanelField('excalibur', 'WindowX', x)
            UpdateCapturePanelField('excalibur', 'WindowY', y)
        case 2:
            data['ExtensionsX'] := x
            data['ExtensionsY'] := y
            gExCapture.step := 3
            TrayTip('Excalibur Capture', 'Step 3: Click Excalibur in the submenu.', 'Mute')
            UpdateCapturePanelField('excalibur', 'ExtensionsX', x)
            UpdateCapturePanelField('excalibur', 'ExtensionsY', y)
        case 3:
            data['ExcaliburX'] := x
            data['ExcaliburY'] := y
            gExCapture.step := 4
            TrayTip('Excalibur Capture', 'Step 4: Click the panel close button.', 'Mute')
            UpdateCapturePanelField('excalibur', 'ExcaliburX', x)
            UpdateCapturePanelField('excalibur', 'ExcaliburY', y)
        case 4:
            data['CloseX'] := x
            data['CloseY'] := y
            SaveExcaliburPositions(data)
            TrayTip('Excalibur Capture', 'Positions saved!', 'Mute')
            SetTimer(HideTrayTip, -1600)
            gExCapture.active := false
            gExCapture.step := 0
            gExCapture.data := Map()
            LoadCapturePanelSection('excalibur')
    }
}

HandleMotionCaptureClick(*) {
    global gMotionCapture
    if !gMotionCapture.active {
        return
    }

    MouseGetPos(&x, &y)
    data := gMotionCapture.data

    switch gMotionCapture.step {
        case 1:
            data['MotionToggleX'] := x
            data['MotionToggleY'] := y
            gMotionCapture.step := 2
            TrayTip('Motion Capture', 'Step 2: Click the Position X value.', 'Mute')
            UpdateCapturePanelField('motion', 'MotionToggleX', x)
            UpdateCapturePanelField('motion', 'MotionToggleY', y)
        case 2:
            data['PositionXX'] := x
            data['PositionXY'] := y
            gMotionCapture.step := 3
            TrayTip('Motion Capture', 'Step 3: Click the Position Y value.', 'Mute')
            UpdateCapturePanelField('motion', 'PositionXX', x)
            UpdateCapturePanelField('motion', 'PositionXY', y)
        case 3:
            data['PositionYX'] := x
            data['PositionYY'] := y
            gMotionCapture.step := 4
            TrayTip('Motion Capture', 'Step 4: Click the Scale value.', 'Mute')
            UpdateCapturePanelField('motion', 'PositionYX', x)
            UpdateCapturePanelField('motion', 'PositionYY', y)
        case 4:
            data['ScaleX'] := x
            data['ScaleY'] := y
            gMotionCapture.step := 5
            TrayTip('Motion Capture', 'Step 5: Click the Rotation value.', 'Mute')
            UpdateCapturePanelField('motion', 'ScaleX', x)
            UpdateCapturePanelField('motion', 'ScaleY', y)
        case 5:
            data['RotationX'] := x
            data['RotationY'] := y
            gMotionCapture.step := 6
            TrayTip('Motion Capture', 'Step 6: Click the Anchor X value.', 'Mute')
            UpdateCapturePanelField('motion', 'RotationX', x)
            UpdateCapturePanelField('motion', 'RotationY', y)
        case 6:
            data['AnchorXX'] := x
            data['AnchorXY'] := y
            gMotionCapture.step := 7
            TrayTip('Motion Capture', 'Step 7: Click the Anchor Y value.', 'Mute')
            UpdateCapturePanelField('motion', 'AnchorXX', x)
            UpdateCapturePanelField('motion', 'AnchorXY', y)
        case 7:
            data['AnchorYX'] := x
            data['AnchorYY'] := y
            UpdateCapturePanelField('motion', 'AnchorYX', x)
            UpdateCapturePanelField('motion', 'AnchorYY', y)
            SaveMotionPositions(data)
            TrayTip('Motion Capture', 'Motion controls saved!', 'Mute')
            SetTimer(HideTrayTip, -1600)
            gMotionCapture.active := false
            gMotionCapture.step := 0
            gMotionCapture.data := Map()
            LoadCapturePanelSection('motion')
    }
}

HandleTextEffectCaptureClick(*) {
    global gTextCapture
    if !gTextCapture.active {
        return
    }

    MouseGetPos(&x, &y)
    gTextCapture.active := false
    gTextCapture.step := 0
    gTextCapture.data := Map()

    SaveTextEffectPosition(Map('x', x, 'y', y))
    TrayTip('Text Effect Capture', 'Position saved!', 'Mute')
    SetTimer(HideTrayTip, -1500)
    UpdateCapturePanelField('text', 'TextEffectX', x)
    UpdateCapturePanelField('text', 'TextEffectY', y)
    LoadCapturePanelSection('text')
}

HandlePinCaptureClick(*) {
    global gPinCapture
    if !gPinCapture.active {
        return
    }

    MouseGetPos(&x, &y)
    data := gPinCapture.data

    switch gPinCapture.step {
        case 1:
            data['HamburgerX'] := x
            data['HamburgerY'] := y
            gPinCapture.step := 2
            TrayTip('Pin Capture', 'Step 2: Click "Pin to Clip".', 'Mute')
            UpdateCapturePanelField('pin', 'HamburgerX', x)
            UpdateCapturePanelField('pin', 'HamburgerY', y)
        case 2:
            data['PinX'] := x
            data['PinY'] := y
            SavePinPositions(data)
            TrayTip('Pin Capture', 'Pin to Clip saved!', 'Mute')
            SetTimer(HideTrayTip, -1600)
            gPinCapture.active := false
            gPinCapture.step := 0
            gPinCapture.data := Map()
            UpdateCapturePanelField('pin', 'PinX', x)
            UpdateCapturePanelField('pin', 'PinY', y)
            LoadCapturePanelSection('pin')
    }
}

ReadColorPositions() {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    try {
        fillX := IniRead(ini, 'ColorSlots', 'FillX', '')
        fillY := IniRead(ini, 'ColorSlots', 'FillY', '')
        confirmX := IniRead(ini, 'ColorSlots', 'ConfirmX', '')
        confirmY := IniRead(ini, 'ColorSlots', 'ConfirmY', '')
    } catch {
        return false
    }

    data := Map()
    data['fill'] := Map('x', fillX, 'y', fillY)
    data['confirm'] := Map('x', confirmX, 'y', confirmY)

    global gPremiereColorPalette
    hasColorData := false

    for item in gPremiereColorPalette {
        key := item['key']
        lowerKey := StrLower(key)
        try {
            cx := IniRead(ini, 'ColorSlots', key . 'X', '')
            cy := IniRead(ini, 'ColorSlots', key . 'Y', '')
        } catch {
            cx := ''
            cy := ''
        }
        if (cx != '' && cy != '') {
            hasColorData := true
        }
        data[lowerKey] := Map(
            'x', cx,
            'y', cy,
            'name', item['name'],
            'hex', item['hex'],
            'key', key
        )
    }

    if (fillX = '' || fillY = '' || confirmX = '' || confirmY = '') {
        if MigrateLegacyColorSlots(ini) {
            return ReadColorPositions()
        }
        return false
    }

    if !hasColorData {
        if MigrateLegacyColorSlots(ini) {
            return ReadColorPositions()
        }
    }

    return data
}

ReadGradientPositions(gradientId := '') {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    if (gradientId = '') {
        def := GetTextGradientDefinition()
        if IsObject(def) && def.Has('id') {
            gradientId := def['id']
        } else {
            gradientId := 'Gradient1'
        }
    }

    keys := GetTextGradientKeyList()
    data := Map()
    try {
        for key in keys {
            x := IniRead(ini, 'GradientSlots', gradientId . '_' . key . 'X', '')
            y := IniRead(ini, 'GradientSlots', gradientId . '_' . key . 'Y', '')
            data[StrLower(key)] := Map('x', x, 'y', y)
        }
    } catch {
        return false
    }
    data['gradient'] := gradientId
    return data
}

SaveColorPositions(data) {
    ini := gHidePositionsFile
    keys := GetPremiereColorKeyList()
    for key in keys {
        sx := key . 'X'
        sy := key . 'Y'
        xVal := data.Has(sx) ? data[sx] : ''
        yVal := data.Has(sy) ? data[sy] : ''
        IniWrite(xVal, ini, 'ColorSlots', sx)
        IniWrite(yVal, ini, 'ColorSlots', sy)
    }
}

SaveGradientPositions(data, gradientId := '') {
    ini := gHidePositionsFile
    if (gradientId = '') {
        def := GetTextGradientDefinition()
        if IsObject(def) && def.Has('id') {
            gradientId := def['id']
        } else {
            gradientId := 'Gradient1'
        }
    }
    keys := GetTextGradientKeyList()
    for key in keys {
        sx := gradientId . '_' . key . 'X'
        sy := gradientId . '_' . key . 'Y'
        dataKeyX := key . 'X'
        dataKeyY := key . 'Y'
        xVal := ''
        yVal := ''
        if data.Has(sx) {
            xVal := data[sx]
        } else if data.Has(dataKeyX) {
            xVal := data[dataKeyX]
        }
        if data.Has(sy) {
            yVal := data[sy]
        } else if data.Has(dataKeyY) {
            yVal := data[dataKeyY]
        }
        IniWrite(xVal, ini, 'GradientSlots', sx)
        IniWrite(yVal, ini, 'GradientSlots', sy)
    }
}

MigrateLegacyColorSlots(ini) {
    legacy := Map(
        'Slot1', 'Red',
        'Slot2', 'Green',
        'Slot3', 'Pink',
        'Slot4', 'Blue'
    )

    data := Map()
    try {
        data['FillX'] := IniRead(ini, 'ColorSlots', 'FillX', '')
        data['FillY'] := IniRead(ini, 'ColorSlots', 'FillY', '')
        data['ConfirmX'] := IniRead(ini, 'ColorSlots', 'ConfirmX', '')
        data['ConfirmY'] := IniRead(ini, 'ColorSlots', 'ConfirmY', '')
    } catch {
        return false
    }

    migrated := false
    for legacyKey, colorName in legacy {
        try {
            lx := IniRead(ini, 'ColorSlots', legacyKey . 'X', '')
            ly := IniRead(ini, 'ColorSlots', legacyKey . 'Y', '')
        } catch {
            lx := ''
            ly := ''
        }
        if (lx = '' || ly = '') {
            continue
        }
        newKey := PremiereColorNameToKey(colorName)
        data[newKey . 'X'] := lx
        data[newKey . 'Y'] := ly
        migrated := true
    }

    if !migrated {
        return false
    }

    SaveColorPositions(data)

    for legacyKey, _ in legacy {
        try IniDelete(ini, 'ColorSlots', legacyKey . 'X')
        try IniDelete(ini, 'ColorSlots', legacyKey . 'Y')
    }
    return true
}

ApplyPremiereColor(colorName, *) {
    if !EnsurePremiereActive() {
        return
    }

    positions := ReadColorPositions()
    if (positions = false) {
        MsgBox('Run the color capture before using color hotkeys.', 'Color', 'OK Icon!')
        return
    }

    if !positions.Has('fill') || !positions.Has('confirm') {
        MsgBox('Color capture is incomplete. Re-run the color capture wizard.', 'Color', 'OK Icon!')
        return
    }

    fill := positions['fill']
    confirm := positions['confirm']
    if (fill['x'] = '' || fill['y'] = '' || confirm['x'] = '' || confirm['y'] = '') {
        MsgBox('Color capture is incomplete. Re-run the color capture wizard.', 'Color', 'OK Icon!')
        return
    }

    definition := GetPremiereColorDefinition(colorName)
    if !IsObject(definition) {
        MsgBox('Unknown color "' . colorName . '".', 'Color', 'OK Icon!')
        return
    }

    keyLower := StrLower(definition['key'])
    if !positions.Has(keyLower) {
        MsgBox('Color "' . definition['name'] . '" is not configured.', 'Color', 'OK Icon!')
        return
    }

    target := positions[keyLower]
    if (target['x'] = '' || target['y'] = '') {
        MsgBox('Color "' . definition['name'] . '" is not configured.', 'Color', 'OK Icon!')
        return
    }

    if !PremiereActivateFillSlot(fill) {
        return
    }
    ClickAt(target['x'], target['y'])
    Sleep(70)

    PremiereReplaceActiveHex(definition['hex'])

    Sleep(60)
    if (confirm['x'] = target['x'] && confirm['y'] = target['y']) {
        SendInput('{Enter}')
    } else {
        ClickAt(confirm['x'], confirm['y'])
    }
}

ApplyPremiereTextGradient(gradientId := '') {
    if !EnsurePremiereActive() {
        return
    }

    definition := GetTextGradientDefinition(gradientId)
    if !IsObject(definition) {
        MsgBox('No text gradient definition found.', 'Text Gradients', 'OK Icon!')
        return
    }
    if definition.Has('id') {
        gradientId := definition['id']
    }

    colorPositions := ReadColorPositions()
    if (colorPositions = false) {
        MsgBox('Run the color capture before using gradients.', 'Text Gradients', 'OK Icon!')
        return
    }

    if !colorPositions.Has('fill') || !colorPositions.Has('confirm') {
        MsgBox('Color capture is incomplete. Re-run the color capture wizard.', 'Text Gradients', 'OK Icon!')
        return
    }

    fill := colorPositions['fill']
    confirm := colorPositions['confirm']
    if (fill['x'] = '' || fill['y'] = '' || confirm['x'] = '' || confirm['y'] = '') {
        MsgBox('Color capture is incomplete. Re-run the color capture wizard.', 'Text Gradients', 'OK Icon!')
        return
    }

    if !PremiereActivateFillSlot(fill) {
        return
    }

    gradient := ReadGradientPositions(gradientId)
    if !IsObject(gradient) {
        MsgBox('Configure the Text Gradients tab before using this hotkey.', 'Text Gradients', 'OK Icon!')
        return
    }

    required := [
        Map('key', 'dropdown', 'label', 'gradient dropdown'),
        Map('key', 'linear', 'label', 'linear gradient option'),
        Map('key', 'stop1', 'label', 'first color stop'),
        Map('key', 'stop2', 'label', 'second color stop'),
        Map('key', 'hex', 'label', 'hex input'),
        Map('key', 'midpoint', 'label', 'midpoint handle'),
        Map('key', 'midpointtarget', 'label', 'midpoint target')
    ]

    for item in required {
        key := item['key']
        if !gradient.Has(key) {
            MsgBox('Set the ' . item['label'] . ' coordinates in the Text Gradients tab.', 'Text Gradients', 'OK Icon!')
            return
        }
        point := gradient[key]
        if (point['x'] = '' || point['y'] = '') {
            MsgBox('Set the ' . item['label'] . ' coordinates in the Text Gradients tab.', 'Text Gradients', 'OK Icon!')
            return
        }
    }

    dropdown := gradient['dropdown']
    linear := gradient['linear']
    stop1 := gradient['stop1']
    stop2 := gradient['stop2']
    hexField := gradient['hex']
    midpoint := gradient['midpoint']
    midpointTarget := gradient['midpointtarget']

    stopColors := definition.Has('stops') ? definition['stops'] : Map()
    stop1Hex := 'FF0000'
    stop2Hex := 'FFFFFF'
    if IsObject(stopColors) {
        if stopColors.Has('Stop1') {
            normalized := NormalizePremiereHex(stopColors['Stop1'])
            if (normalized != '') {
                stop1Hex := normalized
            }
        }
        if stopColors.Has('Stop2') {
            normalized := NormalizePremiereHex(stopColors['Stop2'])
            if (normalized != '') {
                stop2Hex := normalized
            }
        }
    }

    ClickAt(dropdown['x'], dropdown['y'])
    Sleep(90)
    ClickAt(linear['x'], linear['y'])
    Sleep(120)

    ClickAt(stop1['x'], stop1['y'])
    Sleep(80)
    ClickAt(hexField['x'], hexField['y'])
    PremiereReplaceActiveHex(stop1Hex)
    Sleep(100)

    ClickAt(stop2['x'], stop2['y'])
    Sleep(80)
    ClickAt(hexField['x'], hexField['y'])
    PremiereReplaceActiveHex(stop2Hex)
    Sleep(110)

    PremiereDragBetweenPoints(midpoint, midpointTarget)
    Sleep(140)

    ClickAt(confirm['x'], confirm['y'])
}

ReadExcaliburPositions() {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    try {
        winX := IniRead(ini, 'Excalibur', 'WindowX', '')
        winY := IniRead(ini, 'Excalibur', 'WindowY', '')
        extX := IniRead(ini, 'Excalibur', 'ExtensionsX', '')
        extY := IniRead(ini, 'Excalibur', 'ExtensionsY', '')
        excX := IniRead(ini, 'Excalibur', 'ExcaliburX', '')
        excY := IniRead(ini, 'Excalibur', 'ExcaliburY', '')
        closeX := IniRead(ini, 'Excalibur', 'CloseX', '')
        closeY := IniRead(ini, 'Excalibur', 'CloseY', '')
    } catch {
        return false
    }

    if (winX = '' || extX = '' || excX = '' || closeX = '') {
        return false
    }

    return Map(
        'window', Map('x', winX, 'y', winY),
        'extensions', Map('x', extX, 'y', extY),
        'excalibur', Map('x', excX, 'y', excY),
        'close', Map('x', closeX, 'y', closeY)
    )
}

SaveExcaliburPositions(data) {
    ini := gHidePositionsFile
    IniWrite(data['WindowX'], ini, 'Excalibur', 'WindowX')
    IniWrite(data['WindowY'], ini, 'Excalibur', 'WindowY')
    IniWrite(data['ExtensionsX'], ini, 'Excalibur', 'ExtensionsX')
    IniWrite(data['ExtensionsY'], ini, 'Excalibur', 'ExtensionsY')
    IniWrite(data['ExcaliburX'], ini, 'Excalibur', 'ExcaliburX')
    IniWrite(data['ExcaliburY'], ini, 'Excalibur', 'ExcaliburY')
    IniWrite(data['CloseX'], ini, 'Excalibur', 'CloseX')
    IniWrite(data['CloseY'], ini, 'Excalibur', 'CloseY')
}

ReadMotionControlPositions() {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    try {
        motionX := IniRead(ini, 'MotionControls', 'MotionToggleX', '')
        motionY := IniRead(ini, 'MotionControls', 'MotionToggleY', '')
        anchorXX := IniRead(ini, 'MotionControls', 'AnchorXX', '')
        anchorXY := IniRead(ini, 'MotionControls', 'AnchorXY', '')
        anchorYX := IniRead(ini, 'MotionControls', 'AnchorYX', '')
        anchorYY := IniRead(ini, 'MotionControls', 'AnchorYY', '')
        posXX := IniRead(ini, 'MotionControls', 'PositionXX', '')
        posXY := IniRead(ini, 'MotionControls', 'PositionXY', '')
        posYX := IniRead(ini, 'MotionControls', 'PositionYX', '')
        posYY := IniRead(ini, 'MotionControls', 'PositionYY', '')
        scaleX := IniRead(ini, 'MotionControls', 'ScaleX', '')
        scaleY := IniRead(ini, 'MotionControls', 'ScaleY', '')
        rotX := IniRead(ini, 'MotionControls', 'RotationX', '')
        rotY := IniRead(ini, 'MotionControls', 'RotationY', '')
    } catch {
        return false
    }

    if ((anchorXX = '' || anchorXY = '' || anchorYX = '' || anchorYY = '')) {
        ; Attempt migration from legacy anchor keys
        try {
            legacyAnchorX := IniRead(ini, 'MotionControls', 'AnchorX', '')
            legacyAnchorY := IniRead(ini, 'MotionControls', 'AnchorY', '')
        } catch {
            legacyAnchorX := ''
            legacyAnchorY := ''
        }
        if (legacyAnchorX != '' && legacyAnchorY != '') {
            anchorXX := legacyAnchorX
            anchorXY := legacyAnchorY
            anchorYX := legacyAnchorX
            anchorYY := legacyAnchorY
        }
    }

    if (motionX = '' || motionY = '' || anchorXX = '' || anchorXY = '' || anchorYX = '' || anchorYY = '' || posXX = '' || posXY = '') {
        return false
    }

    motion := Map()
    motion['motiontoggle'] := Map('x', motionX, 'y', motionY)
    motion['anchorx'] := Map('x', anchorXX, 'y', anchorXY)
    motion['anchory'] := Map('x', anchorYX, 'y', anchorYY)
    motion['positionx'] := Map('x', posXX, 'y', posXY)
    motion['positiony'] := Map('x', posYX, 'y', posYY)
    motion['scale'] := Map('x', scaleX, 'y', scaleY)
    motion['rotation'] := Map('x', rotX, 'y', rotY)
    return motion
}

SaveMotionPositions(data) {
    ini := gHidePositionsFile
    IniWrite(data['MotionToggleX'], ini, 'MotionControls', 'MotionToggleX')
    IniWrite(data['MotionToggleY'], ini, 'MotionControls', 'MotionToggleY')
    IniWrite(data['PositionXX'], ini, 'MotionControls', 'PositionXX')
    IniWrite(data['PositionXY'], ini, 'MotionControls', 'PositionXY')
    IniWrite(data['PositionYX'], ini, 'MotionControls', 'PositionYX')
    IniWrite(data['PositionYY'], ini, 'MotionControls', 'PositionYY')
    IniWrite(data['ScaleX'], ini, 'MotionControls', 'ScaleX')
    IniWrite(data['ScaleY'], ini, 'MotionControls', 'ScaleY')
    IniWrite(data['RotationX'], ini, 'MotionControls', 'RotationX')
    IniWrite(data['RotationY'], ini, 'MotionControls', 'RotationY')
    IniWrite(data['AnchorXX'], ini, 'MotionControls', 'AnchorXX')
    IniWrite(data['AnchorXY'], ini, 'MotionControls', 'AnchorXY')
    IniWrite(data['AnchorYX'], ini, 'MotionControls', 'AnchorYX')
    IniWrite(data['AnchorYY'], ini, 'MotionControls', 'AnchorYY')
    IniDelete(ini, 'MotionControls', 'AnchorX')
    IniDelete(ini, 'MotionControls', 'AnchorY')
    IniDelete(ini, 'MotionControls', 'MotionToggleColor')
}

ReadPinPositions() {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    try {
        hamX := IniRead(ini, 'PinToClip', 'HamburgerX', '')
        hamY := IniRead(ini, 'PinToClip', 'HamburgerY', '')
        pinX := IniRead(ini, 'PinToClip', 'PinX', '')
        pinY := IniRead(ini, 'PinToClip', 'PinY', '')
    } catch {
        return false
    }

    if (hamX = '' || pinX = '') {
        return false
    }

    return Map(
        'hamburger', Map('x', hamX, 'y', hamY),
        'pin', Map('x', pinX, 'y', pinY)
    )
}

SavePinPositions(data) {
    ini := gHidePositionsFile
    IniWrite(data['HamburgerX'], ini, 'PinToClip', 'HamburgerX')
    IniWrite(data['HamburgerY'], ini, 'PinToClip', 'HamburgerY')
    IniWrite(data['PinX'], ini, 'PinToClip', 'PinX')
    IniWrite(data['PinY'], ini, 'PinToClip', 'PinY')
}

PremiereToggleMotion(*) {
    if !EnsurePremiereActive() {
        return
    }

    positions := ReadMotionControlPositions()
    if (positions = false) {
        MsgBox('Capture motion control coordinates before toggling motion.', 'Motion', 'OK Icon!')
        return
    }

    if !positions.Has('motiontoggle') {
        MsgBox('Motion toggle coordinates are not configured.', 'Motion', 'OK Icon!')
        return
    }
    toggle := positions['motiontoggle']
    if (toggle['x'] = '' || toggle['y'] = '') {
        MsgBox('Motion toggle coordinates are not configured.', 'Motion', 'OK Icon!')
        return
    }

    FocusPremierePanel('effect controls')
    Sleep(120)

    MouseGetPos(&origX, &origY)
    MouseMove(toggle['x'], toggle['y'], 0)
    Sleep(40)
    Click()
    Sleep(120)
    MouseMove(origX, origY, 0)
}

PremiereAdjustMotionControl(controlKey) {
    if !EnsurePremiereActive() {
        return
    }

    global gPremiereMotionDragActive
    if gPremiereMotionDragActive {
        return
    }

    positions := ReadMotionControlPositions()
    if (positions = false) {
        MsgBox('Capture motion control coordinates in the capture panel before using this hotkey.', 'Motion', 'OK Icon!')
        return
    }

    lower := StrLower(controlKey)
    if !positions.Has(lower) {
        MsgBox(StrTitle(controlKey) . ' coordinates are not configured.', 'Motion', 'OK Icon!')
        return
    }

    target := positions[lower]
    if (target['x'] = '' || target['y'] = '') {
        MsgBox(StrTitle(controlKey) . ' coordinates are not configured.', 'Motion', 'OK Icon!')
        return
    }

    FocusPremierePanel('effect controls')
    Sleep(120)

    gPremiereMotionDragActive := true
    try {
        MouseMove(target['x'], target['y'], 0)
        Sleep(40)
        if (lower = 'motiontoggle') {
            Click('Down')
            try {
                WaitForHotkeyRelease(A_ThisHotkey)
            } finally {
                Click('Up')
            }
        } else {
            WaitForHotkeyRelease(A_ThisHotkey)
        }
    } finally {
        gPremiereMotionDragActive := false
    }
}

PremiereClickTextEffect(*) {
    if !EnsurePremiereActive() {
        return
    }

    position := ReadTextEffectPosition()
    if (position = false) {
        MsgBox('Capture the text effect coordinate in the capture panel before using this hotkey.', 'Text Effect', 'OK Icon!')
        return
    }

    if !position.Has('texteffect') {
        MsgBox('Text effect coordinate is not configured.', 'Text Effect', 'OK Icon!')
        return
    }

    coords := position['texteffect']
    if (coords['x'] = '' || coords['y'] = '') {
        MsgBox('Text effect coordinate is not configured.', 'Text Effect', 'OK Icon!')
        return
    }

    FocusPremierePanel('effect controls')
    Sleep(120)

    MouseGetPos(&origX, &origY)
    ClickAt(coords['x'], coords['y'])
    Sleep(80)
    if (origX != '' && origY != '') {
        MouseMove(origX, origY, 0)
    }
}

PinToClip(*) {
    if !EnsurePremiereActive() {
        return
    }

    positions := ReadPinPositions()
    if (positions = false) {
        MsgBox('Capture Pin to Clip coordinates before using this hotkey.', 'Pin to Clip', 'OK Icon!')
        return
    }

    if !positions.Has('hamburger') || !positions.Has('pin') {
        MsgBox('Pin to Clip coordinates are incomplete.', 'Pin to Clip', 'OK Icon!')
        return
    }

    ham := positions['hamburger']
    pin := positions['pin']
    if (ham['x'] = '' || ham['y'] = '' || pin['x'] = '' || pin['y'] = '') {
        MsgBox('Pin to Clip coordinates are incomplete.', 'Pin to Clip', 'OK Icon!')
        return
    }

    FocusPremierePanel('effect controls')
    Sleep(120)

    MouseGetPos(&origX, &origY)
    MouseMove(ham['x'], ham['y'], 0)
    Sleep(40)
    Click()
    Sleep(150)
    MouseMove(pin['x'], pin['y'], 0)
    Sleep(40)
    Click()
    Sleep(120)
    MouseMove(origX, origY, 0)
}

HideTrayTip(*) {
    TrayTip()
}

WaitForHotkeyRelease(hotkey) {
    key := NormalizeHotkeyKey(hotkey)
    if (key = '') {
        Sleep(40)
        return
    }
    KeyWait(key, 'U')
}

NormalizeHotkeyKey(hotkey) {
    for mod in ['~', '*', '$', ' '] {
        hotkey := StrReplace(hotkey, mod)
    }
    for mod in ['^', '!', '+', '#'] {
        hotkey := StrReplace(hotkey, mod)
    }
    return hotkey
}

ReopenExcalibur(*) {
    if !EnsurePremiereActive() {
        return
    }

    positions := ReadExcaliburPositions()
    if (positions = false) {
        MsgBox('Capture Excalibur positions first via the capture panel.', 'Excalibur', 'OK Icon!')
        return
    }

    ClickAt(positions['window']['x'], positions['window']['y'])
    Sleep(200)
    ClickAt(positions['extensions']['x'], positions['extensions']['y'])
    Sleep(500)
    ClickAt(positions['excalibur']['x'], positions['excalibur']['y'])
    Sleep(700)
    ClickAt(positions['close']['x'], positions['close']['y'])
}

OffsetPremierePositions(target, axis, amount) {
    switch target {
        case 'color':
            return OffsetColorPositions(axis, amount)
        case 'hide':
            return OffsetHidePositions(axis, amount)
        case 'excalibur':
            return OffsetExcaliburPositions(axis, amount)
        case 'motion':
            return OffsetMotionPositions(axis, amount)
        case 'pin':
            return OffsetPinPositions(axis, amount)
        default:
            return false
    }
}

OffsetColorPositions(axis, amount) {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    applied := false
    keys := GetPremiereColorKeyList()
    colorKeysX := []
    colorKeysY := []
    for key in keys {
        colorKeysX.Push(key . 'X')
        colorKeysY.Push(key . 'Y')
    }

    if (axis = 'x' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'ColorSlots', colorKeysX, amount) || applied
    }
    if (axis = 'y' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'ColorSlots', colorKeysY, amount) || applied
    }
    return applied
}

OffsetHidePositions(axis, amount) {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    applied := false
    if (axis = 'x' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'Positions', ['FillX', 'StrokeX', 'ShadowX'], amount) || applied
    }
    if (axis = 'y' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'Positions', ['FillY', 'StrokeY', 'ShadowY'], amount) || applied
    }
    return applied
}

OffsetPinPositions(axis, amount) {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    applied := false
    if (axis = 'x' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'PinToClip', ['HamburgerX', 'PinX'], amount) || applied
    }
    if (axis = 'y' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'PinToClip', ['HamburgerY', 'PinY'], amount) || applied
    }
    return applied
}

OffsetExcaliburPositions(axis, amount) {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    applied := false
    if (axis = 'x' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'Excalibur', ['WindowX', 'ExtensionsX', 'ExcaliburX', 'CloseX'], amount) || applied
    }
    if (axis = 'y' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'Excalibur', ['WindowY', 'ExtensionsY', 'ExcaliburY', 'CloseY'], amount) || applied
    }
    return applied
}
OffsetMotionPositions(axis, amount) {
    ini := gHidePositionsFile
    if !FileExist(ini) {
        return false
    }

    applied := false
    motionKeysX := ['MotionToggleX', 'PositionXX', 'PositionYX', 'ScaleX', 'RotationX', 'AnchorXX', 'AnchorYX']
    motionKeysY := ['MotionToggleY', 'PositionXY', 'PositionYY', 'ScaleY', 'RotationY', 'AnchorXY', 'AnchorYY']

    if (axis = 'x' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'MotionControls', motionKeysX, amount) || applied
    }
    if (axis = 'y' || axis = 'both') {
        applied := OffsetIniKeys(ini, 'MotionControls', motionKeysY, amount) || applied
    }
    return applied
}

OffsetIniKeys(ini, section, keys, amount) {
    applied := false
    for key in keys {
        value := IniRead(ini, section, key, '')
        if !IsIntegerString(value) {
            continue
        }
        newValue := Integer(value) + amount
        IniWrite(newValue, ini, section, key)
        applied := true
    }
    return applied
}

IsIntegerString(value) {
    return (value != '' && RegExMatch(value, '^[+-]?\d+$'))
}

IsGuiVisible(panel) {
    try {
        return (IsObject(panel) && DllCall('IsWindowVisible', 'ptr', panel.Hwnd, 'int'))
    } catch {
        return false
    }
}

