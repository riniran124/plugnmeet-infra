# Отчёт о диагностике инцидента (пост-мортем)

| Параметр | Значение |
|---|---|
| Номер | INC-001 |
| Дата и время обнаружения | 25.10.2026 16:09 |
| Время устранения | 25.10.2026 16:10 (длительность диагностики и устранения: 2 мин; дефект существовал с 18.10.2026) |
| Сервис | plugNmeet, srv-1.gerber.org (компонент NATS — чат и события комнат) |
| Приоритет | P2 — частичный отказ: при проигрыше «гонки» пропадают чат и события комнат у всех пользователей; на момент обнаружения влияния на пользователей не было |
| Обнаружено | плановая проверка «первые 2 минуты» (`systemctl --failed`) перед этапом 8 |

## 1. Симптом
После включения сервера команда `systemctl --failed` показала две службы с ошибкой:

```
● check-plugnmeet.service loaded failed failed Проверка доступности plugNmeet
● nats-server.service     loaded failed failed NATS Server
```

В `/var/log/plugnmeet/check.log` была запись об отказе почти всех служб в 16:07:39, через 3 секунды после загрузки, а следующая проверка в 16:09:10 прошла (`OK`).
Скриншоты: `8.0-первые-2-минуты.png`, `8.7-INC-001-диагностика-nats.png`.

## 2. Гипотезы и их проверка
| № | Гипотеза | Команда проверки | Результат | Вывод |
|---|---|---|---|---|
| 1 | Не работает брокер NATS, нужный plugNmeet | `systemctl is-active nats` | active | отвергнута |
| 2 | nats-server.service — вторая копия NATS, которая не может занять порт | `journalctl -u nats-server.service \| grep FTL` | `bind: address already in use` на 127.0.0.1:4222 | ПОДТВЕРЖДЕНА |
| 3 | Порт 4222 занят нашей службой nats.service | `ss -tlnp \| grep 4222`, `systemctl show -p MainPID nats.service` | PID 726 — это nats.service | ПОДТВЕРЖДЕНА |
| 4 | Лишняя служба пришла из пакета Ubuntu | `dpkg -S /lib/systemd/system/nats-server.service` | пакет `nats-server` (установлен 18.10.2026 00:25) | ПОДТВЕРЖДЕНА |
| 5 | Гонка уже проигрывалась нашей службой | `journalctl -u nats.service \| grep 'address already in use'` | 20.10.2026 19:00:59 nats.service не смогла занять порт | ПОДТВЕРЖДЕНА |
| 6 | Отказ в check.log — настоящий сбой сервиса | `uptime`, время записи в check.log | проверка запущена через 3 с после загрузки, когда службы ещё стартовали | отвергнута: ложная тревога |
| 7 | Таймер проверки запускается сразу после загрузки | `systemctl cat check-plugnmeet.timer` | `Persistent=true` — systemd «догоняет» пропущенный запуск при загрузке | ПОДТВЕРЖДЕНА |

## 3. Локализация
- **Основная причина:** юнит `/lib/systemd/system/nats-server.service` из пакета Ubuntu `nats-server` 2.10.7. Он включён по умолчанию (`enabled`), использует свой конфиг `/etc/nats-server.conf` на том же адресе 127.0.0.1:4222, что и наша служба `/etc/systemd/system/nats.service` (конфиг `/etc/nats/nats-server.conf` с JetStream и auth_callout для plugNmeet).
  При каждой загрузке две службы стартуют одновременно, и порт достаётся той, что успела первой. Если первой успеет пакетная служба, то plugNmeet подключится к NATS без JetStream и без нужной авторизации, и в комнатах пропадут чат и события.
- **Сопутствующий дефект:** параметр `Persistent=true` в `systemd/check-plugnmeet.timer` (репозиторий) и `/etc/systemd/system/check-plugnmeet.timer`. Из-за него после загрузки проверка запускается раньше, чем стартуют службы, и в журнал попадает ложный «ОТКАЗ».

## 4. Устранение
```
sudo systemctl disable --now nats-server.service
sudo systemctl mask nats-server.service          # чтобы пакет не включил её снова при обновлении
sudo systemctl reset-failed nats-server.service

cd /opt/plugnmeet-infra
sudo sed -i 's/^Persistent=true/Persistent=false\nOnBootSec=3min/' systemd/check-plugnmeet.timer
sudo install -m 644 systemd/check-plugnmeet.timer /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl restart check-plugnmeet.timer
```

Проверка после исправления:
```
$ systemctl is-enabled nats-server.service nats.service
masked enabled
$ systemctl --failed --no-legend | wc -l
0
$ sudo check_plugnmeet.sh; tail -1 /var/log/plugnmeet/check.log
2026-10-25 16:10:52 OK
```
Скриншот: `8.7-INC-001-устранение-nats.png`.

## 5. Корневая причина
На этапе 3 NATS сначала поставили из пакета Ubuntu (`apt install nats-server`, версия 2.10.7), а потом заменили на нужную plugNmeet версию 2.10.11 (`/usr/local/bin/nats-server`) со своим юнитом `nats.service`. Пакет при этом не удалили и его службу не отключили.
Проверки, которая искала бы службы в состоянии failed, не было: `check_plugnmeet.sh` проверяет только `nats.service` и порт, а порт был занят «правильной» службой. Поэтому дефект неделю оставался незамеченным.

