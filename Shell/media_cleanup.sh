#!/bin/bash
#
# Hybrid Media Auto-Cleanup Script with Enhanced Logging
#

MEDIA_ROOTS=(
    "/data/media/movies"
    "/data/media/tv"
    "/data/media/anime"
)

LOG_FILE="/var/log/media_cleanup.log"
MIN_AGE=10                 # days (don’t touch newer files or dirs)
THRESHOLD=80               # % usage to trigger cleanup
FREESPACE_TARGET=60        # stop deleting once below this

# Logging function with levels
log() {
    local LEVEL="$1"
    local MSG="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $MSG" | tee -a "$LOG_FILE"
}

for MEDIA_DIR in "${MEDIA_ROOTS[@]}"; do
    log "INFO" "Scanning media folder: $MEDIA_DIR"

    if [ ! -d "$MEDIA_DIR" ]; then
        log "ERROR" "Folder $MEDIA_DIR does not exist. Skipping."
        continue
    fi

    #USAGE=$(df -P --output=pcent "$MEDIA_DIR" | tail -1 | tr -d '%')
    USAGE=$(df "$MEDIA_DIR" | awk 'NR==2 {print $5}' | tr -d '%')
    log "INFO" "Current disk usage: $USAGE%"

    if [ "$USAGE" -gt "$THRESHOLD" ]; then
        log "INFO" "Usage $USAGE% > $THRESHOLD%. Starting cleanup..."

        FILE_DELETED=0
        TOTAL_SIZE=0
        FILE_COUNT=0
        DIR_COUNT=0

        # Delete old files
        FILES=$(find "$MEDIA_DIR" -mindepth 2 -type f -mtime +$MIN_AGE -printf '%T@ %p\n' | sort -n | awk '{print $2}')
        for FILE in $FILES; do
            #USAGE=$(df -h "$MEDIA_DIR" | awk 'NR==2 {gsub(/%/,""); print $5}')
            USAGE=$(df -P --output=pcent "$MEDIA_DIR" | tail -1 | tr -d '%')
            if [ "$USAGE" -le "$FREESPACE_TARGET" ]; then
                log "INFO" "Usage dropped to $USAGE%. Stopping cleanup in $MEDIA_DIR."
                break
            fi

            FILE_SIZE_BYTES=$(stat -c%s "$FILE")
            FILE_SIZE_HUMAN=$(du -h "$FILE" | cut -f1)
            log "DELETE" "File: $FILE | Size: $FILE_SIZE_HUMAN"
            rm -f "$FILE"
            FILE_DELETED=1
            TOTAL_SIZE=$((TOTAL_SIZE + FILE_SIZE_BYTES))
            ((FILE_COUNT++))
        done

        # Delete empty directories older than MIN_AGE if files were deleted
        if [ "$FILE_DELETED" -eq 1 ]; then
            EMPTY_DIRS=$(find "$MEDIA_DIR" -mindepth 2 -type d -empty -mtime +$MIN_AGE)
            for DIR in $EMPTY_DIRS; do
                log "DELETE" "Empty directory: $DIR"
                rmdir "$DIR"
                ((DIR_COUNT++))
            done
        fi

        log "INFO" "Cleanup finished for $MEDIA_DIR: Deleted $FILE_COUNT files, Freed $(numfmt --to=iec $TOTAL_SIZE), Removed $DIR_COUNT directories"
        USAGE=$(df -P --output=pcent "$MEDIA_DIR" | tail -1 | tr -d '%')
        log "INFO" "Current disk usage after cleanup: $USAGE%"
    else
        log "INFO" "Usage below threshold for $MEDIA_DIR. No cleanup needed."
    fi
done
