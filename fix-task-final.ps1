$scheduler = New-Object -ComObject "Schedule.Service"
$scheduler.Connect()
$folder = $scheduler.GetFolder("\")
$task = $folder.GetTask("AutoTheme-BootCheck")
$def = $task.Definition

$action = $def.Actions.Item(1)
Write-Host "Before Execute: [$($action.Execute)]"
Write-Host "Before Args: [$($action.Arguments)]"

$action.Execute = "wscript.exe"
$action.Arguments = "`"C:\Users\Lenovo\miclaw\project\light-dark\run-silent.vbs`""

Write-Host "After Execute: [$($action.Execute)]"
Write-Host "After Args: [$($action.Arguments)]"

$folder.RegisterTaskDefinition("AutoTheme-BootCheck", $def, 4, "Lenovo", $null, 5)
Write-Host "Done - task updated"
