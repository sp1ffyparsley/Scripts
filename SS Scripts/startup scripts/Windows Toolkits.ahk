#Requires AutoHotkey v2.0
TraySetIcon(A_ScriptDir . '\..\assets\icons\tray_keyboard.ico')

; ============================================================================
; KEYBOARD UTILITIES
; ============================================================================

CapsLock & u::ConvertSelectionToUppercase()
CapsLock & 8::WrapSelection("*", "*")
CapsLock & 9::WrapSelection("(", ")")
CapsLock & '::WrapSelection('"', '"')

; Email hotstrings
:*:gustavoluna0957::gustavoluna0957@gmail.com
:*:gustavot0957::gustavot0957@robeson.k12.nc.us
:*:garrythesnail10::garrythesnail10@gmail.com
:*:footlettucebruh::footlettucebruh@gmail.com

ConvertSelectionToUppercase() {
    ProcessSelection((selection) => ToggleUpperLower(selection))
}

WrapSelection(prefix, suffix) {
    ProcessSelection((selection) => WrapTransform(selection, prefix, suffix))
}

ToggleUpperLower(selection) {
    if (selection = "")
        return false
    upper := StrUpper(selection)
    lower := StrLower(selection)
    if (selection = upper && selection != lower)
        return lower
    return upper
}

WrapTransform(selection, prefix, suffix) {
    if (selection = "")
        return false
    return prefix . selection . suffix
}

ProcessSelection(transformFn) {
    clipSaved := ClipboardAll()
    try {
        A_Clipboard := ""
        Send("^c")
        if !ClipWait(0.5) {
            return
        }
        selection := A_Clipboard
        result := transformFn(selection)
        if (result = false) {
            return
        }
        A_Clipboard := result
        Send("^v")
        Sleep(20)
    } finally {
        A_Clipboard := clipSaved
    }
}

; ============================================================================
; CAPSLOCK MODIFIER HOTKEYS
; ============================================================================

SetCapsLockState("AlwaysOff")
CapsLock::Return

; -- Clipboard & Symbols --
#^c::CopyExplorerSelectionPaths()
CapsLock & 2::Send("~")

!1::SendAltMapped("-")
!2::SendAltMapped(".")

SendAltMapped(outputChar) {
    Send("{Blind}{Alt up}")
    SendInput("{Text}" . outputChar)
    if GetKeyState("Alt", "P") {
        Send("{Blind}{Alt down}")
    }
}

; -- Editing & Navigation --
CapsLock & Backspace::CapsForwardDelete()
CapsLock & h::CapsNavigate("Home")
CapsLock & n::CapsNavigate("End")

; -- Mouse & Scrolling --
CapsLock & [::ScrollWindowUnderMouse("down")
CapsLock & ]::ScrollWindowUnderMouse("up")

; -- Window Layout & Control --
CapsLock & q::MinimizeActiveWindow()
CapsLock & r::CenterActiveWindow()

; -- Application Launchers & Browser Controls --
CapsLock & e::CapsHandleExplorer()
CapsLock & p::CapsFocusPremiere()
CapsLock & f::CapsHandleFirefox()
CapsLock & d::CapsFirefoxTabCycle("back")
CapsLock & s::CapsHandleSpotify()
CapsLock & l::CapsHandleListary()
CapsLock & c::CapsHandleCursor()

; -- Virtual Desktop Navigation --
#^Tab::SendEvent("{Blind}{LWin Down}{Ctrl Down}{Tab}{Ctrl Up}{LWin Up}")
#^+Tab::SendEvent("{Blind}{LWin Down}{Ctrl Down}{Shift Down}{Tab}{Shift Up}{Ctrl Up}{LWin Up}")

CopyExplorerSelectionPaths() {
    doc := ExplorerGetActiveDocument()
    paths := []
    if doc {
        try {
            for item in doc.SelectedItems {
                paths.Push(item.Path)
            }
        } catch {
        }
        if (paths.Length = 0) {
            try {
                folderPath := doc.Folder.Self.Path
                if (folderPath != "")
                    paths.Push(folderPath)
            } catch {
            }
        }
    }

    if (paths.Length = 0) {
        Send("^c")
        return
    }

    A_Clipboard := JoinWithDelimiter(paths, "`r`n")
    ClipWait(0.1)
    ShowTransientTooltip("Copied " . paths.Length . " path" . (paths.Length = 1 ? "" : "s"))
}

