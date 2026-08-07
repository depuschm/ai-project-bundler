#!/usr/bin/env bash
# cleanup_copied_files.sh
# Deletes frontend or backend specific files from a copied_files folder.
# Run this after copy_files_new_folder.sh.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
TARGET_DIR="${1:-}"
# ─────────────────────────────────────────────────────────────────────────────

if [[ -z "$TARGET_DIR" ]]; then
    echo "Error: Please provide a folder to clean up." >&2
    echo "Usage: ./cleanup_copied_files.sh <folder>" >&2
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a valid directory." >&2
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
echo "Target directory : $TARGET_DIR"

# ── Detect frontend or backend ───────────────────────────────────────────────
if [[ "$TARGET_DIR" == *"Frontend"* || "$TARGET_DIR" == *"frontend"* ]]; then
    MODE="frontend"
elif [[ "$TARGET_DIR" == *"Backend"* || "$TARGET_DIR" == *"backend"* ]]; then
    MODE="backend"
else
    echo "Error: Could not detect frontend or backend from folder name '$TARGET_DIR'." >&2
    echo "       Folder name must contain 'Frontend' or 'Backend'." >&2
    exit 1
fi

echo "Detected mode    : $MODE"
echo ""

deleted=0

delete_by_extension() {
    local ext="$1"
    while IFS= read -r -d '' file; do
        echo "  [DELETED] $(basename "$file")"
        rm "$file"
        (( deleted++ )) || true
    done < <(find "$TARGET_DIR" -type f -name "*.${ext}" -print0)
}

# ── Frontend cleanup ─────────────────────────────────────────────────────────
if [[ "$MODE" == "frontend" ]]; then
    echo "Deleting frontend asset files..."
    echo "───────────────────────────────────"
    for ext in png jpg jpeg svg woff2 ttf wav mp3 ico pdf; do
        delete_by_extension "$ext"
    done
fi

# ── Backend cleanup ──────────────────────────────────────────────────────────
if [[ "$MODE" == "backend" ]]; then
    echo "Deleting backend files..."
    echo "───────────────────────────────────"

    # Migration files (start with a date like 20260308022512_)
    while IFS= read -r -d '' file; do
        echo "  [DELETED] $(basename "$file")"
        rm "$file"
        (( deleted++ )) || true
    done < <(find "$TARGET_DIR" -type f -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_*" -print0)

    # launchSettings.json
    while IFS= read -r -d '' file; do
        echo "  [DELETED] $(basename "$file")"
        rm "$file"
        (( deleted++ )) || true
    done < <(find "$TARGET_DIR" -type f -name "launchSettings.json" -print0)
fi

echo "───────────────────────────────────"
echo "Done. Deleted: $deleted file(s) from $TARGET_DIR"
