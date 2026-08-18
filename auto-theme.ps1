# Auto Dark/Light Theme Switcher
# Auto-detect location via IP, switch theme based on sunrise/sunset
# Usage:
#   .\auto-theme.ps1              - Daily setup
#   .\auto-theme.ps1 -SetTheme   - Set theme only
#   .\auto-theme.ps1 -Light      - Force light
#   .\auto-theme.ps1 -Dark       - Force dark
#   .\auto-theme.ps1 -Locate     - Show current detected location

param(
    [switch]$SetTheme,
    [switch]$Light,
    [switch]$Dark,
    [switch]$Locate
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ===== Config =====
$ConfigDir  = Join-Path $env:USERPROFILE ".auto-theme"
$ConfigFile = Join-Path $ConfigDir "config.json"
$LogFile    = Join-Path $ConfigDir "auto-theme.log"

$PersonalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$TaskPrefix = "AutoTheme"

# ===== Utility =====

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $line
}

function Ensure-Config {
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    $defaults = @{
        latitude   = 0.0
        longitude  = 0.0
        city       = ""
        darkMode   = $true
        lastDate   = ""
        lastLocate = ""
        sunrise    = ""
        sunset     = ""
    }

    if (Test-Path $ConfigFile) {
        $existing = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $changed = $false
        foreach ($key in $defaults.Keys) {
            if ($null -eq $existing.PSObject.Properties[$key]) {
                $existing | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key]
                $changed = $true
            }
        }
        if ($changed) {
            $existing | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Encoding UTF8
        }
        return $existing
    }

    $cfg = [PSCustomObject]$defaults
    $cfg | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
    return $cfg
}

function Save-Config {
    param($Config)
    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Encoding UTF8
}

# ===== Location =====

function Get-IPLocation {
    # ip-api.com: free, no key, 45 req/min
    try {
        $resp = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=status,lat,lon,city,country" -Method Get -TimeoutSec 8
        if ($resp.status -eq "success") {
            return @{
                latitude  = [double]$resp.lat
                longitude = [double]$resp.lon
                city      = "$($resp.city), $($resp.country)"
            }
        }
    } catch {
        Write-Log "ip-api.com failed, trying backup..."
    }

    # Backup: ipinfo.io
    try {
        $resp = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Method Get -TimeoutSec 8
        if ($resp.loc) {
            $parts = $resp.loc -split ","
            return @{
                latitude  = [double]$parts[0]
                longitude = [double]$parts[1]
                city      = "$($resp.city), $($resp.country)"
            }
        }
    } catch {
        Write-Log "ipinfo.io also failed"
    }

    return $null
}

function Update-Location {
    param($Config)
    $today = Get-Date -Format "yyyy-MM-dd"

    # Only locate once per day (unless forced)
    if ($Config.lastLocate -eq $today -and $Config.latitude -ne 0) {
        Write-Log "Location already updated today: $($Config.city) ($($Config.latitude), $($Config.longitude))"
        return $Config
    }

    Write-Log "Detecting location via IP..."
    $loc = Get-IPLocation
    if ($loc) {
        $Config.latitude   = $loc.latitude
        $Config.longitude  = $loc.longitude
        $Config.city       = $loc.city
        $Config.lastLocate = $today
        Save-Config $Config
        Write-Log "Location: $($loc.city) ($($loc.latitude), $($loc.longitude))"
    } else {
        if ($Config.latitude -eq 0) {
            Write-Log "Cannot detect location and no fallback available"
        } else {
            Write-Log "Using last known location: $($Config.city)"
        }
    }
    return $Config
}

# ===== Theme =====

function Set-WindowsTheme {
    param([string]$Mode)
    $value = if ($Mode -eq "dark") { 0 } else { 1 }
    Set-ItemProperty -Path $PersonalizePath -Name "AppsUseLightTheme"   -Value $value
    Set-ItemProperty -Path $PersonalizePath -Name "SystemUsesLightTheme" -Value $value

    # Force system UI refresh so taskbar/start menu respond immediately
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ThemeRefresh {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, IntPtr lpvParam, int fuWinIni);
    public const int SPI_SETICONSPECIALSPACING = 0x002E;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDCHANGE = 0x02;
    public static void Refresh() {
        SystemParametersInfo(SPI_SETICONSPECIALSPACING, 0, IntPtr.Zero, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
    }
}
"@ -ErrorAction SilentlyContinue
    [ThemeRefresh]::Refresh()

    $label = if ($Mode -eq "dark") { "[Dark]" } else { "[Light]" }
    Write-Log "Switched to $label"
}

function Get-CurrentTheme {
    try {
        $v = Get-ItemProperty -Path $PersonalizePath -Name "AppsUseLightTheme" -ErrorAction Stop
        if ($v.AppsUseLightTheme -eq 0) { return "dark" } else { return "light" }
    } catch {
        return "unknown"
    }
}

# ===== Sunrise/Sunset =====

function Get-SunTimes {
    param([double]$Lat, [double]$Lng)
    $today = Get-Date -Format "yyyy-MM-dd"
    $url = "https://api.sunrise-sunset.org/json?lat=$Lat&lng=$Lng&date=$today&formatted=0"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10
        if ($resp.status -eq "OK") {
            $sunriseUtc = [DateTime]::Parse($resp.results.sunrise).ToUniversalTime()
            $sunsetUtc  = [DateTime]::Parse($resp.results.sunset).ToUniversalTime()
            $tz = [System.TimeZoneInfo]::Local
            $sunriseLocal = [System.TimeZoneInfo]::ConvertTimeFromUtc($sunriseUtc, $tz)
            $sunsetLocal  = [System.TimeZoneInfo]::ConvertTimeFromUtc($sunsetUtc, $tz)
            return @{
                sunrise = $sunriseLocal.ToString("HH:mm")
                sunset  = $sunsetLocal.ToString("HH:mm")
            }
        }
    } catch {
        Write-Log "Sun API failed: $_"
    }
    return $null
}

