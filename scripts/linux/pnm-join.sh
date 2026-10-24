#!/bin/bash
# Создание комнаты plugNmeet и выдача ссылки для входа.
# Использование: pnm-join.sh [ID_комнаты] [Имя] [admin|user]
# Пример:        pnm-join.sh room01 "Герберт" admin
set -euo pipefail

CONF=/opt/plugnmeet/config.yaml
SERVER="https://192.168.122.10"
API_KEY=$(awk '/^client:/{f=1} f&&/api_key:/{gsub(/"/,"",$2);print $2;exit}' "$CONF")
SECRET=$(awk '/^client:/{f=1} f&&/secret:/{gsub(/"/,"",$2);print $2;exit}' "$CONF")

ROOM_ID=${1:-room01}
NAME=${2:-Admin}
ROLE=${3:-admin}
IS_ADMIN=false; [ "$ROLE" = "admin" ] && IS_ADMIN=true
USER_ID=$(echo "$NAME" | md5sum | cut -c1-12)

# Запрос к API: тело подписывается HMAC-SHA256 секретом из config.yaml
api() {
    local path=$1 body=$2 sig
    sig=$(printf '%s' "$body" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $NF}')
    curl -sk -X POST "$SERVER/auth$path" \
        -H "Content-Type: application/json" \
        -H "API-KEY: $API_KEY" \
        -H "HASH-SIGNATURE: $sig" \
        -d "$body"
}

# 1. Создать комнату (если уже активна — сервер просто вернёт её данные)
CREATE=$(api /room/create "{\"room_id\":\"$ROOM_ID\",\"metadata\":{\"room_title\":\"Комната $ROOM_ID (gerber.org)\",\"welcome_message\":\"Добро пожаловать!\",\"room_features\":{\"allow_webcams\":true,\"mute_on_start\":false,\"allow_screen_share\":true,\"allow_view_other_webcams\":true,\"allow_view_other_users_list\":true,\"chat_features\":{\"is_allow\":true,\"is_allow_file_upload\":true},\"whiteboard_features\":{\"is_allow\":true}}}}")
echo "create: $CREATE" >&2

# 2. Получить токен участника
JOIN=$(api /room/getJoinToken "{\"room_id\":\"$ROOM_ID\",\"user_info\":{\"name\":\"$NAME\",\"user_id\":\"$USER_ID\",\"is_admin\":$IS_ADMIN,\"is_hidden\":false}}")
TOKEN=$(echo "$JOIN" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -z "$TOKEN" ]; then
    echo "Ошибка получения токена: $JOIN" >&2
    exit 1
fi

echo "$SERVER/?access_token=$TOKEN"