## 6. Хронология
| Время | Событие |
|---|---|
| 18.10.2026 00:25 | Установлен пакет `nats-server` 2.10.7, его служба включена по умолчанию |
| 20.10.2026 19:00 | nats.service проиграла гонку: `bind: address already in use` (запись в журнале) |
| 21.10.2026 22:35 | Установлен текущий юнит nats.service; пакетная служба осталась включённой |
| 22.10, 24.10, 25.10 | При каждой загрузке nats-server.service падает (10 раз за 21 загрузку) |
| 25.10.2026 16:07:36 | Загрузка сервера |
| 25.10.2026 16:07:39 | check_plugnmeet: ложный «ОТКАЗ» (службы ещё стартуют) |
| 25.10.2026 16:09 | Проверка «первые 2 минуты»: обнаружены 2 службы в состоянии failed, начата диагностика |
| 25.10.2026 16:10 | Причина найдена: дублирующая служба из пакета и `Persistent=true` в таймере |
| 25.10.2026 16:10:52 | Исправлено, `systemctl --failed` пуст, check_plugnmeet: OK |

## 7. Меры предотвращения
- Добавить в `check_plugnmeet.sh` проверку `systemctl --failed`: любая упавшая служба — повод для записи в alerts.log. Ответственный: администратор (Гербер А.С.), срок — этап 9.
- При замене пакетной программы на собранную вручную удалять пакет или маскировать его службу (`systemctl mask`), а сам шаг записывать в git. Включить это правило в процедуру изменений на этапе 9.
- После каждой перезагрузки выполнять «первые 2 минуты» (раздел 8.0 методички).
- Таймер мониторинга: `Persistent=false` и `OnBootSec=3min`, чтобы не было ложных тревог при загрузке (сделано, коммит этапа 8).

## 8. Выводы
Дефект был «тихим»: сервис работал, но его работа зависела от того, какая служба первой успеет занять порт при загрузке. Обнаружить его удалось только общей проверкой `systemctl --failed`, а не проверкой конкретного сервиса. Устранение заняло 2 минуты, а вот без проверки дефект мог бы проявиться в любой момент после перезагрузки, например во время занятия.

---

# Приложение. Тренировка по шести сценариям отказа (25.10.2026)

Перед тренировкой созданы снимки обеих ВМ `etap8-start`. Каждый отказ внесён вручную по методичке, найден по циклу «симптом → гипотезы → проверка → локализация → устранение» и устранён. Скриншоты лежат в папке «скрины восьмой этап».

| № | Сценарий | Отказ внесён | Устранён | Как внесли | Чем нашли | Чем устранили |
|---|---|---|---|---|---|---|
| 1 | Сервис недоступен (порт) | 16:11:15 | 16:11:43 | `port: 8081` в config.yaml | `curl` → 502; `ss -tlnp`: plugNmeet на 8081; nginx `proxy_pass` на 8080; error.log: `Connection refused` | вернуть `port: 8080`, `systemctl restart plugnmeet` |
| 2а | БД: неверный пароль | 16:12:11 | 16:12:36 | `ALTER USER ... IDENTIFIED BY 'wrong'` | журнал plugnmeet: `Error 1045 Access denied`; вход в MariaDB с паролем из config.yaml — тот же отказ | задать в MariaDB пароль из config.yaml, перезапустить plugnmeet |
| 2б | БД: нет места на диске | 16:12:55 | 16:13:53 | `fallocate` на всё свободное место | `df -h`: 100%; MariaDB: `Errcode: 28 No space left on device`; `du`/`find`: файл `/var/tmp/big.fill` 20 ГБ | удалить файл, перезапустить mariadb и plugnmeet |
| 3 | Истёк срок учётной записи | 16:14:35 | 16:15:07 | `samba-tool user setexpiry student --days=0` | pnm-login: DENY; `ldapwhoami`: `data 701`; `kinit`: `credentials have been revoked`; `pdbedit`: Kickoff time | `samba-tool user setexpiry student --noexpiry` |
| 4 | Резервное копирование (права) | 16:15:31 | 16:16:26 | `chattr +i /var/backups/plugnmeet` | backup.log: `FAIL: ошибка в строке 17`; журнал: `mkdir: Operation not permitted`; `lsattr`: флаг `i`; журнал sudo: кто выполнил chattr | `chattr -i`, проверить владельца и права, запустить бэкап вручную |
| 5 | Нехватка памяти | 16:20:26 | 16:24:07 | `stress-ng --vm 1 --vm-bytes 4200M --vm-keep` | `free`: доступно 33 МБ, swap 1,6 ГБ; `vmstat`: si/so ≈ 110 000, wa 30–40 %; `ps --sort=-%mem`: stress-ng-vm 86 % | `kill` процесса, `swapoff -a && swapon -a` |
| 6 | Клиент не находит домен (DNS) | 16:27:22 | 16:31:09 | на Windows DNS = 8.8.8.8 | `nslookup gerber.org` → чужой адрес 64.118.87.49; `nltest`: `1355 ERROR_NO_SUCH_DOMAIN`; SRV-записи нет; при прямом запросе к 192.168.122.10 SRV есть → виноват клиент | `Set-DnsClientServerAddress ... 192.168.122.10`, `ipconfig /flushdns /registerdns`, `nltest` и `Test-ComputerSecureChannel` — успешно |

Наблюдения по ходу тренировки:
- Сценарий 4: auditd не записал `chattr +i`. Правило `-w ... -p wa` ловит запись и смену атрибутов (chmod, chown), а флаг immutable меняется через ioctl. Кто выполнил команду, видно в журнале sudo (`journalctl _COMM=sudo`).
- Сценарий 6: `Test-ComputerSecureChannel` во время отказа отвечал «канал в хорошем состоянии», потому что Netlogon помнил контроллер, найденный до сбоя. Надёжнее проверять `nltest /dsgetdc:gerber.org /force`, он ищет контроллер заново.
- Сценарий 2б: каталог `/root/.cache` занимает 3,1 ГБ — кандидат на очистку.
