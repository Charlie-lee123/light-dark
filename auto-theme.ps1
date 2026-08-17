# Windows Auto Dark/Light Theme Switcher
# Based on sunrise/sunset times
# Usage:
#   .\auto-theme.ps1              - Daily setup
#   .\auto-theme.ps1 -SetTheme   - Set theme only
#   .\auto-theme.ps1 -Light      - Force light
#   .\auto-theme.ps1 -Dark       - Force dark

param(
    [switch]$SetTheme,
    [switch]$Light,
    [switch]$Dark
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ===== Config =====
$ConfigDir  = Join-Path $env:USERPROFILE ".auto-theme"
$ConfigFile = Join-Path $ConfigDir "config.json"
$LogFile    = Join-Path $ConfigDir "auto-theme.log"

$DefaultLat = 29.57
$DefaultLng = 106.45

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
    if (Test-Path $ConfigFile) {
        return Get-Content $ConfigFile -Raw | ConvertFrom-Json
    }
    $cfg = @{
        latitude  = $DefaultLat
        longitude = $DefaultLng
        darkMode  = $true
        lastDate  = ""
        sunrise   = ""
        sunset    = ""
    }
    $cfg | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
    return $cfg
}

function Save-Config {
    param($Config)
    $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFile -Encoding UTF8
}

# ===== Theme =====

function Set-WindowsTheme {
    param([string]$Mode)
    $value = if ($Mode -eq "dark") { 0 } else { 1 }
    Set-ItemProperty -Path $PersonalizePath -Name "AppsUseLightTheme"   -Value $value
    Set-ItemProperty -Path $PersonalizePath -Name "SystemUsesLightTheme" -Value $value
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
        Write-Log "API request failed: $_"
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

if ($SetTheme) {
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

# Full startup
Write-Log "====== Auto Theme System Started ======"

$times = Get-SunTimes -Lat $config.latitude -Lng $config.longitude

if ($times) {
    $config.sunrise = $times.sunrise
    $config.sunset  = $times.sunset
    $config.lastDate = Get-Date -Format "yyyy-MM-dd"
    Save-Config $config
    Write-Log "Lat: $($config.latitude), Lng: $($config.longitude)"
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
Write-Host "  Sunrise: $($times.sunrise) -> Light Mode"
Write-Host "  Sunset:  $($times.sunset)  -> Dark Mode"
Write-Host "  Daily refresh at 00:05"
Write-Host "========================================="
Write-Host ""
Write-Host "Manual: .\auto-theme.ps1 -Dark / -Light"
