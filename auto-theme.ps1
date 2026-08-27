<#
.SYNOPSIS
  Windows 自动深色/浅色模式切换工具 (V6 - 网络连接触发版).
.DESCRIPTION
  自动定位 → 获取日出日落 → 注册定时任务 → 到点自动切换。
  开机时自动检查并补切换（解决关机错过日出/日落的问题）。
  网络连接时自动重新获取日出日落时间（解决开机时网络未就绪的问题）。
.PARAMETER Dark              强制切深色
.PARAMETER Light             强制切浅色
.PARAMETER NetworkConnected  网络连接触发，重新获取日出日落并补切换
#>
param(
    [switch]$Dark,
    [switch]$Light,
    [switch]$NetworkConnected
)

$ErrorActionPreference = "Stop"

# 彻底隐藏控制台窗口（解决 -WindowStyle Hidden 不可靠的问题）
try {
    Add-Type -TypeDefinition '
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
' -ErrorAction SilentlyContinue
    $hwnd = [Win32]::GetConsoleWindow()
    if ($hwnd -ne [IntPtr]::Zero) { [Win32]::ShowWindow($hwnd, 0) }
} catch {}

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
    # 每次触发都重新定位（使用高德地理编码获取精确坐标）
    # 不再使用缓存，确保位置信息始终最新
    if (-not $cfg) {
        $cfg = [PSCustomObject]@{latitude=0;longitude=0;city="";sunrise="";sunset="";darkMode=$true;lastDate="";lastLocate="";lastSwitch="";lastSwitchDate=""}
    }
    # 确保所有必要字段存在
    $requiredFields = @("city","lastLocate","lastSwitch","lastSwitchDate","darkMode","lastDate","sunrise","sunset")
    foreach ($field in $requiredFields) {
        if (-not ($cfg.PSObject.Properties.Name -contains $field)) {
            $cfg | Add-Member -NotePropertyName $field -NotePropertyValue "" -Force
        }
    }
                                                Write-Log "Locating..."
    $amapKey = "825c925879372262c060fe4e2b32a188"

    # 优先用 config.json 中的 address 做地理编码（精确到地点）
    $address = ""
    if ($cfg.PSObject.Properties.Name -contains "address") {
        $address = $cfg.address
    }
    if ($address) {
        try {
            $encodedAddr = [System.Uri]::EscapeDataString($address)
            $geoResp = Invoke-RestMethod -Uri "https://restapi.amap.com/v3/geocode/geo?key=$amapKey&address=$encodedAddr" -TimeoutSec 8
            if ($geoResp.status -eq "1" -and $geoResp.geocodes -and $geoResp.geocodes.Count -gt 0) {
                $locParts = $geoResp.geocodes[0].location.Split(",")
                $cfg.longitude = [double]$locParts[0]
                $cfg.latitude = [double]$locParts[1]
                $cfg.city = "$address, CN"
                $cfg.lastLocate = $today
                Save-Config $cfg
                Write-Log "Located via Amap Geocoding: $address ($($cfg.latitude), $($cfg.longitude))"
                return $cfg
            }
        } catch {
            Write-Log "Amap Geocoding failed: $_"
        }
    }

    # fallback: 高德 IP 定位
    try {
        $ipResp = Invoke-RestMethod -Uri "https://restapi.amap.com/v3/ip?key=$amapKey" -TimeoutSec 8
        if ($ipResp.status -eq "1" -and $ipResp.location) {
            $locParts = $ipResp.location.Split(",")
            $cfg.longitude = [double]$locParts[0]
            $cfg.latitude = [double]$locParts[1]
            $city = if ($ipResp.city) { $ipResp.city } else { $ipResp.province }
            $cfg.city = "$city, CN"
            $cfg.lastLocate = $today
            Save-Config $cfg
            Write-Log "Located via Amap IP: $($cfg.city)"
            return $cfg
        }
    } catch {
        Write-Log "Amap IP locate failed: $_"
    }

    # 最后 fallback: 使用上次保存的位置
    if ($cfg.latitude -ne 0 -and $cfg.longitude -ne 0) {
        Write-Log "Using last known location: $($cfg.city) ($($cfg.latitude), $($cfg.longitude))"
        $cfg.lastLocate = $today
        return $cfg
    }
    throw "Cannot locate - no saved coordinates"
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
    # 发送系统刷新消息
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ThemeRefresh {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(int a, int b, IntPtr c, int d);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
        # 刷新系统参数
        [ThemeRefresh]::SystemParametersInfo(0x002E, 0, [IntPtr]::Zero, 0x03)
        # 广播 WM_SETTINGCHANGE
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = [System.UInt32]0x001A
        $result = [UIntPtr]::Zero
                [ThemeRefresh]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "ImmersiveColorSet", 2, 3000, [ref]$result) | Out-Null
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

    # 判断当前应该是什么主题
    $shouldBeDark = $false
    if ($now -ge $cfg.sunset -or $now -lt $cfg.sunrise) {
        $shouldBeDark = $true
    }

    # 检查当前实际主题
    $light = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme').AppsUseLightTheme
    $isCurrentlyLight = ($light -eq 1)

    # 如果主题正确，跳过
    if (($shouldBeDark -and -not $isCurrentlyLight) -or (-not $shouldBeDark -and $isCurrentlyLight)) {
        Write-Log "BootCheck: Theme is correct (should=$(if ($shouldBeDark) {'Dark'} else {'Light'}), actual=$(if ($isCurrentlyLight) {'Light'} else {'Dark'})), skipping"
        return
    }

    # 主题不正确，切换
    if ($shouldBeDark) {
        Write-Log "BootCheck: Incorrect theme, switching to Dark"
        Set-WindowsTheme -Mode "dark"
    } else {
        Write-Log "BootCheck: Incorrect theme, switching to Light"
        Set-WindowsTheme -Mode "light"
    }
    $cfg.lastSwitch = $now
    $cfg.lastSwitchDate = $today
    Save-Config $cfg
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

    # 网络连接触发：重新获取日出日落并补切换（解决开机时网络未就绪）
    if ($NetworkConnected) {
        Write-Log "NetworkConnected trigger: refreshing sun times"
        $cfg = Get-Config
        try {
            $located = Invoke-Locate
            $sun = Get-SunTimes -Lat $located.latitude -Lon $located.longitude
            $cfg.sunrise = $sun.sunrise
            $cfg.sunset = $sun.sunset
            $cfg.lastDate = Get-Date -Format "yyyy-MM-dd"
            Save-Config $cfg
            Write-Log "NetworkConnected: Updated sun times - Sunrise=$($sun.sunrise) Sunset=$($sun.sunset)"
        } catch {
            Write-Log "NetworkConnected: Failed to update sun times, using cached values: Sunrise=$($cfg.sunrise) Sunset=$($cfg.sunset)"
        }
        # 补切换
        Invoke-BootCheck
        exit 0
    }

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
        $vbsSunrise = Join-Path $PSScriptRoot "run-sunrise.vbs"
        $a1 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsSunrise`""
        $t1 = New-ScheduledTaskTrigger -Daily -At $srTime
        Register-ScheduledTask -TaskName "AutoTheme-Sunrise" -Action $a1 -Trigger $t1 -Force | Out-Null

        $ssTime = [DateTime]::Parse("2000-01-01 $($sun.sunset)")
        $vbsSunset = Join-Path $PSScriptRoot "run-sunset.vbs"
        $a2 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsSunset`""
        $t2 = New-ScheduledTaskTrigger -Daily -At $ssTime
        Register-ScheduledTask -TaskName "AutoTheme-Sunset" -Action $a2 -Trigger $t2 -Force | Out-Null

        $vbsDaily = Join-Path $PSScriptRoot "run-boot.vbs"
        $a3 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsDaily`""
        $t3 = New-ScheduledTaskTrigger -Daily -At ([DateTime]::Parse("2000-01-01 00:05"))
        Register-ScheduledTask -TaskName "AutoTheme-DailySetup" -Action $a3 -Trigger $t3 -Force | Out-Null

                        # BootCheck 通过 VBS 包装启动，彻底隐藏窗口
        $vbsPath = Join-Path $PSScriptRoot "run-boot.vbs"
        $a4 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`""
        $t4 = New-ScheduledTaskTrigger -AtLogOn
        Register-ScheduledTask -TaskName "AutoTheme-BootCheck" -Action $a4 -Trigger $t4 -Force | Out-Null

        # WiFi/网络连接时触发（解决开机时网络未就绪的问题）
        $vbsNet = Join-Path $PSScriptRoot "run-netconnected.vbs"
        $a5 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsNet`""
        # 使用事件触发器：Microsoft-Windows-NetworkProfile/Operational 事件ID 10000（网络已连接）
        $t5 = New-ScheduledTaskTrigger -AtLogOn  # 先创建基础触发器
        $t5xml = $t5.ExportXml()
        # 替换为事件触发器（XML方式）
        $eventTriggerXml = @"
<Triggers xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <EventTrigger>
    <Enabled>true</Enabled>
    <Subscription>
      <![CDATA[
        <QueryList>
          <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
            <Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[(EventID=10000)]]</Select>
          </Query>
        </QueryList>
      ]]>
    </Subscription>
    <Delay>PT10S</Delay>
  </EventTrigger>
</Triggers>
"@
        Register-ScheduledTask -TaskName "AutoTheme-NetworkCheck" -Action $a5 -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Force | Out-Null
        # 用 XML 注册事件触发器
        $taskXml = Get-ScheduledTask -TaskName "AutoTheme-NetworkCheck" | Export-ScheduledTask
        $taskXml = $taskXml -replace '<Triggers>.*?</Triggers>', $eventTriggerXml
        Unregister-ScheduledTask -TaskName "AutoTheme-NetworkCheck" -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName "AutoTheme-NetworkCheck" -Xml $taskXml -Force | Out-Null

        Write-Log "Registered all tasks: Sunrise=$($sun.sunrise) Sunset=$($sun.sunset)"
    } catch {
        Write-Log "WARN: Cannot register tasks: $_"
    }

    Write-Log "====== Setup Complete ======"
} catch {
    Write-Log "ERROR: $_"
    exit 1
}
