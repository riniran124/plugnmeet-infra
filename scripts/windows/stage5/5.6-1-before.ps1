# Этап 5.6, шаг 1: снимок «до» — экспорт ветвей реестра и текущие значения
function Run($c) { Write-Host "PS> $c" -ForegroundColor Yellow; Invoke-Expression $c | Out-Host }
New-Item -ItemType Directory -Force C:\Reg | Out-Null
Run 'reg export "HKLM\SYSTEM\CurrentControlSet\Services\Spooler" C:\Reg\before-spooler.reg /y'
Run 'reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" C:\Reg\before-uac.reg /y'
Run 'reg export "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" C:\Reg\before-lsa.reg /y'
Run 'Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\Spooler -Name Start | Select-Object Start'
Run 'Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System | Select-Object EnableLUA, ConsentPromptBehaviorAdmin, PromptOnSecureDesktop'
Run 'auditpol /get /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}"'
