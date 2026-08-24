$scheduler = New-Object -ComObject "Schedule.Service"
$scheduler.Connect()
$folder = $scheduler.GetFolder("\")

# 先尝试禁用任务
$task = $folder.GetTask("AutoTheme-BootCheck")
Write-Host "Current state: $($task.State)"

# 方法1: 用 RunEx 直接禁用
try {
    $task.Enabled = $false
    Write-Host "Set Enabled=false via property"
} catch {
    Write-Host "Enabled property failed: $_"
}

# 验证
$task2 = $folder.GetTask("AutoTheme-BootCheck")
Write-Host "After disable, state: $($task2.State)"
Write-Host "After disable, enabled: $($task2.Enabled)"
