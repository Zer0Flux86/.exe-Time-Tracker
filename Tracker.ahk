#SingleInstance Force
#Persistent
SetWorkingDir %A_ScriptDir%
Menu, Tray, Icon, %A_ScriptDir%\source\icon.ico

global processList := {}
global timeLog := {}
global isTracking := true
global appDataFolder := A_AppData . "\dormant1337"
global configFile := appDataFolder . "\tracker_config.ini"
global dataFile := appDataFolder . "\tracker_data.ini"

if !FileExist(appDataFolder)
    FileCreateDir, %appDataFolder%

LoadSavedData()


Gui, Add, GroupBox, x10 y10 w470 h140, Add Program to Track
Gui, Add, Text, x20 y30 w100 h20, Program Name:
Gui, Add, Edit, x20 y50 w200 h20 vProgramName
Gui, Add, Text, x20 y80 w300 h20, (Enter process name, e.g.: notepad.exe, chrome.exe)
Gui, Add, Button, x20 y100 w100 h30 gAddProgram, Add Program
Gui, Add, Button, x130 y100 w100 h30 gRemoveSelected, Remove Selected


Gui, Add, Button, x10 y160 w100 h30 gToggleTracking vTrackButton, Pause Tracking
Gui, Add, Button, x120 y160 w100 h30 gShowReport, Show Report
Gui, Add, Button, x230 y160 w100 h30 gExportData, Export Data
Gui, Add, Button, x340 y160 w100 h30 gResetStats, Reset Stats


Gui, Add, ListView, x10 y200 w470 h200 vProgramList gListViewClick, Program|Status|Time (minutes)
LV_ModifyCol(1, 200)
LV_ModifyCol(2, 100)
LV_ModifyCol(3, 150)


LoadProgramsToListView()

Gui, Show, w490 h410, Process Time Tracker

SetTimer, TrackProcesses, 1000
SetTimer, AutoSave, 300000
return

LoadSavedData() {
    if FileExist(configFile) {
        Loop, Read, %configFile%
        {
            if (A_LoopReadLine) {
                processList[A_LoopReadLine] := {startTime: 0, isRunning: false, totalTime: 0}
            }
        }
    }
    
    if FileExist(dataFile) {
        Loop, Read, %dataFile%
        {
            if (A_LoopReadLine) {
                parts := StrSplit(A_LoopReadLine, "=")
                if (parts.Length() = 2) {
                    timeLog[parts[1]] := parts[2]
                }
            }
        }
    }
}

SaveData() {
    FileDelete, %configFile%
    for processName in processList {
        FileAppend, %processName%`n, %configFile%
    }
    
    FileDelete, %dataFile%
    for processName, time in timeLog {
        FileAppend, %processName%=%time%`n, %dataFile%
    }
}

LoadProgramsToListView() {
    LV_Delete()
    for processName in processList {
        Process, Exist, %processName%
        status := ErrorLevel > 0 ? "Running" : "Not Running"
        minutes := Round(timeLog[processName] / 60, 1)
        LV_Add(, processName, status, minutes)
    }
}

AddProgram:
Gui, Submit, NoHide
if (ProgramName = "") {
    MsgBox, Please enter a program name!
    return
}
if (processList[ProgramName]) {
    MsgBox, This program is already being tracked!
    return
}

processList[ProgramName] := {startTime: 0, isRunning: false, totalTime: 0}
timeLog[ProgramName] := 0
LV_Add(, ProgramName, "Not Running", "0")
GuiControl,, ProgramName, 
SaveData()
return

RemoveSelected:
row := LV_GetNext()
if (row = 0) {
    MsgBox, Please select a program to remove!
    return
}

MsgBox, 4, Confirm Removal, Are you sure you want to remove this program?
IfMsgBox No
    return

LV_GetText(programName, row, 1)
processList.Delete(programName)
timeLog.Delete(programName)
LV_Delete(row)
SaveData()
return

TrackProcesses:
if (!isTracking)
    return

for processName, data in processList {
    Process, Exist, %processName%
    isRunning := ErrorLevel > 0
    
    if (isRunning && !data.isRunning) {
        data.startTime := A_TickCount
        data.isRunning := true
    }
    else if (!isRunning && data.isRunning) {
        elapsed := (A_TickCount - data.startTime) / 1000
        timeLog[processName] += elapsed
        data.isRunning := false
    }
    else if (isRunning && data.isRunning) {
        elapsed := (A_TickCount - data.startTime) / 1000
        timeLog[processName] += elapsed
        data.startTime := A_TickCount
    }
    
    row := 0
    Loop % LV_GetCount() {
        LV_GetText(currentName, A_Index, 1)
        if (currentName = processName) {
            row := A_Index
            break
        }
    }
    
    if (row > 0) {
        status := isRunning ? "Running" : "Not Running"
        minutes := Round(timeLog[processName] / 60, 1)
        LV_Modify(row, , processName, status, minutes)
    }
}
return

AutoSave:
SaveData()
return

ToggleTracking:
isTracking := !isTracking
GuiControl,, TrackButton, % (isTracking ? "Pause Tracking" : "Resume Tracking")
SaveData()
return

ShowReport:
MsgBox, 0, Time Report, % GenerateReport()
return

GenerateReport() {
    report := "Time Report:`n`n"
    for processName, seconds in timeLog {
        minutes := Round(seconds / 60, 1)
        report .= processName . ": " . minutes . " minutes`n"
    }
    return report
}

ExportData:
FileSelectFile, saveFile, S16, , Save Report, CSV Files (*.csv)
if (saveFile = "")
    return
if !InStr(saveFile, ".csv")
    saveFile .= ".csv"

FileDelete, %saveFile%
FileAppend, Program,Status,Time (minutes)`n, %saveFile%
for processName, data in processList {
    Process, Exist, %processName%
    status := ErrorLevel > 0 ? "Running" : "Not Running"
    minutes := Round(timeLog[processName] / 60, 1)
    FileAppend, %processName%,%status%,%minutes%`n, %saveFile%
}
MsgBox, Data exported successfully!
return

ResetStats:
MsgBox, 4, Reset Statistics, Are you sure you want to reset all statistics?
IfMsgBox Yes
{
    for processName in timeLog {
        timeLog[processName] := 0
        Process, Exist, %processName%
        status := ErrorLevel > 0 ? "Running" : "Not Running"
        
        row := 0
        Loop % LV_GetCount() {
            LV_GetText(currentName, A_Index, 1)
            if (currentName = processName) {
                row := A_Index
                break
            }
        }
        
        if (row > 0) {
            LV_Modify(row, , processName, status, "0")
        }
    }
    SaveData()
}
return

ListViewClick:
if (A_GuiEvent = "DoubleClick") {
    LV_GetText(processName, A_EventInfo, 1)
    MsgBox, % "Program: " processName "`nTotal time: " Round(timeLog[processName] / 60, 1) " minutes"
}
return

GuiClose:
SaveData()
ExitApp