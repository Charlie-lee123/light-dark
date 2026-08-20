<#
.SYNOPSIS
  Windows 自动深色/浅色模式切换工具 (V4 - 开机补切换版).
.DESCRIPTION
  自动定位 → 获取日出日落 → 注册定时任务 → 到点自动切换。
  切换使用 SystemParametersInfo + WM_SETTINGCHANGE + Invoke-ThemeRefresh，零闪烁 + 任务栏实时刷新。
  所有计划任务均以隐藏窗口运行，不会弹出 PowerShell 窗口。
  开机时自动检查并补切换（解决关机错过日出/日落的问题）。
.PARAMETER Dark    强制切深色
.PARAMETER Light   强制切浅色
.EXAMPLE
  .\auto-theme.ps1          # 首次运行：定位 + 设置 + 注册任务
  .\auto-theme.ps1 -Dark    # 立刻切深色
  .\auto-theme.ps1 -Light   # 立刻切浅色
#>
param(
    [switch]$Dark,
    [switch]$Light
)

$ErrorActionPreference = "Stop"
$PersonalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$ConfigDir  = Join-Path $env:USERPROFILE ".auto-theme"
$ConfigFile = Join-Path $ConfigDir "config.json"
$LogFile    = Join-Path $ConfigDir "auto-theme.log"

