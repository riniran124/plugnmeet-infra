# plugnmeet-infra

Инфраструктурный репозиторий сервиса видеоконференций plugNmeet
(srv-1.gerber.org, 192.168.122.10, домен gerber.org).

| Каталог | Содержимое |
|------------------|--------------------------------------------------------|
| configs/ | конфигурации plugNmeet, LiveKit, NATS, nginx, coturn, Samba (секреты = CHANGE_ME) |
| systemd/ | модули и таймеры systemd |
| scripts/linux | сценарии bash: резервное копирование, проверка, ротация, вход по LDAP |
| scripts/windows | сценарии PowerShell: копирование копий, проверка администраторов |
| docs/ | design.md, inventory.md, audit-report.md, sla.md, incident-*.md |
| hooks/ | pre-commit: контроль синтаксиса |

Адреса: https://meet.gerber.org (plugNmeet), https://livekit.gerber.org (LiveKit).
