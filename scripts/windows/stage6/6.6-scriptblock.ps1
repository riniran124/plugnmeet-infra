# Этап 6.6: журналирование блоков сценариев PowerShell (событие 4104)
function Run($c) { Write-Host "PS> $c" -ForegroundColor Yellow; Invoke-Expression $c | Out-Host }
Run 'reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" /v EnableScriptBlockLogging /t REG_DWORD /d 1 /f'
Run 'powershell -Command "Write-Output ''проверка журналирования''; Get-Date"'
Start-Sleep 2
Run 'Get-WinEvent -FilterHashtable @{LogName="Microsoft-Windows-PowerShell/Operational"; Id=4104} -MaxEvents 3 | Format-List TimeCreated, Id, @{n="Message";e={($_.Message -split "`n" | Select-Object -First 3) -join " "}}'