# ===== Scheduled Tasks =====

function Remove-OldThemeTasks {
    Get-ScheduledTask -TaskName "${TaskPrefix}*" -ErrorAction SilentlyContinue |
        Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
}

function Register-ThemeTask {
    param(
        [string]$TaskName,
        [string]$TimeStr,
        [string]$ThemeMode
    )
    $flag = if ($ThemeMode -eq "light") { "-Light" } else { "-Dark" }
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" $flag"
    $today = Get-Date -Format "yyyy-MM-dd"
    $triggerTime = [DateTime]::Parse("$today $TimeStr")
    if ($triggerTime -lt (Get-Date)) {
        Write-Log "Skip $TaskName ($TimeStr already passed)"
        return
    }
    $trigger = New-ScheduledTaskTrigger -Once -At $triggerTime
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Log "Registered: $TaskName -> $TimeStr $ThemeMode"
}

function Register-DailySetupTask {
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $trigger = New-ScheduledTaskTrigger -Daily -At "00:05"
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries
    Register-ScheduledTask -TaskName "${TaskPrefix}-DailySetup" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Log "Registered daily setup task at 00:05"
}

# ===== Main =====

$config = Ensure-Config

# Quick modes
if ($Light) {
    Set-WindowsTheme "light"
    Write-Host "Switched to Light Mode"
    exit 0
}
if ($Dark) {
    Set-WindowsTheme "dark"
    Write-Host "Switched to Dark Mode"
    exit 0
}

if ($Locate) {
    $config = Update-Location $config
    if ($config.latitude -ne 0) {
        Write-Host ""
        Write-Host "=============================="
        Write-Host "  City:      $($config.city)"
        Write-Host "  Latitude:  $($config.latitude)"
        Write-Host "  Longitude: $($config.longitude)"
        Write-Host "=============================="
    } else {
        Write-Host "Cannot detect location"
    }
    exit 0
}

if ($SetTheme) {
    $config = Update-Location $config
    $times = Get-SunTimes -Lat $config.latitude -Lng $config.longitude
    if ($times) {
        $now = Get-Date -Format "HH:mm"
        $currentTheme = Get-CurrentTheme
        if ($now -lt $times.sunrise -or $now -ge $times.sunset) {
            if ($currentTheme -ne "dark") { Set-WindowsTheme "dark" }
            else { Write-Log "Already in dark mode" }
        } else {
            if ($currentTheme -ne "light") { Set-WindowsTheme "light" }
            else { Write-Log "Already in light mode" }
        }
    } else {
        Write-Log "Cannot fetch sun times, keeping current theme"
    }
    exit 0
}

# ===== Full Daily Setup =====
Write-Log "====== Auto Theme System Started ======"

# Auto-detect location (once per day)
$config = Update-Location $config

if ($config.latitude -eq 0) {
    Write-Log "No location available, cannot proceed"
    exit 1
}

$times = Get-SunTimes -Lat $config.latitude -Lng $config.longitude

if ($times) {
    $config.sunrise = $times.sunrise
    $config.sunset  = $times.sunset
    $config.lastDate = Get-Date -Format "yyyy-MM-dd"
    Save-Config $config
    Write-Log "Location: $($config.city) ($($config.latitude), $($config.longitude))"
    Write-Log "Sunrise: $($times.sunrise)  Sunset: $($times.sunset)"
} else {
    Write-Log "API failed, using cached times"
    $times = @{ sunrise = $config.sunrise; sunset = $config.sunset }
    if (-not $times.sunrise -or -not $times.sunset) {
        Write-Log "No cached times available, exiting"
        exit 1
    }
}

$now = Get-Date -Format "HH:mm"
$currentTheme = Get-CurrentTheme
Write-Log "Current time: $now  Theme: $currentTheme"

if ($now -lt $times.sunrise -or $now -ge $times.sunset) {
    if ($currentTheme -ne "dark") { Set-WindowsTheme "dark" }
    else { Write-Log "Already dark mode" }
} else {
    if ($currentTheme -ne "light") { Set-WindowsTheme "light" }
    else { Write-Log "Already light mode" }
}

Remove-OldThemeTasks
Register-ThemeTask -TaskName "${TaskPrefix}-Sunrise" -TimeStr $times.sunrise -ThemeMode "light"
Register-ThemeTask -TaskName "${TaskPrefix}-Sunset"  -TimeStr $times.sunset  -ThemeMode "dark"
Register-DailySetupTask

Write-Log "====== Setup Complete ======"
Write-Host ""
Write-Host "========================================="
Write-Host "  Location:   $($config.city)"
Write-Host "  Sunrise:    $($times.sunrise) -> Light"
Write-Host "  Sunset:     $($times.sunset)  -> Dark"
Write-Host "  Auto-refresh daily at 00:05"
Write-Host "========================================="
Write-Host ""
Write-Host "Manual: .\auto-theme.ps1 -Dark / -Light / -Locate"