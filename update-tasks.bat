@echo off
chcp.com 65001 >nul 2>&1
echo Updating AutoTheme tasks...

schtasks.exe /Delete /TN "AutoTheme-BootCheck" /F
schtasks.exe /Delete /TN "AutoTheme-DailySetup" /F
schtasks.exe /Delete /TN "AutoTheme-Sunrise" /F
schtasks.exe /Delete /TN "AutoTheme-Sunset" /F

schtasks.exe /Create /TN "AutoTheme-BootCheck" /TR "wscript.exe \"C:\Users\Lenovo\miclaw\project\light-dark\run-boot.vbs\"" /SC ONLOGON /F
schtasks.exe /Create /TN "AutoTheme-DailySetup" /TR "wscript.exe \"C:\Users\Lenovo\miclaw\project\light-dark\run-boot.vbs\"" /SC DAILY /ST 12:00 /F
schtasks.exe /Create /TN "AutoTheme-Sunrise" /TR "wscript.exe \"C:\Users\Lenovo\miclaw\project\light-dark\run-boot.vbs\"" /SC DAILY /ST 06:30 /F
schtasks.exe /Create /TN "AutoTheme-Sunset" /TR "wscript.exe \"C:\Users\Lenovo\miclaw\project\light-dark\run-boot.vbs\"" /SC DAILY /ST 19:30 /F

echo Done!
pause
