Write-Host "=== AutoTheme Tasks ==="
Get-ScheduledTask -TaskName "AutoTheme-*" | ForEach-Object {
    $triggers = ($_.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ","
    $action = "$($_.Actions[0].Execute) $($_.Actions[0].Arguments)"
    Write-Host "  $($_.TaskName): State=$($_.State) Triggers=$triggers"
    Write-Host "    Action: $action"
}

Write-Host ""
Write-Host "=== All Logon Tasks Running PowerShell ==="
Get-ScheduledTask | Where-Object {
    $_.State -ne "Disabled" -and
    ($_.Actions | Where-Object { $_.Execute -match "powershell|cmd" }) -and
    ($_.Triggers | Where-Object { $_.CimClass.CimClassName -eq "MSFT_TaskLogonTrigger" })
} | ForEach-Object {
    Write-Host "  $($_.TaskName) -> $($_.Actions[0].Execute)"
}

Write-Host ""
Write-Host "=== Recent log entries ==="
$log = Join-Path $env:USERPROFILE ".auto-theme\auto-theme.log"
if (Test-Path $log) { Get-Content $log -Tail 10 } else { Write-Host "No log file" }
