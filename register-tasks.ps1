# 手动注册任务计划（需要管理员权限）
# 用法：以管理员身份运行 PowerShell，然后执行此脚本

Write-Host "开始注册任务计划..."

# 注册 Sunrise 任务
Unregister-ScheduledTask -TaskName 'AutoTheme-Sunrise' -Confirm:$false -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& ''C:\Users\Lenovo\miclaw\project\light-dark\auto-theme.ps1'' -Light"'
$trigger = New-ScheduledTaskTrigger -Daily -At '06:27'
Register-ScheduledTask -TaskName 'AutoTheme-Sunrise' -Action $action -Trigger $trigger -Description 'Auto Theme - Sunrise Switch' -Force
Write-Host "✅ Sunrise 任务已注册: 06:27"

# 注册 Sunset 任务
Unregister-ScheduledTask -TaskName 'AutoTheme-Sunset' -Confirm:$false -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& ''C:\Users\Lenovo\miclaw\project\light-dark\auto-theme.ps1'' -Dark"'
$trigger = New-ScheduledTaskTrigger -Daily -At '19:23'
Register-ScheduledTask -TaskName 'AutoTheme-Sunset' -Action $action -Trigger $trigger -Description 'Auto Theme - Sunset Switch' -Force
Write-Host "✅ Sunset 任务已注册: 19:23"

# 注册 DailySetup 任务
Unregister-ScheduledTask -TaskName 'AutoTheme-DailySetup' -Confirm:$false -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& ''C:\Users\Lenovo\miclaw\project\light-dark\auto-theme.ps1'' -RegisterAll"'
$trigger = New-ScheduledTaskTrigger -Daily -At '00:05'
Register-ScheduledTask -TaskName 'AutoTheme-DailySetup' -Action $action -Trigger $trigger -Description 'Auto Theme - Daily Setup' -Force
Write-Host "✅ DailySetup 任务已注册: 00:05"

Write-Host ""
Write-Host "所有任务已注册完成！"
Write-Host "Sunrise: 06:27"
Write-Host "Sunset: 19:23"
