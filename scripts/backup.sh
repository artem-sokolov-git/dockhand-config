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

usage() {
  echo "Usage: $0 [backup|restore [archive.tar.gz]]"
  exit 1
}

do_backup() {
  mkdir -p "$DEST"
  ARCHIVE="$DEST/$DATE.tar.gz"
  ARCHIVE_TMP="${ARCHIVE}.tmp"

  echo "Source : $SOURCE"
  echo "Dest   : $DEST"
  echo ""
  echo "Backing up..."
  if tar -czf "$ARCHIVE_TMP" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")"; then
    mv "$ARCHIVE_TMP" "$ARCHIVE"
    echo "Done: $ARCHIVE"
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
    if [[ ! -d "$DEST" ]] || ! compgen -G "$DEST/*.tar.gz" > /dev/null 2>&1; then
      echo "Error: no backups found in $DEST"
      exit 1
    fi
    echo "Available backups:"
    ls -lht "$DEST"/*.tar.gz
    echo ""
    archive=$(find "$DEST" -maxdepth 1 -name "*.tar.gz" -print0 | xargs -0 ls -t | head -1)
    echo "Restoring latest: $archive"
  else
    archive="$1"
  fi

  if [[ ! -f "$archive" ]]; then
    echo "Error: $archive not found"
    exit 1
  fi

  if [[ -t 0 ]]; then
    read -r -p "This will replace $SOURCE. Continue? [y/N] " confirm
    [[ "$confirm" != "y" ]] && echo "Aborted." && exit 0
  else
    echo "Non-interactive mode: proceeding with restore of $archive"
  fi

  echo "Restoring from $archive..."
  rm -rf "$SOURCE"
  tar -xzf "$archive" -C "$(dirname "$SOURCE")"

  echo "Done."
}

case "${1:-}" in
  backup)  do_backup ;;
  restore) do_restore "${2:-}" ;;
  *)       usage ;;
esac
