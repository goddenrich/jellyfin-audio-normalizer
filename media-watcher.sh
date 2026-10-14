#!/bin/bash

set -uo pipefail

# --------------------------------------------------
# Configuration
# --------------------------------------------------
WATCH_DIRS=(
    "/home/goddenrich/media/external_5TB/Films"
    "/home/goddenrich/media/external_5TB/TV Shows"
)
NORMALIZE_SCRIPT="/home/goddenrich/repos/jellyfin-audio-normalizer/normalize-audio.sh" # Adjust to your script path

# Check dependencies
if ! command -v inotifywait >/dev/null 2>&1; then
    echo "ERROR: inotifywait is not installed. Install it with: sudo apt install inotify-tools" >&2
    exit 1
fi

if [[ ! -x "$NORMALIZE_SCRIPT" ]]; then
    echo "ERROR: Normalization script is not executable or not found at: $NORMALIZE_SCRIPT" >&2
    exit 1
fi

# Wait for the external drive mount to become available (up to 60 seconds)
TIMEOUT=60
ELAPSED=0
while [[ ! -d "${WATCH_DIRS[0]}" ]]; do
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo "ERROR: Timeout waiting for external drive mount: ${WATCH_DIRS[0]}" >&2
        exit 1
    fi
    sleep 5
    ((ELAPSED+=5))
done

# Check that all watch directories exist
for DIR in "${WATCH_DIRS[@]}"; do
    if [[ ! -d "$DIR" ]]; then
        echo "ERROR: Watch directory does not exist: $DIR" >&2
        exit 1
    fi
done

echo "=================================================="
echo "Starting Media Audio Normalizer Watcher"
echo "Watching ${#WATCH_DIRS[@]} directories:"
for DIR in "${WATCH_DIRS[@]}"; do
    echo "  - $DIR"
done
echo "=================================================="

# --------------------------------------------------
# Monitor Loop
# --------------------------------------------------
inotifywait -m -r -e close_write,moved_to --format '%w%f' "${WATCH_DIRS[@]}" | while read -r FILE; do
    case "${FILE,,}" in
        *.mkv|*.mp4)
            # Ignore hidden files, partial downloads, or temp files starting with a dot
            if [[ "$(basename "$FILE")" =~ ^\. ]]; then
                continue
            fi

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] New file detected: $FILE"
            
            # Run the normalization script on the specific file
            "$NORMALIZE_SCRIPT" -f "$FILE"
            ;;
    esac
done
