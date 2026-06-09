#NoEnv
#SingleInstance, Force
#Persistent
SendMode Input
SetWorkingDir %A_ScriptDir%

global BoundWindows, BoundWindowList, BoundCount
global GD_Executable, GD_DefaultGroupName, ToggleKey, IniPath
global LastClickTime, StartWithWindows, shortcutPath, scriptEditor, clipboardHotkeyEnabled

BoundWindows := {}
BoundWindowList := []
BoundCount := 0
LastClickTime := 0
IniPath := A_ScriptDir . "\GoldenDictAutoSearch.ini"

IniRead, GD_Executable, %IniPath%, GoldenDict, Executable, goldendict
IniRead, GD_DefaultGroupName, %IniPath%, GoldenDict, DefaultGroupName, default
IniRead, clipboardHotkeyEnabled, %IniPath%, GoldenDict, ClipboardHotkeyEnabled, off
clipboardHotkeyEnabled := (clipboardHotkeyEnabled = "on" || clipboardHotkeyEnabled = "1" || clipboardHotkeyEnabled = "true")
IniRead, ToggleKey, %IniPath%, Hotkeys, ToggleKey, ^!+g

EnvGet, envEditor, EDITOR
IniRead, scriptEditor, %IniPath%, AutoHotkey, ScriptEditor, __MISSING__
if (scriptEditor = "__MISSING__" || scriptEditor = "")
    scriptEditor := envEditor != "" ? envEditor : "notepad"

startupDir := A_StartMenu . "\Programs\Startup"
shortcutPath := startupDir . "\GoldenDict AutoSearch.lnk"
StartWithWindows := FileExist(shortcutPath)

Hotkey, %ToggleKey%, ToggleHandler
Hotkey, ~LButton Up, OnLButtonUp

BuildTrayMenu()
SetTimer, UpdateTrayTip, 1000
return

OnLButtonUp:
    global LastClickTime

    if (!IsCurrentWindowBound())
        return

    now := A_TickCount
    isDoubleClick := (now - LastClickTime < 300)
    LastClickTime := now

    if (!isDoubleClick)
        return

    Sleep, 50

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

    SearchGoldenDict(text)
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

SearchGoldenDict(query) {
    global GD_Executable, GD_DefaultGroupName, clipboardHotkeyEnabled

    groupParam := clipboardHotkeyEnabled ? "--popup-group-name" : "--group-name"
    Run, "%GD_Executable%" %groupParam%="%GD_DefaultGroupName%" "%query%"
}

ToggleClipboardHotkey:
    global clipboardHotkeyEnabled, IniPath
    clipboardHotkeyEnabled := !clipboardHotkeyEnabled
    newVal := clipboardHotkeyEnabled ? "on" : "off"
    IniWrite, %newVal%, %IniPath%, GoldenDict, ClipboardHotkeyEnabled
    if (clipboardHotkeyEnabled) {
        Menu, Tray, Rename, Clipboard Hotkey (Popup Search): Off, Clipboard Hotkey (Popup Search): On
        Menu, Tray, Check, Clipboard Hotkey (Popup Search): On
    } else {
        Menu, Tray, Rename, Clipboard Hotkey (Popup Search): On, Clipboard Hotkey (Popup Search): Off
        Menu, Tray, Uncheck, Clipboard Hotkey (Popup Search): Off
    }
return

BuildTrayMenu() {
    global BoundCount, BoundWindowList, StartWithWindows, clipboardHotkeyEnabled

    Menu, Tray, NoStandard
    Menu, Tray, DeleteAll

    if (clipboardHotkeyEnabled) {
        Menu, Tray, Add, Clipboard Hotkey (Popup Search): On, ToggleClipboardHotkey
        Menu, Tray, Check, Clipboard Hotkey (Popup Search): On
    } else {
        Menu, Tray, Add, Clipboard Hotkey (Popup Search): Off, ToggleClipboardHotkey
    }
    Menu, Tray, Add, Clear All Bound Windows, ClearBindings

    Menu, Tray, Add
    if (StartWithWindows) {
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
    global StartWithWindows, shortcutPath
    if (StartWithWindows) {
        FileDelete, %shortcutPath%
        StartWithWindows := false
        Menu, Tray, Uncheck, Start with Windows
    } else {
        FileCreateShortcut, %A_ScriptFullPath%, %shortcutPath%, %A_ScriptDir%
        StartWithWindows := true
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
    global BoundCount, ToggleKey, GD_DefaultGroupName, BoundWindowList

    tip := "GoldenDict AutoSearch"
    tip := tip . "`nToggle Key: " . ToggleKey
    tip := tip . "`nGroup: " . GD_DefaultGroupName

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
    global scriptEditor, IniPath
    Run, %scriptEditor% "%IniPath%"
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
