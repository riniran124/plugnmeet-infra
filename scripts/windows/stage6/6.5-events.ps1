# Этап 6.5, проверка: события доступа к C:\Backups (4663 — доступ, 4656 — запрос дескриптора, в т.ч. отказ)
function Run($c) { Write-Host "PS> $c" -ForegroundColor Yellow; Invoke-Expression $c | Out-Host }
Run 'Get-Content (Get-ChildItem C:\Backups\plugnmeet -Recurse -Filter SHA256SUMS | Select-Object -First 1).FullName | Select-Object -First 1'
Start-Sleep 2
Run 'Get-WinEvent -FilterHashtable @{LogName="Security"; Id=4663,4656; StartTime=(Get-Date).AddMinutes(-30)} | Where-Object { $_.Message -match "Backups" } | Select-Object -First 6 | ForEach-Object { $m = $_.Message; [pscustomobject]@{ Время = $_.TimeCreated; Id = $_.Id; Пользователь = ([regex]::Match($m, "Имя учетной записи:\s+(\S+)").Groups[1].Value); Объект = ([regex]::Match($m, "Имя объекта:\s+(.+)").Groups[1].Value.Trim()); Результат = $_.KeywordsDisplayNames -join "," } } | Format-Table -AutoSize -Wrap'
