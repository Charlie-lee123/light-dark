# 注册计划任务
try {
    Get-ScheduledTask -TaskName 'AutoTheme-*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

    $scriptPath = 'C:\Users\Lenovo\miclaw\project\light-dark\auto-theme.ps1'

    # 日出任务 - 06:33
    $srTime = [DateTime]::Parse('2000-01-01 06:33')
    $a1 = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File '$scriptPath' -Light"
    $t1 = New-ScheduledTaskTrigger -Daily -At $srTime
    Register-ScheduledTask -TaskName 'AutoTheme-Sunrise' -Action $a1 -Trigger $t1 -Force -RunLevel Highest | Out-Null

    # 日落任务 - 19:40
    $ssTime = [DateTime]::Parse('2000-01-01 19:40')
    $a2 = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File '$scriptPath' -Dark"
    $t2 = New-ScheduledTaskTrigger -Daily -At $ssTime
    Register-ScheduledTask -TaskName 'AutoTheme-Sunset' -Action $a2 -Trigger $t2 -Force -RunLevel Highest | Out-Null

    Write-Host 'SUCCESS: Tasks registered'
} catch {
    Write-Host 'ERROR:' $_.Exception.Message
}
