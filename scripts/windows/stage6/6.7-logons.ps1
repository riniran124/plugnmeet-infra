# Этап 6.7: события входа GERBER\student на клиенте (4624 — успешный вход, 4625 — неудачный)
function Run($c) { Write-Host "PS> $c" -ForegroundColor Yellow; Invoke-Expression $c | Out-Host }
Run 'w32tm /query /source'
Run 'Get-WinEvent -FilterHashtable @{LogName="Security"; Id=4624,4625; StartTime=(Get-Date).AddMinutes(-30)} | Where-Object { $_.Message -match "student" } | Select-Object -First 6 | ForEach-Object { $m = $_.Message; [pscustomobject]@{ Время = $_.TimeCreated.ToString("dd.MM.yyyy HH:mm:ss"); Id = $_.Id; ТипВхода = ([regex]::Match($m, "Тип входа:\s+(\d+)").Groups[1].Value); Код = ([regex]::Match($m, "Подсостояние:\s+(\S+)").Groups[1].Value); Адрес = ([regex]::Match($m, "Сетевой адрес источника:\s+(\S+)").Groups[1].Value) } } | Format-Table -AutoSize'
