# Этап 5.7: локальная групповая политика для группы «Не администраторы» (MLGPO):
# Конфигурация пользователя -> Административные шаблоны -> Система -> Доступ к съёмным запоминающим устройствам ->
# «Все классы съёмных запоминающих устройств: Запретить любой доступ» = Включено.
# Те же файлы создаёт оснастка «Редактор объектов групповой политики» (mmc) при сохранении.
function Run($c) { Write-Host "PS> $c" -ForegroundColor Yellow; Invoke-Expression $c | Out-Host }
$gpo = "C:\Windows\System32\GroupPolicyUsers\S-1-5-32-545"
Run 'New-Item -ItemType Directory -Force "$gpo\User" | Select-Object FullName'
Run 'Copy-Item C:\Reg\gpo\gpt.ini "$gpo\gpt.ini" -Force'
Run 'Copy-Item C:\Reg\gpo\Registry.pol "$gpo\User\Registry.pol" -Force'
Run 'Get-Content "$gpo\gpt.ini"'
Run 'gpupdate /force'
