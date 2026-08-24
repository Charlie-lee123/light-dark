$scheduler = New-Object -ComObject "Schedule.Service"
$scheduler.Connect()
$folder = $scheduler.GetFolder("\")

$task = $folder.GetTask("AutoTheme-BootCheck")
$xml = $task.Xml

# 修改 XML
$newXml = $xml -replace '<Command>powershell\.exe</Command>', '<Command>wscript.exe</Command>'
$newXml = $newXml -replace '<Arguments>"C:\\Users\\Lenovo\\miclaw\\project\\light-dark\\run-silent\.vbs"</Arguments>', '<Arguments>"C:\Users\Lenovo\miclaw\project\light-dark\run-silent.vbs"</Arguments>'
# 简化参数替换
$newXml = $newXml -replace '(?s)<Arguments>.*?</Arguments>', '<Arguments>"C:\Users\Lenovo\miclaw\project\light-dark\run-silent.vbs"</Arguments>'

# 先删除旧任务
$folder.DeleteTask("AutoTheme-BootCheck", 0)
Write-Host "Deleted old task"

# 用 RegisterTaskDefinition 的重载（指定 flags=6 = TASK_CREATE_OR_UPDATE）
$folder.RegisterTaskDefinition("AutoTheme-BootCheck", $newXml, 6, "Lenovo", $null, 5)
Write-Host "Registered new task"

# 验证
$task2 = $folder.GetTask("AutoTheme-BootCheck")
$action2 = $task2.Definition.Actions.Item(1)
Write-Host "Verify Execute: [$($action2.Execute)]"
Write-Host "Verify Args: [$($action2.Arguments)]"
