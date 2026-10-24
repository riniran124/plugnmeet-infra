#!/bin/bash
# rotate_backups.sh — удаление резервных копий plugNmeet старше N дней (по умолчанию 30).
BACKUP_ROOT=/var/backups/plugnmeet
DAYS=${1:-30}
LOG=/var/log/plugnmeet/backup.log
n=0
while IFS= read -r dir; do
    rm -rf -- "$dir"
    n=$((n + 1))
    echo "$(date '+%F %T') ROTATE удалена $dir" >> "$LOG"
done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +"$DAYS")
logger -t rotate_backups "удалено копий старше $DAYS дней: $n"