CreateExplorerFileList(*) {
    doc := ExplorerGetActiveDocument()
    if !IsObject(doc) {
        ShowTransientTooltip("No active Explorer window.")
        return
    }

    folderPath := ""
    try {
        folderPath := doc.Folder.Self.Path
    } catch {
        folderPath := ""
    }

    if (folderPath = "" || !DirExist(folderPath)) {
        ShowTransientTooltip("Explorer location has no filesystem path.")
        return
    }

    outputFile := folderPath . "\SSfiles_name.txt"
    entries := []

    Loop Files, folderPath . "\*", "FR" {
        relative := SubStr(A_LoopFileFullPath, StrLen(folderPath) + 2)
        if (relative = "")
            relative := A_LoopFileName
        entries.Push(relative)
    }

    if (entries.Length = 0) {
        try {
            FileDelete(outputFile)
        } catch {
        }
        FileAppend("", outputFile, "UTF-8")
        ShowTransientTooltip("Folder is empty. Created SSfiles_name.txt")
        return
    }

    joined := JoinWithDelimiter(entries, "`n")
    sorted := Sort(joined, "C")
    if (sorted != "") {
        content := StrReplace(sorted, "`n", "`r`n") . "`r`n"
    } else {
        content := ""
    }

    try FileDelete(outputFile)
    catch {
    }

    try {
        FileAppend(content, outputFile, "UTF-8")
        ShowTransientTooltip("Saved " . entries.Length . " item" . (entries.Length = 1 ? "" : "s") . " to SSfiles_name.txt")
    } catch {
        ShowTransientTooltip("Failed to write SSfiles_name.txt")
    }
}

ExplorerGetActiveDocument() {
    hwndActive := WinActive("A")
    if (hwndActive = 0)
        return 0

    shell := ComObject("Shell.Application")
    for window in shell.Windows {
        try {
            if (window.HWND != hwndActive)
                continue
            if !InStr(StrLower(window.FullName), "explorer.exe")
                continue
            return window.Document
        } catch {
        }
    }
    return 0
}

; ---------------------------------------------------------------------------
; CapsLock Editing & Navigation Helpers
; ---------------------------------------------------------------------------

CapsForwardDelete() {
    Send("{Delete}")
}

CapsNavigate(direction) {
    sendKey := direction = "Home" ? "{Home}" : "{End}"
    if GetKeyState("Shift", "P") {
        Send("+" . sendKey)
    } else {
        Send(sendKey)
    }
}

ScrollWindowUnderMouse(direction) {
    MouseGetPos(, , &winHwnd, &controlHwnd)
    target := controlHwnd ? controlHwnd : winHwnd
    if !target
        return
    if !DllCall("IsWindow", "ptr", target) {
        return
    }
    action := direction = "up" ? 0 : 1
    targetSpec := "ahk_id " . target
    try {
        PostMessage(0x115, action, 0, , targetSpec)
    } catch {
        if (target != winHwnd && DllCall("IsWindow", "ptr", winHwnd)) {
            PostMessage(0x115, action, 0, , "ahk_id " . winHwnd)
        }
    }
}

