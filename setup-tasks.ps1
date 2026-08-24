<#
.SYNOPSIS
  以管理员权限重新注册 AutoTheme 计划任务（使用 VBS 包装器隐藏窗口）
.DESCRIPTION
  需要以管理员身份运行。删除旧的 PowerShell 直接调用任务，
  创建使用 wscript.exe + VBS 包装器的新任务，彻底隐藏控制台窗口。
#>

# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "请以管理员身份运行此脚本！" -ForegroundColor Red
    Write-Host "右键点击 PowerShell → 以管理员身份运行" -ForegroundColor Yellow
    pause
    exit 1
}

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host "=== AutoTheme 任务注册工具 ===" -ForegroundColor Cyan
Write-Host "脚本目录: $ScriptDir" -ForegroundColor Gray

# 删除旧任务
Write-Host "`n[1/2] 删除旧任务..." -ForegroundColor Yellow
$oldTasks = @("AutoTheme-Sunrise", "AutoTheme-Sunset", "AutoTheme-DailySetup", "AutoTheme-BootCheck")
foreach ($t in $oldTasks) {
    Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  已删除: $t" -ForegroundColor Gray
}

# 读取配置获取日出日落时间
$ConfigFile = Join-Path $env:USERPROFILE ".auto-theme\config.json"
if (Test-Path $ConfigFile) {
    $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    $sunriseTime = $cfg.sunrise
    $sunsetTime = $cfg.sunset
} else {
    $sunriseTime = "06:30"
    $sunsetTime = "19:30"
}

Write-Host "`n[2/2] 创建新任务（VBS 包装器）..." -ForegroundColor Yellow

# Sunrise 任务
$vbsSunrise = Join-Path $ScriptDir "run-sunrise.vbs"
$a = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsSunrise`""
$t = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Parse("2000-01-01 $sunriseTime"))
Register-ScheduledTask -TaskName "AutoTheme-Sunrise" -Action $a -Trigger $t -Force | Out-Null
Write-Host "  AutoTheme-Sunrise: 每天 $sunriseTime → 浅色模式" -ForegroundColor Green

# Sunset 任务
$vbsSunset = Join-Path $ScriptDir "run-sunset.vbs"
$a = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsSunset`""
$t = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Parse("2000-01-01 $sunsetTime"))
Register-ScheduledTask -TaskName "AutoTheme-Sunset" -Action $a -Trigger $t -Force | Out-Null
Write-Host "  AutoTheme-Sunset: 每天 $sunsetTime → 深色模式" -ForegroundColor Green

# DailySetup 任务（每天 00:05 更新日出日落数据）
$vbsDaily = Join-Path $ScriptDir "run-boot.vbs"
$a = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsDaily`""
$t = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Parse("2000-01-01 00:05"))
Register-ScheduledTask -TaskName "AutoTheme-DailySetup" -Action $a -Trigger $t -Force | Out-Null
Write-Host "  AutoTheme-DailySetup: 每天 00:05 → 更新数据" -ForegroundColor Green

# BootCheck 任务（登录时检查并补切换）
$vbsBoot = Join-Path $ScriptDir "run-boot.vbs"
$a = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsBoot`""
$t = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "AutoTheme-BootCheck" -Action $a -Trigger $t -Force | Out-Null
Write-Host "  AutoTheme-BootCheck: 登录时 → 补切换" -ForegroundColor Green

Write-Host "`n=== 完成！所有任务已更新为 VBS 包装器 ===" -ForegroundColor Cyan
Write-Host "窗口切换时将不再弹出黑框。" -ForegroundColor Green
pause
