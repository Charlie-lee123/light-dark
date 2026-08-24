Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' 获取 VBS 所在目录
strDir = objFSO.GetParentFolderName(WScript.ScriptFullName)

' 读取参数文件（与 VBS 同目录）
strArgFile = objFSO.BuildPath(strDir, "task-args.txt")
If objFSO.FileExists(strArgFile) Then
    Set f = objFSO.OpenTextFile(strArgFile, 1)
    strArgs = Trim(f.ReadAll)
    f.Close
Else
    strArgs = ""
End If

' 构建 PowerShell 命令
strCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File """ & objFSO.BuildPath(strDir, "auto-theme.ps1") & """ " & strArgs

' 静默执行，不弹窗
objShell.Run strCmd, 0, False
