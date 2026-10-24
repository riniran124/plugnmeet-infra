#!/bin/bash
# pnm-login — вход в plugNmeet по доменной учётной записи gerber.org.
# Пароль проверяется привязкой к Samba AD по LDAPS, роль определяется по группам домена:
# Admins, Teachers -> admin (модератор); Students -> user; иначе — отказ.
# Использование: sudo pnm-login [ID_комнаты]
set -euo pipefail

LDAP_URI="ldaps://srv-1.gerber.org"
BASE_DN="DC=gerber,DC=org"
BIND_DN="svc-plugnmeet@gerber.org"
BIND_PW_FILE="/etc/plugnmeet/ldap.secret"
LOG=/var/log/plugnmeet/pnm-login.log
ROOM_ID=${1:-room01}

log() {
    echo "$(date '+%F %T') $*" >> "$LOG"
    logger -t pnm-login "$*"
}

read -rp "Доменный логин (gerber.org): " LOGIN
read -rsp "Пароль: " PASS; echo
# Защита от LDAP-инъекции: в логине только латиница, цифры, точка, _ и -
[[ "$LOGIN" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Недопустимый логин"; exit 1; }

# 1. Проверка пароля: привязка к LDAP от имени самого пользователя.
# Отключённая, заблокированная или истёкшая учётка тоже не пройдёт.
if ! ldapwhoami -x -H "$LDAP_URI" -D "$LOGIN@gerber.org" -y <(printf '%s' "$PASS") >/dev/null 2>&1; then
    log "DENY user=$LOGIN reason=bad_credentials_or_account_disabled"
    echo "Отказ: неверный логин/пароль, учётная запись заблокирована или истекла."
    exit 1
fi
unset PASS

# 2. Группы пользователя (ищем от имени сервисной учётной записи)
USER_GROUPS=$(ldapsearch -x -LLL -o ldif-wrap=no -H "$LDAP_URI" -D "$BIND_DN" -y "$BIND_PW_FILE" \
    -b "$BASE_DN" "(sAMAccountName=$LOGIN)" memberOf | sed -n 's/^memberOf: CN=\([^,]*\),.*/\1/p')

# 3. Роль по группам
if grep -qxE 'Admins|Teachers' <<<"$USER_GROUPS"; then
    ROLE=admin
elif grep -qx 'Students' <<<"$USER_GROUPS"; then
    ROLE=user
else
    log "DENY user=$LOGIN reason=no_group groups=$(echo $USER_GROUPS | tr ' ' ',')"
    echo "Отказ: учётная запись не входит в группы Admins, Teachers или Students."
    exit 1
fi

# 4. Создание комнаты и токена
URL=$(/usr/local/bin/pnm-join "$ROOM_ID" "$LOGIN" "$ROLE" 2>/dev/null | tail -1)
log "ALLOW user=$LOGIN role=$ROLE room=$ROOM_ID"
echo "Добро пожаловать, $LOGIN (роль: $ROLE). Ссылка действует 10 минут:"
echo "$URL"
