# Light-Dark 一键卸载脚本
# 用法：.\uninstall.ps1

$ErrorActionPreference = "Continue"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Light-Dark 卸载程序" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# 1. 删除所有计划任务
Write-Host "[*] 删除计划任务..." -ForegroundColor Yellow
$tasks = Get-ScheduledTask -TaskName "AutoTheme-*" -ErrorAction SilentlyContinue
if ($tasks) {
    $tasks | ForEach-Object {
        Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false
        Write-Host "  已删除: $($_.TaskName)" -ForegroundColor Gray
    }
    Write-Host "[+] 计划任务已全部删除" -ForegroundColor Green
} else {
    Write-Host "  没有找到计划任务" -ForegroundColor Gray
}

# 2. 删除配置和日志目录
$configDir = Join-Path $env:USERPROFILE ".auto-theme"
if (Test-Path $configDir) {
    Remove-Item $configDir -Recurse -Force
    Write-Host "[+] 配置目录已删除: $configDir" -ForegroundColor Green
}

# 3. 恢复浅色模式（可选）
Write-Host ""
$choice = Read-Host "是否恢复为浅色模式？(Y/N)"
if ($choice -eq "Y" -or $choice -eq "y") {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-ItemProperty -Path $path -Name "AppsUseLightTheme" -Value 1
    Set-ItemProperty -Path $path -Name "SystemUsesLightTheme" -Value 1
    Write-Host "[+] 已恢复浅色模式" -ForegroundColor Green
}

Write-Host ""
Write-Host "[+] 卸载完成！软件本身文件可直接删除。" -ForegroundColor Green
