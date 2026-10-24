# Этап 5.6, шаг 3: UAC, снимок «после» и сравнение
function Run($c) { Write-Host "PS> $c" -ForegroundColor Yellow; Invoke-Expression $c | Out-Host }
$uac = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Run 'reg add $uac /v EnableLUA /t REG_DWORD /d 1 /f'
Run 'reg add $uac /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 2 /f'
Run 'reg add $uac /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f'
Run 'reg export "HKLM\SYSTEM\CurrentControlSet\Services\Spooler" C:\Reg\after-spooler.reg /y'
Run 'reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" C:\Reg\after-uac.reg /y'
Run 'reg export "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" C:\Reg\after-lsa.reg /y'
Run 'Compare-Object (Get-Content C:\Reg\before-spooler.reg) (Get-Content C:\Reg\after-spooler.reg)'
Run 'Compare-Object (Get-Content C:\Reg\before-uac.reg) (Get-Content C:\Reg\after-uac.reg)'
Run 'Compare-Object (Get-Content C:\Reg\before-lsa.reg) (Get-Content C:\Reg\after-lsa.reg)'