CenterActiveWindow() {
    hwnd := WinExist("A")
    if !hwnd
        return

    try {
        class := WinGetClass("ahk_id " . hwnd)
        if (class = "Progman" || class = "WorkerW" || class = "Shell_TrayWnd") {
            ShowTransientTooltip("No active window to center.")
            return
        }
    } catch {
        return
    }

    wx := wy := ww := wh := 0
    try {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)
    } catch {
        wx := wy := ww := wh := 0
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    WinRestore("ahk_id " . hwnd)

    workArea := GetWorkAreaForPoint(mx, my)
    if !IsObject(workArea) {
        workArea := GetWorkAreaForWindow(hwnd)
    }
    if !IsObject(workArea) {
        workArea := GetPrimaryWorkArea()
    }
    if !IsObject(workArea)
        return

    sizeConfig := GetWindowResizeConfig(hwnd)
    widthRatio := sizeConfig.widthRatio
    heightRatio := sizeConfig.heightRatio
    forcedRatio := ""
    if GetKeyState("Shift", "P") {
        forcedRatio := 0.65
    } else if GetKeyState("Ctrl", "P") {
        forcedRatio := 0.40
    }
    if (forcedRatio != "") {
        widthRatio := forcedRatio
        heightRatio := forcedRatio
    }

    minWidthRatio := sizeConfig.HasProp("minWidthRatio") ? sizeConfig.minWidthRatio : 0.4
    minHeightRatio := sizeConfig.HasProp("minHeightRatio") ? sizeConfig.minHeightRatio : 0.4
    if (forcedRatio != "") {
        if (forcedRatio < minWidthRatio)
            minWidthRatio := forcedRatio
        if (forcedRatio < minHeightRatio)
            minHeightRatio := forcedRatio
    }

    width := Clamp(Round(workArea.width * widthRatio), Round(workArea.width * minWidthRatio), workArea.width)
    height := Clamp(Round(workArea.height * heightRatio), Round(workArea.height * minHeightRatio), workArea.height)

    x := workArea.left + Floor((workArea.width - width) / 2)
    y := workArea.top + Floor((workArea.height - height) / 2)

    safeMargin := 20
    maxX := workArea.left + workArea.width - width - safeMargin
    maxY := workArea.top + workArea.height - height - safeMargin
    minX := workArea.left + safeMargin
    minY := workArea.top + safeMargin

    x := Clamp(mx - Floor(width / 2), minX, maxX)
    y := Clamp(my - Floor(height / 2), minY, maxY)

    WinMove(x, y, width, height, "ahk_id " . hwnd)
    WinActivate("ahk_id " . hwnd)
}

GetWorkAreaForWindow(hwnd) {
    try {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)
    } catch {
        return 0
    }
    if !(ww && wh)
        return 0
    return GetWorkAreaForPoint(wx + ww / 2, wy + wh / 2)
}

GetWorkAreaForPoint(x, y) {
    monitorCount := MonitorGetCount()
    Loop monitorCount {
        idx := A_Index
        MonitorGet(idx, &left, &top, &right, &bottom)
        if (x >= left && x <= right && y >= top && y <= bottom) {
            MonitorGetWorkArea(idx, &waLeft, &waTop, &waRight, &waBottom)
            return {left: waLeft, top: waTop, width: waRight - waLeft, height: waBottom - waTop}
        }
    }
    return 0
}

GetPrimaryWorkArea() {
    try {
        MonitorGetWorkArea(1, &left, &top, &right, &bottom)
        return {left: left, top: top, width: right - left, height: bottom - top}
    } catch {
        return 0
    }
}

GetWindowResizeConfig(hwnd) {
    try {
        exe := WinGetProcessName("ahk_id " . hwnd)
    } catch {
        exe := ""
    }

    config := Map(
        "Spotify.exe", {widthRatio: 0.05, heightRatio: 0.05, minWidthRatio: 0.05, minHeightRatio: 0.05}
    )

    if (exe != "" && config.Has(exe)) {
        return config[exe]
    }

    return {widthRatio: 0.85, heightRatio: 0.85, minWidthRatio: 0.4, minHeightRatio: 0.4}
}

; ---------------------------------------------------------------------------
; CapsLock Window Control Helpers
; ---------------------------------------------------------------------------

MinimizeActiveWindow() {
    hwnd := WinExist("A")
    if !hwnd
        return
    try {
        class := WinGetClass("ahk_id " . hwnd)
        if (class = "Shell_TrayWnd") {
            return
        }
    } catch {
    }
    WinMinimize("ahk_id " . hwnd)
}

; ---------------------------------------------------------------------------
; CapsLock Application Helpers
; ---------------------------------------------------------------------------

CapsHandleExplorer() {
    if GetKeyState("Shift", "P") {
        global g_LastExplorerTarget
        target := g_LastExplorerTarget ? g_LastExplorerTarget : A_Desktop
        Run(Format('explorer.exe "{1}"', target))
        return
    }
    HandleFileExplorer()
}

CapsFocusPremiere() {
    global WINDOW_CLASSES, APP_PATHS
    queries := []
    if WINDOW_CLASSES.Has("premiere") {
        queries.Push("ahk_class " . WINDOW_CLASSES["premiere"])
    }
    if APP_PATHS.Has("premiere") {
        queries.Push("ahk_exe " . GetAppNameFromPath(APP_PATHS["premiere"]))
    }
    if (queries.Length = 0) {
        ShowTransientTooltip("Premiere path not configured.")
        return
    }
    hwnd := FindWindowHandle(queries)
    if (hwnd) {
        if WinActive("ahk_id " . hwnd) {
            WinMinimize("ahk_id " . hwnd)
        } else {
            WinRestore("ahk_id " . hwnd)
            WinActivate("ahk_id " . hwnd)
        }
    } else {
        ShowTransientTooltip("Premiere not running.")
    }
}

