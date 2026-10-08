# Light-Dark 一键安装脚本
# 用法：右键此文件 → 使用 PowerShell 运行
# 或在 PowerShell 中执行：.\install.ps1

$ErrorActionPreference = "Stop"
$dir = $PSScriptRoot

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Light-Dark 安装程序" -ForegroundColor Cyan
Write-Host "  Windows 日出日落自动深色/浅色切换" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查 stealth-launcher.exe（无窗口启动器）
$exePath = Join-Path $dir "stealth-launcher.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "[*] stealth-launcher.exe 不存在，正在编译..." -ForegroundColor Yellow
    $csPath = Join-Path $dir "stealth-launcher.cs"
    if (-not (Test-Path $csPath)) {
        Write-Host "[-] 找不到 stealth-launcher.cs，无法编译" -ForegroundColor Red
        exit 1
    }
    # 尝试用 .NET 自带的 csc 编译
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path $csc)) {
        $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
    }
    if (Test-Path $csc) {
        & $csc /nologo /target:winexe /out:"$exePath" "$csPath"
        Write-Host "[+] 编译完成" -ForegroundColor Green
    } else {
        Write-Host "[-] 未找到 C# 编译器，请手动编译 stealth-launcher.cs" -ForegroundColor Red
        exit 1
    }
}

# 2. 运行主脚本：定位 + 获取日出日落 + 设置主题 + 注册计划任务
Write-Host ""
Write-Host "[*] 正在获取位置和日出日落时间..." -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir "auto-theme.ps1")

# 3. 验证
Write-Host ""
Write-Host "[*] 验证计划任务..." -ForegroundColor Yellow
$tasks = Get-ScheduledTask -TaskName "AutoTheme-*" -ErrorAction SilentlyContinue
if ($tasks) {
    $tasks | Select-Object TaskName, State | Format-Table -AutoSize
    Write-Host "[+] 安装完成！" -ForegroundColor Green
    Write-Host ""
    Write-Host "  日出 -> 自动浅色 | 日落 -> 自动深色" -ForegroundColor White
    Write-Host "  每天 00:05 自动更新时间" -ForegroundColor White
    Write-Host ""
    Write-Host "  手动控制：" -ForegroundColor White
    Write-Host "    .\auto-theme.ps1 -Dark   # 强制深色" -ForegroundColor Gray
    Write-Host "    .\auto-theme.ps1 -Light  # 强制浅色" -ForegroundColor Gray
} else {
    Write-Host "[-] 计划任务注册失败，请以管理员身份重试" -ForegroundColor Red
    exit 1
}
