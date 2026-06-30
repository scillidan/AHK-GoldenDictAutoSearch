#SingleInstance, Force
#Persistent

scriptDir := A_ScriptDir
iniPath := scriptDir . "\GoldenDictAutoSearch.ini"
trayIcon := scriptDir . "\assets\icon.ico"

if (!FileExist(iniPath)) {
    MsgBox, 0x10, Error, Configuration file not found:`n%iniPath%
    ExitApp
}

global BoundWindows, BoundWindowList, BoundCount
global GD_Executable, GD_DoubleClickGroup, GD_ClipboardGroup, toggleKey, iniPath
global LastClickTime, isStartup, shortcutPath, scriptEditor, clipboardHotkeyEnabled
global DoubleClickEnabled, ClipboardEnabled, DC_LastText, CB_LastText, ClipGuardTick

BoundWindows := {}
BoundWindowList := []
BoundCount := 0
LastClickTime := 0
DC_LastText := ""
CB_LastText := ""
ClipGuardTick := 0

IniRead, GD_Executable, %iniPath%, GoldenDict, Executable, goldendict
IniRead, GD_DoubleClickGroup, %iniPath%, GoldenDict, DoubleClickGroup, default
IniRead, GD_ClipboardGroup, %iniPath%, GoldenDict, ClipboardGroup, translate
IniRead, clipboardHotkeyEnabled, %iniPath%, GoldenDict, ClipboardHotkeyEnabled, off
clipboardHotkeyEnabled := (clipboardHotkeyEnabled = "on" || clipboardHotkeyEnabled = "1" || clipboardHotkeyEnabled = "true")
IniRead, DoubleClickEnabled, %iniPath%, Settings, DoubleClickEnabled, on
DoubleClickEnabled := (DoubleClickEnabled = "on" || DoubleClickEnabled = "1" || DoubleClickEnabled = "true")
IniRead, ClipboardEnabled, %iniPath%, Settings, ClipboardEnabled, off
ClipboardEnabled := (ClipboardEnabled = "on" || ClipboardEnabled = "1" || ClipboardEnabled = "true")
IniRead, toggleKey, %iniPath%, Hotkeys, ToggleKey, ^!+g

EnvGet, envEditor, EDITOR
IniRead, scriptEditor, %iniPath%, AutoHotkey, ScriptEditor, __MISSING__
if (scriptEditor = "__MISSING__" || scriptEditor = "")
    scriptEditor := envEditor != "" ? envEditor : "notepad"

startupDir := A_StartMenu . "\Programs\Startup"
shortcutPath := startupDir . "\GoldenDict AutoSearch.lnk"
isStartup := FileExist(shortcutPath)

Hotkey, %toggleKey%, ToggleHandler

Hotkey, ~LButton Up, OnLButtonUp
if (!DoubleClickEnabled)
    Hotkey, ~LButton Up, Off

if (ClipboardEnabled) {
    CB_LastText := Trim(Clipboard)
    SetTimer, ClipMonitorTimer, 500
}

BuildTrayMenu()
SetTimer, UpdateTrayTip, 1000
return

OnLButtonUp:
    global LastClickTime, DC_LastText, ClipGuardTick

    if (!IsCurrentWindowBound())
        return

    now := A_TickCount
    isDoubleClick := (now - LastClickTime < 300)
    LastClickTime := now

    if (!isDoubleClick)
        return

    Sleep, 50

    ClipGuardTick := A_TickCount
    oldClip := ClipboardAll
    Clipboard := ""
    Send, ^c
    ClipWait, 0.5, 0

    if (ErrorLevel) {
        Clipboard := oldClip
        return
    }

    text := Trim(Clipboard)
    Clipboard := oldClip
    oldClip := ""

    if (text = "" || StrLen(text) > 1000)
        return

    DC_LastText := text
    SearchGoldenDict(text, "DoubleClick")
return

ClipMonitorTimer:
    global CB_LastText, ClipGuardTick

    if (A_TickCount - ClipGuardTick < 1500)
        return

    clipText := Trim(Clipboard)

    if (!IsCurrentWindowBound()) {
        if (clipText != "" && StrLen(clipText) <= 1000)
            CB_LastText := clipText
        return
    }

    if (clipText = "" || StrLen(clipText) > 1000)
        return

    if (clipText = CB_LastText)
        return

    CB_LastText := clipText
    SearchGoldenDict(clipText, "Clipboard")
return

ToggleHandler:
    ToggleBind()
return

ToggleBind() {
    global BoundWindows, BoundWindowList, BoundCount

    MouseGetPos, , , winId

    if (!winId) {
        ShowCenterTip("No window under cursor")
        return
    }

    WinGet, winExe, ProcessName, ahk_id %winId%

    if (!winExe) {
        ShowCenterTip("Cannot get window info")
        return
    }

    if (BoundWindows.HasKey(winExe)) {
        UnbindWindow(winExe)
        msg := "Unbound: " . winExe
        ShowCenterTip(msg)
    } else {
        BindWindow(winExe)
        msg := "Bound: " . winExe
        ShowCenterTip(msg)
    }

    BuildTrayMenu()
}

ShowCenterTip(text) {
    WinGetPos, x, y, w, h, A
    if (x = "" || w = "") {
        ToolTip, %text%
        SetTimer, RemoveToolTip, -1500
        return
    }
    centerX := x + w // 2
    centerY := y + h // 2
    ToolTip, %text%, centerX, centerY
    SetTimer, RemoveToolTip, -1500
}

BindWindow(winExe) {
    global BoundWindows, BoundWindowList, BoundCount

    if (!BoundWindows.HasKey(winExe)) {
        BoundWindows[winExe] := true
        BoundWindowList.Push(winExe)
        BoundCount++
    }
}

UnbindWindow(winExe) {
    global BoundWindows, BoundWindowList, BoundCount

    if (BoundWindows.HasKey(winExe)) {
        BoundWindows.Delete(winExe)

        newList := []
        Loop, % BoundWindowList.Length() {
            exe := BoundWindowList[A_Index]
            if (exe != winExe)
                newList.Push(exe)
        }
        BoundWindowList := newList
        BoundCount--
    }
}

IsCurrentWindowBound() {
    global BoundWindows, BoundCount

    if (BoundCount = 0)
        return false

    WinGet, currentExe, ProcessName, A
    return BoundWindows.HasKey(currentExe)
}

SearchGoldenDict(query, mode) {
    global GD_Executable, GD_DoubleClickGroup, GD_ClipboardGroup, clipboardHotkeyEnabled

    group := (mode = "Clipboard") ? GD_ClipboardGroup : GD_DoubleClickGroup
    groupParam := clipboardHotkeyEnabled ? "--popup-group-name" : "--group-name"
    Run, "%GD_Executable%" %groupParam%="%group%" "%query%"
}

ToggleDoubleClick:
    global DoubleClickEnabled, iniPath

    DoubleClickEnabled := !DoubleClickEnabled
    if (DoubleClickEnabled)
        Hotkey, ~LButton Up, On
    else
        Hotkey, ~LButton Up, Off

    IniWrite, % DoubleClickEnabled ? "on" : "off", %iniPath%, Settings, DoubleClickEnabled
    BuildTrayMenu()
return

ToggleClipboard:
    global ClipboardEnabled, iniPath, CB_LastText

    ClipboardEnabled := !ClipboardEnabled
    if (ClipboardEnabled) {
        CB_LastText := Trim(Clipboard)
        SetTimer, ClipMonitorTimer, 500
    } else {
        SetTimer, ClipMonitorTimer, Off
    }

    IniWrite, % ClipboardEnabled ? "on" : "off", %iniPath%, Settings, ClipboardEnabled
    BuildTrayMenu()
return

ToggleClipboardHotkey:
    global clipboardHotkeyEnabled, iniPath
    clipboardHotkeyEnabled := !clipboardHotkeyEnabled
    newVal := clipboardHotkeyEnabled ? "on" : "off"
    IniWrite, %newVal%, %iniPath%, GoldenDict, ClipboardHotkeyEnabled
    BuildTrayMenu()
return

BuildTrayMenu() {
    global BoundCount, BoundWindowList, isStartup, clipboardHotkeyEnabled
    global DoubleClickEnabled, ClipboardEnabled

    Menu, Tray, NoStandard
    Menu, Tray, DeleteAll
    if (DoubleClickEnabled) {
        Menu, Tray, Add, DoubleClick Mode: On, ToggleDoubleClick
    } else {
        Menu, Tray, Add, DoubleClick Mode: Off, ToggleDoubleClick
    }
    if (ClipboardEnabled) {
        Menu, Tray, Add, Clipboard Mode: On, ToggleClipboard
    } else {
        Menu, Tray, Add, Clipboard Mode: Off, ToggleClipboard
    }
    Menu, Tray, Add
    Menu, Tray, Add, Clear All Bound Windows, ClearBindings
    if (clipboardHotkeyEnabled) {
        Menu, Tray, Add, Clipboard Hotkey (Popup Search): On, ToggleClipboardHotkey
    } else {
        Menu, Tray, Add, Clipboard Hotkey (Popup Search): Off, ToggleClipboardHotkey
    }
    if (isStartup) {
        Menu, Tray, Add, Start with Windows, ToggleStartup
        Menu, Tray, Check, Start with Windows
    } else {
        Menu, Tray, Add, Start with Windows, ToggleStartup
    }
    Menu, Tray, Add, Edit Config, EditConfig
    Menu, Tray, Add, Reload, ReloadApp
    Menu, Tray, Add, Exit, AppExit
}

ToggleStartup:
    global isStartup, shortcutPath
    if (isStartup) {
        FileDelete, %shortcutPath%
        isStartup := false
        Menu, Tray, Uncheck, Start with Windows
    } else {
        FileCreateShortcut, %A_ScriptFullPath%, %shortcutPath%, %A_ScriptDir%
        isStartup := true
        Menu, Tray, Check, Start with Windows
    }
return

ClearBindings:
    global BoundWindows, BoundWindowList, BoundCount
    BoundWindows := {}
    BoundWindowList := []
    BoundCount := 0
    ShowCenterTip("All bindings cleared")
    BuildTrayMenu()
return

UpdateTrayTip:
    global BoundCount, toggleKey, BoundWindowList

    tip := "GoldenDict Auto Search"
    tip := tip . "`nToggle Key: " . toggleKey

    if (BoundCount > 0) {
        sortedList := []
        Loop, % BoundWindowList.Length() {
            exe := BoundWindowList[A_Index]
            sortedList.Push(exe)
        }

        Loop, % sortedList.Length() {
            i := A_Index
            Loop, % sortedList.Length() - i {
                if (sortedList[A_Index] > sortedList[A_Index + 1]) {
                    temp := sortedList[A_Index]
                    sortedList[A_Index] := sortedList[A_Index + 1]
                    sortedList[A_Index + 1] := temp
                }
            }
        }

        tip := tip . "`nBind Windows [" . BoundCount . "]"
        Loop, % sortedList.Length() {
            exe := sortedList[A_Index]
            tip := tip . "`n  " . exe
        }
    }

    Menu, Tray, Tip, %tip%
return

RemoveToolTip:
    ToolTip
return

EditConfig:
    global scriptEditor, iniPath
    Run, %scriptEditor% "%iniPath%"
return

ReloadApp:
    TrayTip, GoldenDict AutoSearch, Config reloaded, 2, 1
    SetTimer, DoReload, -500
return

DoReload:
    Reload
return

AppExit:
    ExitApp
return
