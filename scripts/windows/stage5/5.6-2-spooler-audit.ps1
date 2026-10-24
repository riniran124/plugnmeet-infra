# Этап 5.6, шаг 2: отключение Spooler и включение аудита входа
function Run($c) { Write-Host "PS> $c" -ForegroundColor Yellow; Invoke-Expression $c | Out-Host }
Run 'Stop-Service Spooler -Force'
Run 'reg add "HKLM\SYSTEM\CurrentControlSet\Services\Spooler" /v Start /t REG_DWORD /d 4 /f'
Run 'Get-Service Spooler | Select-Object Name, Status, StartType'
Run 'reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v SCENoApplyLegacyAuditPolicy /t REG_DWORD /d 1 /f'
Run 'auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable'
Run 'auditpol /set /subcategory:"{0CCE9216-69AE-11D9-BED3-505054503030}" /success:enable'
Run 'auditpol /set /subcategory:"{0CCE9217-69AE-11D9-BED3-505054503030}" /failure:enable'
Run 'auditpol /get /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030},{0CCE9216-69AE-11D9-BED3-505054503030},{0CCE9217-69AE-11D9-BED3-505054503030}"'
