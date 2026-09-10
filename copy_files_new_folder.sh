#!/usr/bin/env bash
# copy_files_new_folder.sh
# Copies all files from SOURCE_DIR into a newly created folder in the current directory,
# preserving the original subfolder structure so files with the same name don't collide.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
SOURCE_DIR="${1:-.}"              # default: current directory
if [[ -n "${1:-}" ]]; then
    FOLDER_NAME="${2:-copied_files_${1##*/}}"  # e.g. copied_files_App_Frontend
else
    FOLDER_NAME="${2:-copied_files}"
fi
# ─────────────────────────────────────────────────────────────────────────────

# Resolve to absolute path
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
TARGET_DIR="$(pwd)/$FOLDER_NAME"

echo "Source directory : $SOURCE_DIR"

# ── Create the target folder ─────────────────────────────────────────────────
if [[ -e "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' already exists. Choose a different folder name." >&2
    exit 1
fi

mkdir "$TARGET_DIR"
echo "Created folder   : $TARGET_DIR"
echo ""

# ── Find and copy all files ──────────────────────────────────────────────────
mapfile -d '' files < <(find "$SOURCE_DIR" -type f -not -path "$TARGET_DIR/*" -print0)

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No files found in '$SOURCE_DIR'. Nothing to copy."
    exit 0
fi

echo "Files to copy    : ${#files[@]}"
echo "───────────────────────────────────"

copied=0
collisions=0

for file in "${files[@]}"; do
    relative_path="${file#"$SOURCE_DIR"/}"
    dest="$TARGET_DIR/$relative_path"

    # Paths are preserved now, so this should not fire. It still can on a
    # case-insensitive filesystem (macOS/Windows), where Switch.tsx and
    # switch.tsx in the same folder are the same path. Warn, don't lose it.
    if [[ -e "$dest" ]]; then
        echo "  [COLLISION] $relative_path  (case-insensitive filesystem — earlier copy overwritten)" >&2
        (( collisions++ )) || true
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
    echo "  [COPIED] $relative_path"
    (( copied++ )) || true
done

echo "───────────────────────────────────"
echo "Done. Copied: $copied file(s) → $TARGET_DIR"
if (( collisions > 0 )); then
    echo "Warning: $collisions name collision(s) — that many file(s) were lost." >&2
fi