CapsHandleFirefox() {
    if GetKeyState("Ctrl", "P") {
        global APP_PATHS
        if APP_PATHS.Has("firefox") {
            Run('"' . APP_PATHS["firefox"] . '" -private-window')
        } else {
            Run("firefox.exe -private-window")
        }
        return
    }
    CapsFirefoxTabCycle("forward")
}

CapsFirefoxTabCycle(direction := "forward") {
    if !WinExist("ahk_exe firefox.exe") {
        LaunchOrFocus("firefox")
        return
    }
    if !WinActive("ahk_exe firefox.exe") {
        WinActivate("ahk_exe firefox.exe")
        WinRestore("ahk_exe firefox.exe")
        return
    }
    if (direction = "back") {
        Send("^+{Tab}")
    } else {
        Send("^{Tab}")
    }
}

CapsHandleSpotify() {
    LaunchOrFocus("spotify")
}

CapsHandleListary() {
    if GetKeyState("Shift", "P") {
        QuickLockWorkstation()
        return
    }
    LaunchOrFocus("listary")
}

CapsHandleCursor() {
    LaunchOrFocus("cursor")
}

QuickLockWorkstation() {
    DllCall("LockWorkStation")
}

ResolveWorkspacePath(relativePath) {
    base := A_ScriptDir . "\.."
    cleaned := StrReplace(relativePath, "/", "\")
    if RegExMatch(cleaned, "^[A-Za-z]:\\") || SubStr(cleaned, 1, 2) = "\\"
        return cleaned
    target := base . "\" . cleaned
    try {
        fso := ComObject("Scripting.FileSystemObject")
        return fso.GetAbsolutePathName(target)
    } catch {
        return target
    }
}

GetShortPath(path) {
    if !FileExist(path)
        return path
    bufferSize := 260
    loop 2 {
        buf := Buffer(bufferSize * 2, 0)
        needed := DllCall("GetShortPathNameW", "wstr", path, "ptr", buf, "uint", bufferSize, "uint")
        if (needed = 0) {
            return path
        }
        if (needed > bufferSize) {
            bufferSize := needed + 1
            continue
        }
        return StrGet(buf, needed, "UTF-16")
    }
    return path
}

WriteAutoExportSelection(key) {
    if (key = "")
        return false
    configPath := ResolveWorkspacePath("support\\cache\\autoexport_selection.txt")
    SplitPath(configPath, , &configDir)
    if (configDir != "" && !DirExist(configDir)) {
        try {
            DirCreate(configDir)
        } catch Error as e {
            MsgBox("Unable to create auto export cache folder:`n" . configDir . "`n`n" . e.Message, "Auto Export", "OK Iconx!")
            return false
        }
    }
    try {
        file := FileOpen(configPath, "w", "UTF-8")
        if !IsObject(file) {
            throw Error("Unable to open config file for writing.")
        }
        file.Write(key)
        file.Close()
        return true
    } catch Error as e {
        MsgBox("Failed to record preset selection:`n" . configPath . "`n`n" . e.Message, "Auto Export", "OK Iconx!")
        return false
    }
}

ShowTransientTooltip(message, duration := 1500) {
    ToolTip(message)
    SetTimer(() => ToolTip(), -duration)
}

JoinWithDelimiter(items, delimiter := "`r`n") {
    result := ""
    for index, value in items {
        if (index > 1) {
            result .= delimiter
        }
        result .= value
    }
    return result
}

Clamp(value, minValue, maxValue) {
    if (minValue > maxValue) {
        temp := minValue
        minValue := maxValue
        maxValue := temp
    }
    if (value < minValue)
        return minValue
    if (value > maxValue)
        return maxValue
    return value
}

; ============================================================================
; SYSTEM OSD CONTROL
; ============================================================================

class VolumeOsd {
    __New() {
        this.cachedHandle := 0
        this.searchAttempt := 0
        this.nextSearchTick := 0
    }

    Exists(forceSearch := false) {
        return this.Handle(forceSearch) != 0
    }

    IsHidden(hwnd := 0) {
        hwnd := hwnd ? hwnd : this.Handle(false)
        if !hwnd
            return false

        wp := Buffer(44, 0)
        NumPut("UInt", wp.Size, wp, 0)
        if !DllCall("GetWindowPlacement", "ptr", hwnd, "ptr", wp, "int") {
            return false
        }
        state := NumGet(wp, 8, "UInt")
        return state = 2
    }

    Hide(hwnd := 0) {
        hwnd := hwnd ? hwnd : this.Handle()
        if !hwnd
            return false
        if (this.IsHidden(hwnd))
            return true
        DllCall("ShowWindow", "ptr", hwnd, "int", 6) ; SW_MINIMIZE
        return true
    }

    Show(hwnd := 0) {
        hwnd := hwnd ? hwnd : this.Handle()
        if !hwnd
            return false
        if (!this.IsHidden(hwnd))
            return true
        DllCall("ShowWindow", "ptr", hwnd, "int", 9) ; SW_RESTORE
        DllCall("ShowWindow", "ptr", hwnd, "int", 0) ; SW_HIDE
        return true
    }

    HideIfVisible() {
        hwnd := this.Handle(false)
        if !hwnd {
            hwnd := this.Handle(true)
        }
        if !hwnd
            return
        if !this.IsHidden(hwnd) {
            this.Hide(hwnd)
        }
    }

    ResetCache() {
        this.cachedHandle := 0
        this.searchAttempt := 0
        this.nextSearchTick := 0
    }

    Handle(forceSearch := true) {
        if (this.cachedHandle) {
            if DllCall("IsWindow", "ptr", this.cachedHandle) {
                return this.cachedHandle
            }
            this.ResetCache()
        }

        now := A_TickCount
        if !forceSearch && now < this.nextSearchTick {
            return 0
        }
        if (now < this.nextSearchTick) {
            return 0
        }

        parentHandle := 0
        Loop {
            parentHandle := DllCall("FindWindowEx", "ptr", 0, "ptr", parentHandle, "str", "NativeHWNDHost", "ptr", 0, "ptr")
            if !parentHandle
                break
            childHandle := DllCall("FindWindowEx", "ptr", parentHandle, "ptr", 0, "str", "DirectUIHWND", "ptr", 0, "ptr")
            if !childHandle
                continue
            if (this.cachedHandle && this.cachedHandle != parentHandle) {
                this.ResetCache()
                return 0
            }
            this.cachedHandle := parentHandle
        }

        if (this.cachedHandle) {
            this.searchAttempt := 0
            this.nextSearchTick := now + 1000
            return this.cachedHandle
        }

        if (this.searchAttempt < 10) {
            this.searchAttempt++
            SendInput("{Volume_Up}")
            SendInput("{Volume_Down}")
            waitMs := 1000 * (this.searchAttempt ** 2)
            this.nextSearchTick := now + waitMs
        }

        return 0
    }
}

global g_VolumeOsd := VolumeOsd()
SetTimer(EnsureVolumeOsdHidden, 400)
OnExit(VolumeOsdCleanup)

EnsureVolumeOsdHidden(*) {
    global g_VolumeOsd
    hwnd := WinExist("A")
    if !hwnd {
        g_VolumeOsd.Show()
        return
    }

    try {
        processName := WinGetProcessName("ahk_id " . hwnd)
    } catch {
        processName := ""
    }

    watched := ["Adobe Premiere Pro.exe", "AfterFX.exe", "Photoshop.exe"]
    if watched.Has(processName) {
        g_VolumeOsd.HideIfVisible()
    } else {
        g_VolumeOsd.Show()
    }
}

VolumeOsdCleanup(reason, exitCode) {
    global g_VolumeOsd
    g_VolumeOsd.Show()
}

; ============================================================================
; WINDOW MANAGEMENT HOTKEYS
; ============================================================================

APP_PATHS := Map(
    "premiere", "C:\\Program Files\\Adobe\\Adobe Premiere Pro 2024\\Adobe Premiere Pro.exe",
    "afterfx", "C:\\Program Files\\Adobe\\Adobe After Effects 2024\\Support Files\\AfterFX.exe",
    "blender", "C:\\Program Files\\Blender Foundation\\Blender 4.0\\blender.exe",
    "photoshop", "C:\\Program Files\\Adobe\\Adobe Photoshop 2024\\Photoshop.exe",
    "mediaencoder", "C:\\Program Files\\Adobe\\Adobe Media Encoder 2024\\Adobe Media Encoder.exe",
    "topaz", "C:\\Program Files\\Topaz Labs LLC\\Topaz Video AI\\Topaz Video AI.exe",
    "firefox", "C:\\Program Files\\Mozilla Firefox\\firefox.exe",
    "spotify", A_AppData . "\\Spotify\\Spotify.exe",
    "listary", "C:\\Program Files\\Listary\\Listary.exe",
    "cursor", "C:\\Users\\Tavito\\AppData\\Local\\Programs\\cursor\\Cursor.exe"
)

WINDOW_CLASSES := Map(
    "explorer", "CabinetWClass",
    "premiere", "Premiere Pro",
    "firefox", "MozillaWindowClass"
)

g_WindowHistory := []
g_MaxHistory := 20
g_LastExplorerTarget := A_MyDocuments

; F19 combos reserved (currently unused)
; +F19::ToggleApplication("premiere")
; ^F19::ToggleApplication("afterfx")
; ^+F19::ToggleApplication("blender")
; !F19::ToggleApplication("photoshop")
; !+F19::ToggleApplication("mediaencoder")
; ^!F19::ToggleApplication("topaz")

; Global script maintenance
^!r::RefreshAllAhkScripts()

; Quick close shortcuts
^+F16::ToggleConfiguredApp("premiere")
^+F17::ToggleConfiguredApp("photoshop")
^+F18::ToggleConfiguredApp("afterfx")
^+F20::ToggleConfiguredApp("blender")

; Premiere automation shortcuts (active only when Premiere is focused)
#HotIf WinActive("ahk_exe Adobe Premiere Pro.exe")
#+F14::LaunchSrtCensor()
#+F15::RunPremiereExtendscript("PremiereMarkerCreatorRunner.jsx")
#+F16::LaunchAutoExport()
#HotIf

#HotIf WinActive("ahk_class " . WINDOW_CLASSES["explorer"])
#+F18::CreateExplorerFileList()
#HotIf

HandleFileExplorer() {
    global WINDOW_CLASSES, g_LastExplorerTarget
    if !WinExist("ahk_class " . WINDOW_CLASSES["explorer"]) {
        try {
            Run(Format('explorer.exe "{1}"', g_LastExplorerTarget))
            ToolTip("Explorer: " . g_LastExplorerTarget)
            SetTimer(() => ToolTip(), -2000)
        } catch {
            Run("explorer.exe")
        }
        return
    }

    try {
        GroupAdd("TaranExplorers", "ahk_class " . WINDOW_CLASSES["explorer"])
        if WinActive("ahk_exe explorer.exe") {
            GroupActivate("TaranExplorers", "R")
        } else {
            WinActivate("ahk_class " . WINDOW_CLASSES["explorer"])
        }
        title := WinGetTitle("A")
        folderName := RegExReplace(title, "^(.+)\\([^\\]+)$", "$2")
        if (folderName = "" || folderName = title) {
            folderName := title
        }
        ToolTip("Explorer: " . folderName)
        SetTimer(() => ToolTip(), -2000)
    } catch {
        WinActivate("ahk_class " . WINDOW_CLASSES["explorer"])
    }
}

RestoreLastWindow() {
    hwnd := GetPreviousWindow()
    if (hwnd) {
        WinActivate("ahk_id " . hwnd)
        WinRestore("ahk_id " . hwnd)
        try {
            title := WinGetTitle("ahk_id " . hwnd)
        } catch {
            title := ""
        }
        if (title != "") {
            ToolTip("Prev: " . title)
            SetTimer(() => ToolTip(), -2000)
        }
        return
    }
    ShowTaskSwitcher()
}

ShowTaskSwitcher() {
    Send("!{Tab}")
}

LaunchOrFocus(appKey) {
    global APP_PATHS, WINDOW_CLASSES
    if !APP_PATHS.Has(appKey) {
        MsgBox("Application path not configured for: " . appKey)
        return
    }
    appPath := APP_PATHS[appKey]
    appName := GetAppNameFromPath(appPath)

    queries := []
    if WINDOW_CLASSES.Has(appKey) {
        queries.Push("ahk_class " . WINDOW_CLASSES[appKey])
    }
    queries.Push("ahk_exe " . appName)

    hwnd := FindWindowHandle(queries)
    if (hwnd) {
        ToggleWindow(hwnd)
        return
    }
    try {
        Run(appPath)
    } catch Error as e {
        MsgBox("Error launching " . appKey . ": " . e.Message)
    }
}

RunPremiereExtendscript(relativePath) {
    global APP_PATHS
    if !APP_PATHS.Has("premiere") {
        ShowTransientTooltip("Premiere path not configured.")
        return
    }
    scriptPath := ResolveWorkspacePath(relativePath)
    if !FileExist(scriptPath) {
        ShowTransientTooltip("Script not found:`n" . scriptPath)
        return
    }
    premiereExe := APP_PATHS["premiere"]
    if !FileExist(premiereExe) {
        ShowTransientTooltip("Premiere executable not found.")
        return
    }
    SplitPath(scriptPath, &scriptFile, &scriptDir)
    scriptForPremiere := scriptPath
    try {
        cmd := Format('"{1}" "-r" "{2}"', premiereExe, scriptForPremiere)
        Run(cmd, scriptDir)
        ShowTransientTooltip("Running " . scriptFile . " in Premiere.")
    } catch Error as e {
        MsgBox("Failed to run Premiere script:`n" . scriptPath . "`n`n" . e.Message, "Premiere Script", "OK Iconx!")
    }
}

LaunchSrtCensor() {
    scriptPath := ResolveWorkspacePath("Premiere Marker Cutting scripts\\SRTcensor")
    if !FileExist(scriptPath) {
        ShowTransientTooltip("SRT Censor script not found.")
        return
    }
    SplitPath(scriptPath, &scriptFile, &scriptDir)
    for python in ["pythonw.exe", "python.exe"] {
        try {
            cmd := Format('"{1}" "{2}"', python, scriptPath)
            options := python = "pythonw.exe" ? "" : "Hide"
            Run(cmd, scriptDir, options)
            if WinWait("SRT Censor Tool Pro - Enhanced ahk_class TkTopLevel", , 2) {
                WinActivate("SRT Censor Tool Pro - Enhanced ahk_class TkTopLevel")
            }
            ShowTransientTooltip("Launching " . scriptFile . ".")
            return
        } catch Error {
        }
    }
    MsgBox("Python executable not found on PATH. Install Python or update LaunchSrtCensor.", "SRT Censor", "OK Iconx!")
}

LaunchAutoExport() {
    presetList := [
        Map("key", "prores4444_mxf", "name", "Apple ProRes 4444 (MXF)"),
        Map("key", "match_source_high", "name", "Match Source - High Bitrate"),
        Map("key", "match_source_low", "name", "Match Source - Low Bitrate")
    ]
    if (presetList.Length = 0) {
        return
    }

    gui := Gui("+AlwaysOnTop", "Auto Export Preset")
    gui.SetFont("s10")
    gui.Add("Text", , "Choose Media Encoder preset:")
    names := []
    for item in presetList {
        names.Push(item["name"])
    }
    options := JoinWithDelimiter(names, "|")
    presetDropdown := gui.Add("DropDownList", "vPresetChoice w280 Choose1", options)

    startBtn := gui.Add("Button", "Default w120", "Start Export")
    cancelBtn := gui.Add("Button", "w120", "Cancel")

    RunSelection(*) {
        index := presetDropdown.Value
        if (index < 1 || index > presetList.Length) {
            return
        }
        chosen := presetList[index]
        if !WriteAutoExportSelection(chosen["key"]) {
            return
        }
        gui.Destroy()
        RunPremiereExtendscript("AutoExport_Updated.jsx")
    }

    CancelSelection(*) {
        gui.Destroy()
    }

    startBtn.OnEvent("Click", RunSelection)
    cancelBtn.OnEvent("Click", CancelSelection)
    gui.OnEvent("Close", CancelSelection)
    gui.Show("Auto Center")
    presetDropdown.Focus()
}

ToggleApplication(appKey) {
    ToggleConfiguredApp(appKey, false)
}

ToggleConfiguredApp(appKey, useTray := true) {
    global APP_PATHS

    if !APP_PATHS.Has(appKey) {
        NotifyAppState("No path configured for " . appKey . ".", useTray)
        return
    }

    appPath := APP_PATHS[appKey]
    exeName := GetAppNameFromPath(appPath)

    if ProcessExist(exeName) {
        CloseApplicationByExe(exeName)
        NotifyAppState("Closed " . exeName . ".", useTray)
        return
    }

    if (appPath = "" || !FileExist(appPath)) {
        NotifyAppState("Configured path not found:`n" . appPath, useTray)
        return
    }

    try {
        Run(appPath)
        NotifyAppState("Launching " . exeName . ".", useTray)
    } catch Error as e {
        NotifyAppState("Failed to launch " . exeName . ": " . e.Message, useTray)
    }
}

NotifyAppState(message, useTray) {
    if (useTray) {
        TrayTip("Apps", message, "Mute")
        SetTimer(() => TrayTip(), -2000)
    } else {
        MsgBox(message, "Apps", "OK Icon!")
    }
}

CloseApplicationByExe(exeName) {
    loop 10 {
        pid := ProcessExist(exeName)
        if !pid {
            break
        }
        try {
            WinClose("ahk_exe " . exeName)
            ProcessWaitClose(pid, 1)
        } catch {
        }
        if ProcessExist(exeName) {
            try {
                ProcessClose pid
            } catch {
            }
            Sleep(300)
        }
    }
}

RefreshAllAhkScripts() {
    static WM_COMMAND := 0x111            ; Windows message for menu commands
    static ID_FILE_RELOAD := 65303        ; AutoHotkey tray menu -> Reload

    prevDetectHidden := A_DetectHiddenWindows
    DetectHiddenWindows(true)

    try {
        scriptWindows := WinGetList("ahk_class AutoHotkey")
        if (scriptWindows.Length = 0) {
            TrayTip("AutoHotkey Refresh", "No AutoHotkey scripts found.", "Mute")
            SetTimer(() => TrayTip(), -1500)
            return
        }

        reloaded := 0
        for hwnd in scriptWindows {
            if (hwnd = A_ScriptHwnd) {
                continue
            }
            PostMessage(WM_COMMAND, ID_FILE_RELOAD, 0, , "ahk_id " . hwnd)
            reloaded++
        }

        total := reloaded + 1  ; include this script
        TrayTip("AutoHotkey Refresh", "Reloading " . total . " script(s)...", "Mute")
        SetTimer(() => TrayTip(), -1500)
        SetTimer(() => Reload(), -100)
    } finally {
        DetectHiddenWindows(prevDetectHidden)
    }
}

FindWindowHandle(queries) {
    for query in queries {
        hwnd := WinExist(query)
        if (hwnd) {
            return hwnd
        }
    }
    return 0
}

ToggleWindow(hwnd) {
    if WinActive("ahk_id " . hwnd) {
        WinMinimize("ahk_id " . hwnd)
    } else {
        WinActivate("ahk_id " . hwnd)
        WinRestore("ahk_id " . hwnd)
    }
}

GetAppNameFromPath(fullPath) {
    return RegExReplace(fullPath, ".*\\", "")
}

TrackActiveWindow(*) {
    global g_WindowHistory, g_MaxHistory, g_LastExplorerTarget, WINDOW_CLASSES
    static lastHwnd := 0

    hwnd := WinExist("A")
    if (hwnd = 0 || hwnd = lastHwnd) {
        return
    }

    try {
        title := WinGetTitle("ahk_id " . hwnd)
    } catch {
        title := ""
    }

    try {
        className := WinGetClass("ahk_id " . hwnd)
    } catch {
        className := ""
    }

    if (title = "" || InStr(title, "Program Manager") || InStr(title, "Task Switching")) {
        lastHwnd := hwnd
        return
    }

    for index, item in g_WindowHistory {
        if (item.hwnd = hwnd) {
            g_WindowHistory.RemoveAt(index)
            break
        }
    }

    g_WindowHistory.Push({hwnd: hwnd, title: title, class: className})
    if (g_WindowHistory.Length > g_MaxHistory) {
        g_WindowHistory.RemoveAt(1)
    }

    if (className = WINDOW_CLASSES["explorer"]) {
        g_LastExplorerTarget := title
    }

    lastHwnd := hwnd
}

GetPreviousWindow() {
    global g_WindowHistory
    if (g_WindowHistory.Length < 2) {
        return 0
    }
    index := g_WindowHistory.Length - 1
    while (index > 0) {
        candidate := g_WindowHistory[index]
        if !IsObject(candidate) {
            index--
            continue
        }
        if WinExist("ahk_id " . candidate.hwnd) {
            return candidate.hwnd
        }
        g_WindowHistory.RemoveAt(index)
        index--
    }
    return 0
}

TrayTip("Windows Toolkit Active", "Hotkeys loaded.", "Mute")
SetTimer(() => TrayTip(), -3000)
SetTimer(TrackActiveWindow, 250)
