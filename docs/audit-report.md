# Отчёт по аудиту и журналированию (этап 6)

## 1. Linux (srv-1.gerber.org)
| Средство | Настройка | Где смотреть |
|---|---|---|
| auditd | /etc/audit/rules.d/plugnmeet.rules: ключи pnm_config, pnm_secret, identity, samba_config, pnm_backup | `ausearch -k <ключ> -i`, `aureport -k --summary` |
| journald | Storage=persistent, 500 МБ, 1 месяц (/etc/systemd/journald.conf.d/plugnmeet.conf) | `journalctl -u plugnmeet`, `journalctl -p crit` |
| logrotate | /etc/logrotate.d/plugnmeet: еженедельно, 8 архивов, gzip | /var/log/plugnmeet/ |
| Samba | log level = 1 auth_audit:3 auth_json_audit:3 | /var/log/samba/log.samba (строки `Auth:`) |

Сводка auditd на 25.10.2026 (`aureport -k --summary`):

| Ключ | Событий |
|---|---|
| identity | 32 |
| pnm_config | 31 |
| pnm_secret | 11 |
| samba_config | 5 |
| pnm_backup | 4 |

Пример события auditd (изменение config.yaml, `ausearch -k pnm_config -i`):
```
type=SYSCALL msg=audit(10/25/2026 03:30:57.144:505) : syscall=openat ... auid=riniran uid=root comm=touch exe=/usr/bin/touch key=pnm_config
type=PATH ... name=/opt/plugnmeet/config.yaml ...
```
auid показывает исходного пользователя (riniran), даже если команда выполнена через sudo от root.

Пример срабатывания мониторинга в journald (`journalctl -p crit`):
```
Oct 25 01:55:06 srv-1.gerber.org check_plugnmeet[20932]: ОТКАЗ: LiveKit не отвечает;
Oct 25 02:00:04 srv-1.gerber.org check_plugnmeet[21064]: ВОССТАНОВЛЕН: все проверки пройдены
```

## 2. Windows (WIN-CL1)
| Средство | Настройка | Событие |
|---|---|---|
| Аудит входа | auditpol: Вход (успех и сбой), Выход (успех), Блокировка (сбой) | 4624, 4625, 4740 |
| Аудит C:\Backups | SACL «Все»: ReadData/WriteData/Delete, успех и отказ; auditpol: Файловая система (успех и сбой), Работа с дескриптором (сбой) | 4663, 4656 |
| Права на C:\Backups | только Администраторы и SYSTEM (icacls /inheritance:r) | — |
| PowerShell | ScriptBlockLogging = 1 | 4104 |

Проверка:
- admin читает C:\Backups\plugnmeet\...\SHA256SUMS — 4663 «Аудит успеха»;
- student выполняет `Get-ChildItem C:\Backups` — «Отказано в доступе», событие 4656 «Аудит отказа», объект C:\backups;
- тестовая команда `Write-Output 'проверка журналирования'; Get-Date` записана в событии 4104 дословно.

Замечание: после ограничения прав задание планировщика plugnmeet\invokebackup (запуск от admin с ограниченным токеном UAC) получило код 1 — нет доступа к C:\Backups. Исправлено: заданию установлен уровень запуска «Наивысшие права» (RunLevel = Highest), повторный запуск — код 0.

Для события 4656 потребовалось дополнительно включить подкатегорию «Работа с дескриптором» (GUID 0CCE9223) на сбой: без неё отказ доступа к каталогу в журнал не попадал.

## 3. Сопоставление события «вход пользователя student» (25.10.2026)
| Время | Источник | Событие | Подробности |
|---|---|---|---|
| 03:54:25 | Samba AD (srv-1) | Auth: Kerberos KDC, ENC-TS Pre-authentication, NT_STATUS_WRONG_PASSWORD | user student@GERBER, aes256-cts-hmac-sha1-96 |
| 03:54:13 | Windows Security (WIN-CL1) | 4625, тип входа 2, подсостояние 0xC000006A | неверный пароль |
| 03:54:55 | Samba AD (srv-1) | Auth: Kerberos KDC, ENC-TS Pre-authentication, NT_STATUS_OK | user student@GERBER |
| 03:54:44 | Windows Security (WIN-CL1) | 4624 | успешный вход student |

Вывод: одно и то же событие видно в журналах обеих ОС. Контроллер фиксирует проверку учётных данных (Kerberos), клиент — факт входа в сеанс.
Время на клиенте отставало от контроллера примерно на 12 секунд: клиент синхронизируется с внешним источником ntp1.vniiftri.ru (w32tm /query /source), а не с контроллером домена (NTP на srv-1 не настроен, см. этап 1). Расхождение меньше допуска Kerberos (5 минут), поэтому вход работает; для точного сопоставления событий клиент следует синхронизировать с контроллером домена (w32tm /config /syncfromflags:domhier).
