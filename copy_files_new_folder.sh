#!/usr/bin/env bash
# copy_files_new_folder.sh
# Copies all files from SOURCE_DIR into a newly created folder in the current directory,
# preserving the original subfolder structure so files with the same name don't collide.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=rules_lib.sh
source "${SCRIPT_DIR}/rules_lib.sh"

EXCLUDE_DIRS=(); EXTENSIONS=(); PATTERNS=(); KEEP=()
RULES_PRUNE_ARGS=()
MODE=""
CONFIG_FILE="${SCRIPT_DIR}/cleanup_rules.json"

# ── Configuration ────────────────────────────────────────────────────────────
# Flags are separated from positionals first, so --mode can appear anywhere
# without being mistaken for the target folder name.
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            [[ $# -ge 2 ]] || { echo "Error: --mode requires a name." >&2; exit 1; }
            shift; MODE="$1"
            ;;
        --rules)
            [[ $# -ge 2 ]] || { echo "Error: --rules requires a file." >&2; exit 1; }
            shift; CONFIG_FILE="$1"
            ;;
        -*)
            echo "Error: unknown option '$1'." >&2
            echo "Usage: ./copy_files_new_folder.sh [source] [new_folder] [--mode <name>] [--rules <file>]" >&2
            exit 1
            ;;
        *) POSITIONAL+=("$1") ;;
    esac
    shift
done

SOURCE_DIR="${POSITIONAL[0]:-.}"
if [[ -n "${POSITIONAL[0]:-}" ]]; then
    FOLDER_NAME="${POSITIONAL[1]:-copied_files_${POSITIONAL[0]##*/}}"
else
    FOLDER_NAME="${POSITIONAL[1]:-copied_files}"
fi
# ─────────────────────────────────────────────────────────────────────────────

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
# Excluded directories are pruned rather than copied and deleted later: a real
# node_modules or .git is thousands of files, and not reading them at all is
# the whole saving.
if [[ -n "$MODE" ]]; then
    rules_load_mode "$MODE" "$CONFIG_FILE" || exit 1
    rules_build_prune_args
fi

mapfile -d '' files < <(find "$SOURCE_DIR" ${RULES_PRUNE_ARGS[@]+"${RULES_PRUNE_ARGS[@]}"} -type f -not -path "$TARGET_DIR/*" -print0)

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

    # Preserved paths make this unreachable on a case-sensitive filesystem.
    # Elsewhere (macOS, Windows) two names in one directory differing only in
    # case resolve to the same path, and one file is lost. Report it.
    if [[ -e "$dest" ]]; then
        echo "  [COLLISION] $relative_path  (name already taken — earlier copy overwritten)" >&2
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
