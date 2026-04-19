#!/bin/bash
# ~/.dockhand/scripts/backup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env not found at $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

: "${DOCKHAND_DATA:?Error: DOCKHAND_DATA is not set in .env}"
: "${DOCKHAND_BACKUPS:?Error: DOCKHAND_BACKUPS is not set in .env}"

SOURCE="${DOCKHAND_DATA}"
DEST="${DOCKHAND_BACKUPS}"
DATE=$(date +%Y%m%d_%H%M%S)

get_password() {
  if [[ -n "${DOCKHAND_BACKUP_PASSWORD:-}" ]]; then
    echo "$DOCKHAND_BACKUP_PASSWORD"
  elif [[ -t 0 ]]; then
    local pass
    read -r -s -p "Backup password: " pass
    echo "" >&2
    echo "$pass"
  else
    echo "Error: DOCKHAND_BACKUP_PASSWORD is not set in .env" >&2
    exit 1
  fi
}

usage() {
  echo "Usage: $0 [backup|restore [archive.tar.gz.enc]]"
  exit 1
}

do_backup() {
  mkdir -p "$DEST"
  ARCHIVE="$DEST/$DATE.tar.gz.enc"
  ARCHIVE_TMP="${ARCHIVE}.tmp"

  echo "Source : $SOURCE"
  echo "Dest   : $DEST"
  echo ""

  local password
  password=$(get_password)

  echo "Backing up..."
  if tar -cz -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")" \
    | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -pass "pass:${password}" \
    > "$ARCHIVE_TMP"; then
    mv "$ARCHIVE_TMP" "$ARCHIVE"
    shasum -a 256 "$ARCHIVE" > "${ARCHIVE}.sha256"
    echo "Done: $ARCHIVE"
    echo "Hash: $(cut -d' ' -f1 < "${ARCHIVE}.sha256")"
    echo "Size: $(du -sh "$ARCHIVE" | cut -f1)"
  else
    rm -f "$ARCHIVE_TMP"
    echo "Error: backup failed, incomplete archive removed"
    exit 1
  fi
}

do_restore() {
  local archive

  if [[ -z "${1:-}" ]]; then
    if [[ ! -d "$DEST" ]] || ! compgen -G "$DEST/*.tar.gz.enc" > /dev/null 2>&1; then
      echo "Error: no backups found in $DEST"
      exit 1
    fi
    echo "Available backups:"
    ls -lht "$DEST"/*.tar.gz.enc
    echo ""
    archive=$(find "$DEST" -maxdepth 1 -name "*.tar.gz.enc" -print0 | xargs -0 ls -t | head -1)
    echo "Restoring latest: $archive"
  else
    archive="$1"
  fi

  if [[ ! -f "$archive" ]]; then
    echo "Error: $archive not found"
    exit 1
  fi

  local checksum_file="${archive}.sha256"
  if [[ -f "$checksum_file" ]]; then
    echo "Verifying checksum..."
    if ! shasum -a 256 --check "$checksum_file" --status; then
      echo "Error: checksum mismatch, archive may be corrupted"
      exit 1
    fi
    echo "Checksum OK"
  else
    echo "Warning: no checksum file found, skipping verification"
  fi

  if [[ -t 0 ]]; then
    read -r -p "This will replace $SOURCE. Continue? [y/N] " confirm
    [[ "$confirm" != "y" ]] && echo "Aborted." && exit 0
  else
    echo "Non-interactive mode: proceeding with restore of $archive"
  fi

  local password
  password=$(get_password)

  echo "Restoring from $archive..."
  rm -rf "$SOURCE"
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass "pass:${password}" -in "$archive" \
    | tar -xz -C "$(dirname "$SOURCE")"

  echo "Done."
}

case "${1:-}" in
  backup)  do_backup ;;
  restore) do_restore "${2:-}" ;;
  *)       usage ;;
esac
