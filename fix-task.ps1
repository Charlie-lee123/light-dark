$scheduler = New-Object -ComObject "Schedule.Service"
$scheduler.Connect()
$folder = $scheduler.GetFolder("\")
$task = $folder.GetTask("AutoTheme-BootCheck")
$def = $task.Definition
$action = $def.Actions.Item(1)
$action.Execute = "wscript.exe"
$action.Arguments = "`"C:\Users\Lenovo\miclaw\project\light-dark\run-silent.vbs`""
$folder.RegisterTaskDefinition("AutoTheme-BootCheck", $def, 6, "System", $null, 5)
Write-Host "COM update done"
