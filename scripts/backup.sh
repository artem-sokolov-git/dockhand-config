#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$PROJECT_DIR/data"

MOUNT_POINT="/mnt/samsung_ssd"
BACKUP_DIR="$MOUNT_POINT/backup/dockhand"
LOG_FILE="$MOUNT_POINT/backup/dockhand-backup.log"

MAX_ATTEMPTS=3
RETRY_DELAY=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

ensure_mounted() {
    local attempt=1
    while (( attempt <= MAX_ATTEMPTS )); do
        if mountpoint -q "$MOUNT_POINT"; then
            log "Диск $MOUNT_POINT смонтирован"
            return 0
        fi

        log "Диск $MOUNT_POINT не смонтирован, попытка монтирования $attempt/$MAX_ATTEMPTS..."
        mount "$MOUNT_POINT" || true

        if mountpoint -q "$MOUNT_POINT"; then
            log "Диск $MOUNT_POINT успешно смонтирован"
            return 0
        fi

        attempt=$(( attempt + 1 ))
        (( attempt <= MAX_ATTEMPTS )) && sleep "$RETRY_DELAY"
    done

    log "Ошибка: не удалось смонтировать $MOUNT_POINT после $MAX_ATTEMPTS попыток"
    return 1
}

run_backup() {
    local attempt=1
    while (( attempt <= MAX_ATTEMPTS )); do
        log "Резервное копирование, попытка $attempt/$MAX_ATTEMPTS: $SOURCE_DIR -> $BACKUP_DIR"

        if rsync -a --delete --human-readable --info=progress2 "$SOURCE_DIR/" "$BACKUP_DIR/"; then
            log "Резервное копирование успешно завершено"
            return 0
        fi

        log "Резервное копирование не удалось (попытка $attempt/$MAX_ATTEMPTS)"
        attempt=$(( attempt + 1 ))
        (( attempt <= MAX_ATTEMPTS )) && sleep "$RETRY_DELAY"
    done

    log "Ошибка: резервное копирование не удалось после $MAX_ATTEMPTS попыток"
    return 1
}

main() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log "Ошибка: директория источника $SOURCE_DIR не найдена"
        exit 1
    fi

    ensure_mounted || exit 1

    mkdir -p "$BACKUP_DIR"
    exec > >(tee -a "$LOG_FILE") 2>&1

    log "=== Запуск резервного копирования dockhand ==="
    run_backup || exit 1
    log "=== Резервное копирование завершено успешно ==="
}

main "$@"
