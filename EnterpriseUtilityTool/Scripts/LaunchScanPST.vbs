' LaunchScanPST.vbs
' This script finds and runs the Outlook Inbox Repair Tool (SCANPST.EXE).

Option Explicit
Dim WshShell, ScanPstPath

Set WshShell = CreateObject("WScript.Shell")

' List common paths for Office installations (Office16 is 365/2019)
ScanPstPath = ""

' Path 1: 64-bit Office
If FSO.FileExists("C:\Program Files\Microsoft Office\root\Office16\SCANPST.EXE") Then
    ScanPstPath = "C:\Program Files\Microsoft Office\root\Office16\SCANPST.EXE"
ElseIf FSO.FileExists("C:\Program Files (x86)\Microsoft Office\root\Office16\SCANPST.EXE") Then
' Path 2: 32-bit Office (on 64-bit Windows)
    ScanPstPath = "C:\Program Files (x86)\Microsoft Office\root\Office16\SCANPST.EXE"
End If

If ScanPstPath <> "" Then
    ' Launch the executable (0 is non-interactive hide window, but SCANPST is interactive)
    WshShell.Run Chr(34) & ScanPstPath & Chr(34), 1, False 
Else
    ' Log an error (This will be caught by the calling PowerShell script or event viewer)
    WshShell.Popup "Outlook Repair Tool (SCANPST.EXE) not found.", 5, "Launch Error", 16 
End If

Set WshShell = Nothing