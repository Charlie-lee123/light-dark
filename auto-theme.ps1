<#
.SYNOPSIS
  Windows 自动深色/浅色模式切换工具 (V5 - 开机补切换修复版).
.DESCRIPTION
  自动定位 → 获取日出日落 → 注册定时任务 → 到点自动切换。
  开机时自动检查并补切换（解决关机错过日出/日落的问题）。
.PARAMETER Dark    强制切深色
.PARAMETER Light   强制切浅色
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

function Write-Log {
    param([string]$Msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $Msg" | Out-File -FilePath $LogFile -Encoding utf8 -Append
}

function Get-Config {
    if (Test-Path $ConfigFile) {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if (-not ($cfg.PSObject.Properties.Name -contains "lastSwitch")) {
            $cfg | Add-Member -NotePropertyName "lastSwitch" -NotePropertyValue ""
        }
        if (-not ($cfg.PSObject.Properties.Name -contains "lastSwitchDate")) {
            $cfg | Add-Member -NotePropertyName "lastSwitchDate" -NotePropertyValue ""
        }
        return $cfg
    }
    return $null
}

function Save-Config {
    param($Cfg)
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    $Cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Encoding UTF8
}

function Invoke-Locate {
    $cfg = Get-Config
    $today = Get-Date -Format "yyyy-MM-dd"
    if ($cfg -and $cfg.lastLocate -eq $today -and $cfg.latitude -ne 0) {
        Write-Log "Using cached location: $($cfg.city)"
        return $cfg
    }
    if (-not $cfg) {
        $cfg = [PSCustomObject]@{latitude=0;longitude=0;city="";sunrise="";sunset="";darkMode=$true;lastDate="";lastLocate="";lastSwitch="";lastSwitchDate=""}
    }
    Write-Log "Locating via IP..."
    try {
        $ip = (Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec 5)
        $cfg.latitude = [double]$ip.loc.Split(",")[0]
        $cfg.longitude = [double]$ip.loc.Split(",")[1]
        $cfg.city = "$($ip.city), $($ip.country)"
        $cfg.lastLocate = $today
        Write-Log "Located: $($cfg.city)"
    } catch {
        Write-Log "Locate failed: $_"
        if ($cfg.latitude -eq 0) { throw "Cannot locate" }
    }
    return $cfg
}

function Get-SunTimes {
    param($Lat, $Lon)
    $resp = Invoke-RestMethod -Uri "https://api.sunrise-sunset.org/json?lat=$Lat&lng=$Lon&formatted=0" -TimeoutSec 10
    $localOffset = [TimeSpan]::FromHours(8)
    $sunrise = [DateTimeOffset]::Parse($resp.results.sunrise).ToOffset($localOffset).ToString("HH:mm")
    $sunset = [DateTimeOffset]::Parse($resp.results.sunset).ToOffset($localOffset).ToString("HH:mm")
    Write-Log "Sun: sunrise=$sunrise sunset=$sunset"
    return @{ sunrise=$sunrise; sunset=$sunset }
}

function Set-WindowsTheme {
    param([string]$Mode)
    $value = if ($Mode -eq "dark") { 0 } else { 1 }
    Set-ItemProperty -Path $PersonalizePath -Name "AppsUseLightTheme" -Value $value
    Set-ItemProperty -Path $PersonalizePath -Name "SystemUsesLightTheme" -Value $value
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class _SysRefresh {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(int a, int b, IntPtr c, int d);
}
"@
        [_SysRefresh]::SystemParametersInfo(0x002E, 0, [IntPtr]::Zero, 0x03)
    } catch {}
    Write-Log "Switched to [$($Mode.ToUpper())]"
}

