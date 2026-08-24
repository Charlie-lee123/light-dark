Get-ScheduledTask -TaskName 'AutoTheme-*' | ForEach-Object {
    $_.Actions[0].Execute = 'wscript.exe'
    $_.Actions[0].Arguments = '"C:\Users\Lenovo\miclaw\project\light-dark\run-boot.vbs"'
    Set-ScheduledTask -InputObject $_
    Write-Host ('Updated: ' + $_.TaskName)
}
