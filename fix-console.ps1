# 将默认终端改回 Windows Console Host，让 -WindowStyle Hidden 生效
$consolePath = "HKCU:\Console\%%Startup"
$consoleHostClsid = "{00000000-0000-0000-0000-000000000000}"

if (-not (Test-Path $consolePath)) {
    New-Item -Path $consolePath -Force | Out-Null
}

Set-ItemProperty -Path $consolePath -Name "DelegationConsole" -Value $consoleHostClsid -Type String
Set-ItemProperty -Path $consolePath -Name "DelegationTerminal" -Value $consoleHostClsid -Type String

Write-Host "已将默认终端改回 Windows Console Host"
Write-Host "DelegationConsole: $consoleHostClsid"
Write-Host "DelegationTerminal: $consoleHostClsid"
Write-Host ""
Write-Host "下次开机 AutoTheme-BootCheck 就不会弹窗了"
