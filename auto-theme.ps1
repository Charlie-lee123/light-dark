<#
.SYNOPSIS
  Switches Windows between dark and light mode (zero flicker).
.DESCRIPTION
  Sets registry values + uses SystemParametersInfo triple-refresh
  to force taskbar/startmenu to update without restarting Explorer.
.PARAMETER Dark
  Switch to dark mode.
.PARAMETER Light
  Switch to light mode.
.EXAMPLE
  .\auto-theme.ps1 -Dark
  .\auto-theme.ps1 -Light
#>
param(
    [switch]$Dark,
    [switch]$Light
)

$PersonalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$LogFile = Join-Path $PSScriptRoot "auto-theme.log"

function Write-Log {
    param([string]$Msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $Msg" | Out-File -FilePath $LogFile -Encoding utf8 -Append
}

# --- Theme switching ---
function Set-WindowsTheme {
    param([string]$Mode)
    $value = if ($Mode -eq "dark") { 0 } else { 1 }

    # Step 1: Set registry values
    Set-ItemProperty -Path $PersonalizePath -Name "AppsUseLightTheme"   -Value $value
    Set-ItemProperty -Path $PersonalizePath -Name "SystemUsesLightTheme" -Value $value
    Write-Log "Registry set: SystemUsesLightTheme=$value"

    # Step 2: SystemParametersInfo triple-refresh
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class SysRefresh {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, IntPtr lParam, int fuWinIni);

    public const int SPI_SETICONSPECIALSPACING = 0x002E;
    public const int SPI_SETNONCLIENTMETRICS  = 0x002A;
    public const int SPI_SETANIMATION          = 0x0049;
    public const int SPIF_UPDATEINIFILE        = 0x01;
    public const int SPIF_SENDCHANGE           = 0x02;

    public static void Refresh() {
        SystemParametersInfo(SPI_SETICONSPECIALSPACING, 0, IntPtr.Zero, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        SystemParametersInfo(SPI_SETNONCLIENTMETRICS,  0, IntPtr.Zero, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
        SystemParametersInfo(SPI_SETANIMATION,          0, IntPtr.Zero, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
    }
}
"@ -ErrorAction SilentlyContinue

    try {
        [SysRefresh]::Refresh()
        Write-Log "SystemParametersInfo triple-refresh sent"
    } catch {
        Write-Log "SystemParametersInfo failed: $_"
    }

    # Step 3: Broadcast WM_SETTINGCHANGE
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WmBroadcast {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern void SendMessageTimeout(
        IntPtr hWnd, uint Msg, IntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, IntPtr lpdwResult);
}
"@ -ErrorAction SilentlyContinue

    try {
        [WmBroadcast]::SendMessageTimeout(
            [IntPtr]0xFFFF, 0x001A, [IntPtr]0,
            "ImmersiveColorSet", 0x0002, 2000, [IntPtr]0)
        Write-Log "WM_SETTINGCHANGE broadcast sent"
    } catch {
        Write-Log "WM_SETTINGCHANGE failed: $_"
    }

    $label = if ($Mode -eq "dark") { "[Dark]" } else { "[Light]" }
    Write-Log "Switched to $label"
}

# --- Entry ---
if ($Dark) {
    Set-WindowsTheme -Mode "dark"
    Write-Host "Switched to Dark Mode"
} elseif ($Light) {
    Set-WindowsTheme -Mode "light"
    Write-Host "Switched to Light Mode"
} else {
    Write-Host "Usage: .\auto-theme.ps1 -Dark  OR  .\auto-theme.ps1 -Light"
}