function Invoke-BootCheck {
    $cfg = Get-Config
    if (-not $cfg -or -not $cfg.sunrise) {
        Write-Log "BootCheck: No config or sunrise, skipping"
        return
    }

    $now = Get-Date -Format "HH:mm"
    $today = Get-Date -Format "yyyy-MM-dd"

    if ($cfg.lastSwitchDate -eq $today) {
        Write-Log "BootCheck: Already switched today at $($cfg.lastSwitch), skipping"
        return
    }

    if ($now -ge $cfg.sunrise -and $now -lt $cfg.sunset) {
        Write-Log "BootCheck: Missed sunrise ($($cfg.sunrise)), switching to Light"
        Set-WindowsTheme -Mode "light"
        $cfg.lastSwitch = $now
        $cfg.lastSwitchDate = $today
        Save-Config $cfg
    } elseif ($now -ge $cfg.sunset) {
        Write-Log "BootCheck: Missed sunset ($($cfg.sunset)), switching to Dark"
        Set-WindowsTheme -Mode "dark"
        $cfg.lastSwitch = $now
        $cfg.lastSwitchDate = $today
        Save-Config $cfg
    } else {
        Write-Log "BootCheck: Before sunrise ($($cfg.sunrise)), no switch needed"
    }
}

try {
    if ($Dark) {
        Set-WindowsTheme -Mode "dark"
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
        $cfg = Get-Config
        if ($cfg) {
            $cfg.lastSwitch = Get-Date -Format "HH:mm"
            $cfg.lastSwitchDate = Get-Date -Format "yyyy-MM-dd"
            Save-Config $cfg
        }
        exit 0
    }

    Write-Log "====== Auto Theme Start ======"

    $cfg = Invoke-Locate
    $sun = Get-SunTimes -Lat $cfg.latitude -Lon $cfg.longitude
    $cfg.sunrise = $sun.sunrise
    $cfg.sunset = $sun.sunset
    $cfg.lastDate = Get-Date -Format "yyyy-MM-dd"
    Save-Config $cfg

    Invoke-BootCheck

    $now = Get-Date -Format "HH:mm"
    if ($now -ge $sun.sunrise -and $now -lt $sun.sunset) {
        Set-WindowsTheme -Mode "light"
    } else {
        Set-WindowsTheme -Mode "dark"
    }
    $cfg.lastSwitch = $now
    $cfg.lastSwitchDate = Get-Date -Format "yyyy-MM-dd"
    Save-Config $cfg

    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = Join-Path $PSScriptRoot "auto-theme.ps1" }

    try {
        Get-ScheduledTask -TaskName "AutoTheme-*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

        $srTime = [DateTime]::Parse("2000-01-01 $($sun.sunrise)")
        $a1 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"$scriptPath\" -Light"
        $t1 = New-ScheduledTaskTrigger -Daily -At $srTime
        Register-ScheduledTask -TaskName "AutoTheme-Sunrise" -Action $a1 -Trigger $t1 -Force | Out-Null

        $ssTime = [DateTime]::Parse("2000-01-01 $($sun.sunset)")
        $a2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"$scriptPath\" -Dark"
        $t2 = New-ScheduledTaskTrigger -Daily -At $ssTime
        Register-ScheduledTask -TaskName "AutoTheme-Sunset" -Action $a2 -Trigger $t2 -Force | Out-Null

        $a3 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"$scriptPath\""
        $t3 = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Parse("2000-01-01 00:05"))
        Register-ScheduledTask -TaskName "AutoTheme-DailySetup" -Action $a3 -Trigger $t3 -Force | Out-Null

        $a4 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"$scriptPath\""
        $t4 = New-ScheduledTaskTrigger -AtLogOn
        Register-ScheduledTask -TaskName "AutoTheme-BootCheck" -Action $a4 -Trigger $t4 -Force | Out-Null

        Write-Log "Registered all tasks: Sunrise=$($sun.sunrise) Sunset=$($sun.sunset)"
    } catch {
        Write-Log "WARN: Cannot register tasks: $_"
    }

    Write-Log "====== Setup Complete ======"
} catch {
    Write-Log "ERROR: $_"
    exit 1
}
