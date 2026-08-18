<#
.SYNOPSIS
  Windows 自动深色/浅色模式切换工具。
.DESCRIPTION
  自动定位 → 获取日出日落 → 注册定时任务 → 到点自动切换。
  切换使用 SystemParametersInfo + WM_SETTINGCHANGE，零闪烁。
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
    Write-Host $line
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

    # 如果配置存在且今天已定位过，直接返回
    if ($cfg -and $cfg.lastLocate -eq $today -and $cfg.latitude -ne 0) {
        Write-Log "Using cached location: $($cfg.city)"
        return $cfg
    }

    # 创建新配置或更新现有配置
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

# ===== 主题切换（零闪烁）=====
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
        SystemParametersInfo(0x0049, 0, IntPtr.Zero, 0x03);
    }
}
"@ -ErrorAction SilentlyContinue
    try { [_SysRefresh]::Do() } catch {}

    # 3. WM_SETTINGCHANGE 广播
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class _WmBC {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern void SendMessageTimeout(IntPtr h, uint m, IntPtr w, string l, uint f, uint t, IntPtr r);
}
"@ -ErrorAction SilentlyContinue
    try { [_WmBC]::SendMessageTimeout([IntPtr]0xFFFF, 0x001A, [IntPtr]0, "ImmersiveColorSet", 0x02, 2000, [IntPtr]0) } catch {}

    $label = if ($Mode -eq "dark") { "Dark" } else { "Light" }
    Write-Log "Switched to [$label]"
    Write-Host "Switched to $label Mode"
}

# ===== Main =====
try {
    # 手动切换模式
    if ($Dark) {
        Set-WindowsTheme -Mode "dark"
        exit 0
    }
    if ($Light) {
        Set-WindowsTheme -Mode "light"
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

        # 注册计划任务
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = Join-Path $PSScriptRoot "auto-theme.ps1" }

    Write-Log "DEBUG: sun.sunrise=$($sun.sunrise) sun.sunset=$($sun.sunset)"

    try {
        # 删除旧任务
        Get-ScheduledTask -TaskName "AutoTheme-*" -ErrorAction SilentlyContinue |
            Unregister-ScheduledTask -Confirm:$false

        # 日出切浅色
        $srTime = [DateTime]::Parse("2000-01-01 $($sun.sunrise)")
        $action1 = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Light"
        $trigger1 = New-ScheduledTaskTrigger -Daily -At $srTime
        Register-ScheduledTask -TaskName "AutoTheme-Sunrise" -Action $action1 -Trigger $trigger1 `
            -Description "Auto Theme: switch to Light at sunrise" -Force | Out-Null

        # 日落切深色
        $ssTime = [DateTime]::Parse("2000-01-01 $($sun.sunset)")
        $action2 = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Dark"
        $trigger2 = New-ScheduledTaskTrigger -Daily -At $ssTime
        Register-ScheduledTask -TaskName "AutoTheme-Sunset" -Action $action2 -Trigger $trigger2 `
            -Description "Auto Theme: switch to Dark at sunset" -Force | Out-Null

        # 每日重新定位
        $action3 = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $trigger3 = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Parse("2000-01-01 00:05"))
        Register-ScheduledTask -TaskName "AutoTheme-DailySetup" -Action $action3 -Trigger $trigger3 `
            -Description "Auto Theme: daily re-locate and update schedule" -Force | Out-Null

        Write-Log "Registered: Sunrise=$($sun.sunrise) Sunset=$($sun.sunset) DailySetup=00:05"
    } catch {
        Write-Log "WARN: Cannot register tasks (need admin): $_"
        Write-Host "Note: Schedule registration needs admin. Run as Admin to enable auto-switch."
    }

    Write-Log "====== Setup Complete ======"
} catch {
    Write-Log "ERROR: $_"
    Write-Host "Error: $_"
    exit 1
}
