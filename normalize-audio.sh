#!/bin/bash

set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
MARKER_KEY="JellyfinAudioNormalized"
MARKER_VALUE="true"

PROCESSED=0
SKIPPED=0
FAILED=0

usage() {
    cat <<EOF
Usage:
  $SCRIPT_NAME -f <file> [file ...]
  $SCRIPT_NAME -d <directory>
  $SCRIPT_NAME -n -f <file> [file ...]
  $SCRIPT_NAME -n -d <directory>

Options:
  -f, --file <file>       Process a specific MKV/MP4 file.
                          Can be specified multiple times.

  -d, --directory <dir>   Recursively process all MKV/MP4 files
                          under the specified directory.

  -n, --dry-run           Show what would be processed without
                          modifying anything.

  -h, --help              Show this help message.

Examples:

  Process one episode:
    $SCRIPT_NAME -f "/media/shows/Show/Season 1/Episode.mkv"

  Process multiple episodes:
    $SCRIPT_NAME -f "/path/episode1.mkv" -f "/path/episode2.mkv"

  Process an entire show:
    $SCRIPT_NAME -d "/media/shows/Show"

  See what would be processed:
    $SCRIPT_NAME --dry-run -d "/media/shows/Show"

Already processed files are automatically skipped.
Original filenames are preserved.
Video is not re-encoded.
EOF
}

# --------------------------------------------------
# Check dependencies
# --------------------------------------------------

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ERROR: ffmpeg is not installed."
    echo
    echo "Install it with:"
    echo "  sudo apt update && sudo apt install ffmpeg"
    exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
    echo "ERROR: ffprobe is not installed."
    echo
    echo "Install it with:"
    echo "  sudo apt update && sudo apt install ffmpeg"
    exit 1
fi

# --------------------------------------------------
# Argument parsing
# --------------------------------------------------

MODE=""
DIRECTORY=""
DRY_RUN=false
FILES=()

while [[ $# -gt 0 ]]; do
    case "$1" in

        -f|--file)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: $1 requires a file."
                echo
                usage
                exit 1
            fi

            MODE="file"
            FILES+=("$2")
            shift 2
            ;;

        -d|--directory)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: $1 requires a directory."
                echo
                usage
                exit 1
            fi

            MODE="directory"
            DIRECTORY="$2"
            shift 2
            ;;

        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            echo "ERROR: Unknown option: $1"
            echo
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    echo "ERROR: You must specify -f or -d."
    echo
    usage
    exit 1
fi

# --------------------------------------------------
# Build file list
# --------------------------------------------------

if [[ "$MODE" == "file" ]]; then

    for FILE in "${FILES[@]}"; do

        if [[ ! -f "$FILE" ]]; then
            echo "ERROR: File not found:"
            echo "  $FILE"
            exit 1
        fi

        case "${FILE,,}" in
            *.mkv|*.mp4)
                ;;
            *)
                echo "ERROR: Not an MKV or MP4 file:"
                echo "  $FILE"
                exit 1
                ;;
        esac

    done

elif [[ "$MODE" == "directory" ]]; then

    if [[ ! -d "$DIRECTORY" ]]; then
        echo "ERROR: Directory not found:"
        echo "  $DIRECTORY"
        exit 1
    fi

    mapfile -d '' FILES < <(
        find "$DIRECTORY" -type f \
            \( -iname "*.mkv" -o -iname "*.mp4" \) \
            -print0
    )

    if [[ "${#FILES[@]}" -eq 0 ]]; then
        echo "No MKV or MP4 files found."
        exit 0
    fi

fi

# --------------------------------------------------
# Dry run
# --------------------------------------------------

if [[ "$DRY_RUN" == true ]]; then

    echo "DRY RUN - no files will be modified."
    echo

    for FILE in "${FILES[@]}"; do
        echo "$FILE"
    done

    echo
    echo "Found ${#FILES[@]} file(s)."
    exit 0

fi

# --------------------------------------------------
# Process files
# --------------------------------------------------

for INPUT in "${FILES[@]}"; do

    echo
    echo "========================================"
    echo "Checking:"
    echo "$INPUT"
    echo "========================================"

    # ------------------------------------------------
    # Check whether we've already processed this file
    # ------------------------------------------------

    MARKER=$(
        ffprobe -v error \
            -show_entries format_tags="$MARKER_KEY" \
            -of default=noprint_wrappers=1:nokey=1 \
            "$INPUT" 2>/dev/null || true
    )

    if [[ "${MARKER,,}" == "$MARKER_VALUE" ]]; then
        echo "[SKIP] Already normalized."
        ((SKIPPED++))
        continue
    fi

    # ------------------------------------------------
    # Temporary file
    # ------------------------------------------------

    DIR="$(dirname "$INPUT")"
    FILE="$(basename "$INPUT")"
    EXT="${FILE##*.}"

    TEMP="$DIR/.${FILE}.normalized.tmp.${EXT}"

    rm -f "$TEMP"

    echo "[PROCESS] $INPUT"

    # ------------------------------------------------
    # Process
    #
    # - Video is copied without re-encoding
    # - Audio is normalized
    # - Subtitles are copied
    # - All streams are retained
    # - Marker is written into container metadata
    # ------------------------------------------------

    if ffmpeg -hide_banner -loglevel warning \
        -i "$INPUT" \
        -map 0 \
        -map_metadata 0 \
        -c:v copy \
        -c:a aac -b:a 192k \
        -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
        -c:s copy \
        -metadata "$MARKER_KEY=$MARKER_VALUE" \
        "$TEMP"
    then

        echo "[SUCCESS] FFmpeg completed."

        # Make sure the temporary file actually exists
        if [[ ! -f "$TEMP" ]]; then
            echo "[FAILED] Temporary file was not created."
            ((FAILED++))
            continue
        fi

        # Replace original with processed file.
        # Filename remains EXACTLY the same.
        if mv -f "$TEMP" "$INPUT"; then
            echo "[DONE] Original replaced."
            ((PROCESSED++))
        else
            echo "[FAILED] Could not replace original."
            rm -f "$TEMP"
            ((FAILED++))
        fi

    else

        echo "[FAILED] FFmpeg returned an error."
        echo "[UNCHANGED] Original file was NOT modified."

        rm -f "$TEMP"
        ((FAILED++))

    fi

done

# --------------------------------------------------
# Summary
# --------------------------------------------------

echo
echo "========================================"
echo "Finished"
echo "========================================"
echo "Processed: $PROCESSED"
echo "Skipped:   $SKIPPED"
echo "Failed:    $FAILED"
echo
