$scheduler = New-Object -ComObject "Schedule.Service"
$scheduler.Connect()
$folder = $scheduler.GetFolder("\")

# 获取任务的 XML
$task = $folder.GetTask("AutoTheme-BootCheck")
$xml = $task.Xml
Write-Host "=== Original XML (first 500 chars) ==="
Write-Host $xml.Substring(0, [Math]::Min(500, $xml.Length))

# 修改 XML: 把 Execute 从 powershell.exe 改为 wscript.exe，参数改为 VBS
$newXml = $xml -replace '<Exec>[^<]*powershell\.exe[^<]*</Exec>', '<Exec>wscript.exe</Exec>'
$newXml = $newXml -replace '<Arguments>[^<]*</Arguments>', '<Arguments>"C:\Users\Lenovo\miclaw\project\light-dark\run-silent.vbs"</Arguments>'

Write-Host ""
Write-Host "=== Modified XML (first 500 chars) ==="
Write-Host $newXml.Substring(0, [Math]::Min(500, $newXml.Length))

# 用修改后的 XML 重新注册
try {
    $folder.RegisterTaskDefinition("AutoTheme-BootCheck", $newXml, 4, "Lenovo", $null, 5)
    Write-Host ""
    Write-Host "SUCCESS: Task updated"
} catch {
    Write-Host ""
    Write-Host "FAILED: $_"
}