# ===== Helpers =====
function Write-Log {
    param([string]$Msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $Msg"
    $line | Out-File -FilePath $LogFile -Encoding utf8 -Append
}

function Get-Config {
    if (Test-Path $ConfigFile) {
        return Get-Content $ConfigFile -Raw | ConvertFrom-Json
    }
    return $null
}

function Save-Config {
    param($Cfg)
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    $Cfg | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
}

# ===== 定位 =====
function Invoke-Locate {
    $cfg = Get-Config
    $today = Get-Date -Format "yyyy-MM-dd"

    if ($cfg -and $cfg.lastLocate -eq $today -and $cfg.latitude -ne 0) {
        Write-Log "Using cached location: $($cfg.city)"
        return $cfg
    }

    if (-not $cfg) {
        $cfg = [PSCustomObject]@{
            latitude=0; longitude=0; city=""; sunrise=""; sunset=""
            darkMode=$true; lastDate=""; lastLocate=""
        }
    }

    Write-Log "Locating via IP..."
    try {
        $ip = (Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec 5)
        $cfg.latitude  = [double]$ip.loc.Split(",")[0]
        $cfg.longitude = [double]$ip.loc.Split(",")[1]
        $cfg.city      = "$($ip.city), $($ip.country)"
        $cfg.lastLocate = $today
        Write-Log "Located: $($cfg.city) ($($cfg.latitude), $($cfg.longitude))"
    } catch {
        Write-Log "Locate failed: $_"
        if ($cfg.latitude -eq 0) { throw "Cannot locate and no cached coordinates." }
    }
    return $cfg
}

# ===== 日出日落 =====
function Get-SunTimes {
    param($Lat, $Lon)
    $url = "https://api.sunrise-sunset.org/json?lat=$Lat&lng=$Lon&formatted=0"
    $resp = Invoke-RestMethod -Uri $url -TimeoutSec 10
    $r = $resp.results

    # API returns UTC ISO 8601, convert to local (UTC+8)
    $localOffset = [TimeSpan]::FromHours(8)
    $sunrise = [DateTimeOffset]::Parse($r.sunrise).ToOffset($localOffset).ToString("HH:mm")
    $sunset  = [DateTimeOffset]::Parse($r.sunset).ToOffset($localOffset).ToString("HH:mm")

    Write-Log "Sun: sunrise=$sunrise sunset=$sunset"
    return @{ sunrise = $sunrise; sunset = $sunset }
}

# ===== 主题切换（零闪烁 + 任务栏实时刷新）=====
function Set-WindowsTheme {
    param([string]$Mode)
    $value = if ($Mode -eq "dark") { 0 } else { 1 }

    # 1. 注册表
    Set-ItemProperty -Path $PersonalizePath -Name "AppsUseLightTheme"   -Value $value
    Set-ItemProperty -Path $PersonalizePath -Name "SystemUsesLightTheme" -Value $value

    # 2. SystemParametersInfo 刷新
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class _SysRefresh {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(int a, int b, IntPtr c, int d);
    public static void Do() {
        SystemParametersInfo(0x002E, 0, IntPtr.Zero, 0x03);
        SystemParametersInfo(0x002A, 0, IntPtr.Zero, 0x03);
    }
}
"@
    [_SysRefresh]::Do()

    # 3. 任务栏刷新（通过重启 explorer shell component）
    Invoke-ThemeRefresh

    Write-Log "Switched to [$($Mode.ToUpper())]"
}

# ===== 任务栏刷新 =====
function Invoke-ThemeRefresh {
    try {
        # 方法1: 通过 Rundll32 刷新
        Start-Process "rundll32.exe" -ArgumentList "user32.dll,UpdatePerUserSystemParameters" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue

        # 方法2: 通过 powershell 刷新任务栏
        $refreshScript = @'
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class TaskbarRefresh {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
}
"@
# SHCNE_ASSOCCHANGED = 0x08000000, SHCNF_IDLIST = 0
[TaskbarRefresh]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
'@
        Start-Process "powershell" -ArgumentList "-NoProfile -WindowStyle Hidden -Command `"$refreshScript`"" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue

        Write-Log "Invoke-ThemeRefresh: Taskbar refresh triggered"
    } catch {
        Write-Log "Invoke-ThemeRefresh failed: $_"
    }
}

# ===== 开机补切换检查 =====
function Invoke-BootCheck {
    # 检查今天的日出/日落是否已经过了，如果过了就补切换
    $cfg = Get-Config
    if (-not $cfg -or -not $cfg.sunrise -or -not $cfg.sunset) {
        Write-Log "BootCheck: No config found, skipping"
        return
    }

    $today = Get-Date -Format "yyyy-MM-dd"
    if ($cfg.lastDate -ne $today) {
        Write-Log "BootCheck: Date changed (lastDate=$($cfg.lastDate)), will be handled by DailySetup"
        return
    }

    $now = Get-Date -Format "HH:mm"
    $lastSwitch = $cfg.lastSwitch
    $lastDate = $cfg.lastSwitchDate

    # 如果今天已经切换过，跳过
    if ($lastDate -eq $today) {
        Write-Log "BootCheck: Already switched today at $lastSwitch, skipping"
        return
    }

    # 检查是否错过了今天的日出/日落
    if ($now -ge $cfg.sunrise -and $now -ge $cfg.sunset) {
        # 日出和日落都过了，应该切深色
        Write-Log "BootCheck: Missed both sunrise ($($cfg.sunrise)) and sunset ($($cfg.sunset)), switching to Dark"
        Set-WindowsTheme -Mode "dark"
        $cfg.lastSwitch = $now
        $cfg.lastSwitchDate = $today
        Save-Config $cfg
    } elseif ($now -ge $cfg.sunrise -and $now -lt $cfg.sunset) {
        # 日出过了但日落还没到，应该切浅色
        Write-Log "BootCheck: Missed sunrise ($($cfg.sunrise)), switching to Light"
        Set-WindowsTheme -Mode "light"
        $cfg.lastSwitch = $now
        $cfg.lastSwitchDate = $today
        Save-Config $cfg
    } else {
        # 还没到日出，切深色
        Write-Log "BootCheck: Before sunrise ($($cfg.sunrise)), switching to Dark"
        Set-WindowsTheme -Mode "dark"
        $cfg.lastSwitch = $now
        $cfg.lastSwitchDate = $today
        Save-Config $cfg
    }
}

# ===== Main =====
try {
    # 手动切换模式
    if ($Dark) {
        Set-WindowsTheme -Mode "dark"
        # 记录切换时间
        $cfg = Get-Config
        if ($cfg) {
            $cfg.lastSwitch = Get-Date -Format "HH:mm"
            $cfg.lastSwitchDate = Get-Date -Format "yyyy-MM-dd"
            Save-Config $cfg
        }
        exit 0
    }
    if ($Light) {
        Set-WindowsTheme -Mode "light"
        # 记录切换时间
        $cfg = Get-Config
        if ($cfg) {
            $cfg.lastSwitch = Get-Date -Format "HH:mm"
            $cfg.lastSwitchDate = Get-Date -Format "yyyy-MM-dd"
            Save-Config $cfg
        }
        exit 0
    }

    # 正常流程：定位 → 日出日落 → 设置主题 → 注册任务
    Write-Log "====== Auto Theme Start ======"

    $cfg = Invoke-Locate
    $sun = Get-SunTimes -Lat $cfg.latitude -Lon $cfg.longitude
    $cfg.sunrise = $sun.sunrise
    $cfg.sunset  = $sun.sunset
    $cfg.lastDate = Get-Date -Format "yyyy-MM-dd"
    Save-Config $cfg

    # 根据当前时间设置主题
    $now = Get-Date -Format "HH:mm"
    if ($now -ge $sun.sunrise -and $now -lt $sun.sunset) {
        Set-WindowsTheme -Mode "light"
    } else {
        Set-WindowsTheme -Mode "dark"
    }

    # 记录切换时间
    $cfg.lastSwitch = $now
    $cfg.lastSwitchDate = Get-Date -Format "yyyy-MM-dd"
    Save-Config $cfg

    # 注册计划任务
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = Join-Path $PSScriptRoot "auto-theme.ps1" }

    try {
        # 删除旧任务
        Get-ScheduledTask -TaskName "AutoTheme-*" -ErrorAction SilentlyContinue |
            Unregister-ScheduledTask -Confirm:$false

        # 日出切浅色（隐藏窗口）
        $srTime = [DateTime]::Parse("2000-01-01 $($sun.sunrise)")
        $action1 = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Light"
        $trigger1 = New-ScheduledTaskTrigger -Daily -At $srTime
        Register-ScheduledTask -TaskName "AutoTheme-Sunrise" -Action $action1 -Trigger $trigger1 `
            -Description "Auto Theme: switch to Light at sunrise" -Force | Out-Null

        # 日落切深色（隐藏窗口）
        $ssTime = [DateTime]::Parse("2000-01-01 $($sun.sunset)")
        $action2 = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Dark"
        $trigger2 = New-ScheduledTaskTrigger -Daily -At $ssTime
        Register-ScheduledTask -TaskName "AutoTheme-Sunset" -Action $action2 -Trigger $trigger2 `
            -Description "Auto Theme: switch to Dark at sunset" -Force | Out-Null

        # 每日重新定位（隐藏窗口）
        $action3 = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $trigger3 = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Parse("2000-01-01 00:05"))
        Register-ScheduledTask -TaskName "AutoTheme-DailySetup" -Action $action3 -Trigger $trigger3 `
            -Description "Auto Theme: daily re-locate and update schedule" -Force | Out-Null

        # 开机补切换检查（隐藏窗口）
        $action4 = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        # 使用 LOGON 触发器，用户登录时运行
        $trigger4 = New-ScheduledTaskTrigger -AtLogOn
        Register-ScheduledTask -TaskName "AutoTheme-BootCheck" -Action $action4 -Trigger $trigger4 `
            -Description "Auto Theme: check and apply theme on boot" -Force | Out-Null

        Write-Log "Registered: Sunrise=$($sun.sunrise) Sunset=$($sun.sunset) DailySetup=00:05 BootCheck=AtLogOn"
    } catch {
        Write-Log "WARN: Cannot register tasks (need admin): $_"
    }

    Write-Log "====== Setup Complete ======"
} catch {
    Write-Log "ERROR: $_"
    exit 1
}
