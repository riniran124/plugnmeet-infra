#!/bin/bash
# plugnmeet-room на сервере: печатает ссылку для входа в комнату (обёртка над pnm-join)
ARGS=()
for a in "$@"; do [ "$a" = "--print" ] || ARGS+=("$a"); done
exec sudo /usr/local/bin/pnm-join "${ARGS[@]}" 2>/dev/null
