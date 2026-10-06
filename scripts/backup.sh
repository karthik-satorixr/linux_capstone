#!/bin/bash
#
# backup.sh - make a timestamped .tar.gz backup of a directory
#
# Usage:   ./backup.sh <source_directory>
# Example: ./backup.sh ~/capstone/data
#
# Exit codes:
#   0 = backup created
#   1 = no source directory was given
#   2 = source directory does not exist
#   3 = tar failed while creating the archive

# ---------- Settings ----------
BACKUP_DIR="$HOME/capstone/backups"         # where the archives are saved
LOG_FILE="$HOME/capstone/logs/backup.log"   # where every run is recorded
RETENTION_DAYS=7                            # archives older than this are deleted

# ---------- Helper functions ----------
# Current date and time, e.g. 2026-10-05 14:30:00
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Print a SUCCESS line on the screen and append it to the log file
log_success() {
    echo "[$(timestamp)] SUCCESS: $1" | tee -a "$LOG_FILE"
}

# Print an ERROR line on the screen (stderr) and append it to the log file
log_error() {
    echo "[$(timestamp)] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Make sure the backup and log folders exist (does nothing if they already do)
mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

# ---------- Step 1: check the input ----------
SOURCE="$1"

if [ -z "$SOURCE" ]; then
    log_error "no source directory given. Usage: $0 <source_directory>"
    exit 1
fi

if [ ! -d "$SOURCE" ]; then
    log_error "source directory '$SOURCE' does not exist"
    exit 2
fi

SOURCE=$(realpath "$SOURCE")    # turn e.g. "../data" into "/home/<you>/capstone/data"

# ---------- Step 2: create the archive ----------
ARCHIVE_NAME="backup-$(date '+%Y-%m-%d-%H%M').tar.gz"   # e.g. backup-2026-10-05-1430.tar.gz
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"

# tar: -c create, -z compress with gzip, -f write to this file.
# -C moves into the parent folder first, so the archive contains "data/..."
#    instead of the full "/home/<you>/capstone/data/..." path.
if tar -czf "$ARCHIVE_PATH" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")"; then
    log_success "archived $SOURCE → $ARCHIVE_NAME"
else
    rm -f "$ARCHIVE_PATH"          # remove the broken, half-written archive
    log_error "tar failed while archiving $SOURCE"
    exit 3
fi

# ---------- Step 3: delete old archives ----------
# We only get here if the new backup worked, so old backups are never
# deleted while new ones are failing.
# -mtime +7 = last modified more than 7 days ago. -print shows each deleted file.
find "$BACKUP_DIR" -type f -name 'backup-*.tar.gz' -mtime +"$RETENTION_DAYS" -print -delete

exit 0

