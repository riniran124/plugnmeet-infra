#!/bin/bash
# backup_plugnmeet.sh — резервное копирование plugNmeet:
# база данных MariaDB, конфигурация компонентов, файлы пользователей (загрузки, записи).
# Каждая копия — отдельный каталог /var/backups/plugnmeet/ГГГГММДД-ЧЧММСС с файлом SHA256SUMS.
set -euo pipefail

BACKUP_ROOT=/var/backups/plugnmeet
DEST="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
LOG=/var/log/plugnmeet/backup.log

log() {
    echo "$(date '+%F %T') $*" >> "$LOG"
    logger -t backup_plugnmeet "$*"
}
trap 'log "FAIL: ошибка в строке $LINENO"; exit 1' ERR

mkdir -p "$DEST"
log "START $DEST"

# 1. База данных (--single-transaction — согласованный снимок без блокировки таблиц)
mysqldump --single-transaction --routines --events plugnmeet_v2 | gzip > "$DEST/plugnmeet_v2.sql.gz"

# 2. Конфигурация (отсутствующие файлы пропускаются)
tar --ignore-failed-read -czf "$DEST/config.tar.gz" \
    /opt/plugnmeet/config.yaml /opt/plugnmeet/client/dist/assets/config.js \
    /opt/livekit/livekit.yaml /etc/nats/nats-server.conf /etc/turnserver.conf \
    /etc/nginx/sites-available/plugnmeet /etc/samba/smb.conf \
    /etc/systemd/system/plugnmeet.service /etc/systemd/system/nats.service \
    /etc/systemd/system/livekit.service /etc/plugnmeet \
    /etc/ssl/gerber-ca /etc/ssl/private/meet-gerber.key /etc/ssl/certs/meet-gerber-fullchain.crt \
    2>/dev/null

# 3. Файлы пользователей
tar -czf "$DEST/data.tar.gz" -C /opt/plugnmeet upload recording_files artifacts

# 4. Контрольные суммы и права (читать может только группа pnmbackup)
cd "$DEST" && sha256sum -- *.gz > SHA256SUMS
chgrp -R pnmbackup "$DEST"
chmod 750 "$DEST" && chmod 640 "$DEST"/*

log "OK $(du -sh "$DEST" | cut -f1) $DEST"
