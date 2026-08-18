# test-admin.ps1 - 用于测试管理员模式下的配置读取和时间解析
$ErrorActionPreference = "Stop"

$ConfigDir = Join-Path $env:USERPROFILE ".auto-theme"
$ConfigFile = Join-Path $ConfigDir "config.json"

Write-Host "=== Admin Mode Test ==="
Write-Host "ConfigFile: $ConfigFile"

if (Test-Path $ConfigFile) {
    $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    Write-Host "sunrise: $($cfg.sunrise)"
    Write-Host "sunset: $($cfg.sunset)"
    
    if ($cfg.sunrise -and $cfg.sunset) {
        $srTime = [DateTime]::Parse("2000-01-01 $($cfg.sunrise)")
        $ssTime = [DateTime]::Parse("2000-01-01 $($cfg.sunset)")
        Write-Host "Parsed OK: $srTime / $ssTime"
        
        # Check existing tasks
        $tasks = Get-ScheduledTask -TaskName "AutoTheme-*" -ErrorAction SilentlyContinue
        if ($tasks) {
            Write-Host "Existing tasks:"
            $tasks | Format-Table TaskName, State -AutoSize
        } else {
            Write-Host "No AutoTheme tasks found"
        }
    } else {
        Write-Host "ERROR: sunrise or sunset is empty!"
    }
} else {
    Write-Host "ERROR: config.json not found!"
}

Write-Host "=== Test Complete ==="
