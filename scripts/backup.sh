#!/bin/bash
# ~/.dockhand/scripts/backup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env not found at $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

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

  echo "Source : $SOURCE"
  echo "Dest   : $DEST"
  echo ""
  echo "Backing up..."
  tar -czf "$ARCHIVE" -C "$(dirname $SOURCE)" "$(basename $SOURCE)"

  echo "Done: $ARCHIVE"
  echo "Size: $(du -sh $ARCHIVE | cut -f1)"
}

do_restore() {
  if [[ -z "$1" ]]; then
    echo "Available backups:"
    ls -lht "$DEST"/*.tar.gz
    echo ""
    ARCHIVE=$(ls -t "$DEST"/*.tar.gz | head -1)
    echo "Restoring latest: $ARCHIVE"
  else
    ARCHIVE="$1"
  fi

  if [[ ! -f "$ARCHIVE" ]]; then
    echo "Error: $ARCHIVE not found"
    exit 1
  fi

  read -p "This will overwrite $SOURCE. Continue? [y/N] " confirm
  [[ "$confirm" != "y" ]] && echo "Aborted." && exit 0

  echo "Restoring from $ARCHIVE..."
  tar -xzf "$ARCHIVE" -C "$(dirname $SOURCE)"

  echo "Done."
}

case "${1:-}" in
  backup)  do_backup ;;
  restore) do_restore "${2:-}" ;;
  *)       usage ;;
esac
