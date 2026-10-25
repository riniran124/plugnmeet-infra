#!/bin/bash
# check_plugnmeet.sh — проверка доступности plugNmeet. Запускается таймером каждые 5 минут.
# Результат каждой проверки -> /var/log/plugnmeet/check.log (OK / FAIL причина).
# При смене состояния (отказ / восстановление) — уведомление: alerts.log, журнал (crit), wall, Telegram (если настроен).

LOG=/var/log/plugnmeet/check.log
ALERTS=/var/log/plugnmeet/alerts.log
STATE_FILE=/var/lib/plugnmeet-check/state
NOTIFY_CONF=/etc/plugnmeet/notify.conf   # необязательный: TG_TOKEN=... TG_CHAT=...

PROBLEMS=()

# 1. Службы
for svc in plugnmeet livekit nats nginx mariadb redis-server coturn samba-ad-dc; do
    systemctl is-active --quiet "$svc" || PROBLEMS+=("служба $svc не активна")
done
# Любые другие упавшие службы (INC-001: дублирующая nats-server.service висела в failed незамеченной).
# Саму check-plugnmeet.service не считаем: она в failed после каждой неуспешной проверки.
failed=$(systemctl list-units --state=failed --no-legend --plain | awk '$1 != "check-plugnmeet.service" {print $1}' | paste -sd, -)
[ -z "$failed" ] || PROBLEMS+=("службы в состоянии failed: $failed")

# 2. Сервис снаружи — так, как его видит пользователь (через nginx и TLS)
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://meet.gerber.org/)
[ "$code" = "200" ] || PROBLEMS+=("https://meet.gerber.org/ ответил $code")
curl -sf -o /dev/null --max-time 5 https://livekit.gerber.org/ || PROBLEMS+=("LiveKit не отвечает")
curl -sf -o /dev/null --max-time 5 http://127.0.0.1:8223/healthz || PROBLEMS+=("NATS healthz не отвечает")
mysqladmin --connect-timeout=5 ping >/dev/null 2>&1 || PROBLEMS+=("MariaDB не отвечает")

# 3. Ресурсы хоста
disk=$(df --output=pcent / | tail -1 | tr -dc '0-9')
[ "$disk" -lt 90 ] || PROBLEMS+=("корневой раздел заполнен на ${disk}%")
mem=$(free | awk '/^Mem:/{printf "%d", $7*100/$2}')
[ "$mem" -gt 10 ] || PROBLEMS+=("доступно только ${mem}% памяти")

notify() {
    echo "$(date '+%F %T') $1" >> "$ALERTS"
    logger -t check_plugnmeet -p user.crit "$1"
    wall "plugNmeet: $1" 2>/dev/null
    if [ -r "$NOTIFY_CONF" ]; then
        . "$NOTIFY_CONF"
        [ -n "${TG_TOKEN:-}" ] && curl -s --max-time 10 \
            "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d chat_id="$TG_CHAT" \
            --data-urlencode text="srv-1 plugNmeet: $1" >/dev/null
    fi
}

prev=$(cat "$STATE_FILE" 2>/dev/null || echo OK)
if [ ${#PROBLEMS[@]} -eq 0 ]; then
    echo "$(date '+%F %T') OK" >> "$LOG"
    [ "$prev" = "FAIL" ] && notify "ВОССТАНОВЛЕН: все проверки пройдены"
    echo OK > "$STATE_FILE"
    exit 0
else
    text=$(printf '%s; ' "${PROBLEMS[@]}")
    echo "$(date '+%F %T') FAIL $text" >> "$LOG"
    [ "$prev" = "OK" ] && notify "ОТКАЗ: $text"
    echo FAIL > "$STATE_FILE"
    exit 1
fi
