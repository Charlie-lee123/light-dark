Set objShell = CreateObject("WScript.Shell")
strScriptDir = objShell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.auto-theme"
strRunHidden = strScriptDir & "\run-hidden.vbs"
strPowerShell = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & strScriptDir & "\auto-theme.ps1"" -NetworkConnected"
objShell.Run """" & strRunHidden & """ """ & strPowerShell & """", 0, False
