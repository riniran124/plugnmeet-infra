# invoke-backup.ps1 — копирование последней резервной копии plugNmeet с сервера на клиентский хост
# и проверка контрольных сумм. Запускается планировщиком заданий ежедневно в 03:00.
$Server = "riniran@srv-1.gerber.org"
$Remote = "/var/backups/plugnmeet"
$Local  = "C:\Backups\plugnmeet"
$Log    = "C:\Backups\invoke-backup.log"

New-Item -ItemType Directory -Force -Path $Local | Out-Null
function Write-Log($Message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Add-Content -Path $Log -Encoding UTF8
}

try {
    $latest = (ssh -o BatchMode=yes $Server "ls -1 $Remote | tail -n 1" | Out-String).Trim()
    if (-not $latest) { throw "на сервере нет резервных копий или нет доступа" }
    if (Test-Path "$Local\$latest\SHA256SUMS") { Write-Log "SKIP $latest уже скопирована"; exit 0 }

    scp -o BatchMode=yes -r "${Server}:$Remote/$latest" "$Local"
    if ($LASTEXITCODE -ne 0) { throw "scp завершился с кодом $LASTEXITCODE" }

    foreach ($line in Get-Content "$Local\$latest\SHA256SUMS") {
        $hash, $name = $line -split '\s+', 2
        $actual = (Get-FileHash "$Local\$latest\$($name.TrimStart('*'))" -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $hash) { throw "контрольная сумма не совпала: $name" }
    }
    Write-Log "OK $latest скопирована, контрольные суммы совпали"
}
catch {
    Write-Log "FAIL $_"
    exit 1
}
