#!/usr/bin/env bash
# cleanup_copied_files.sh
# Deletes files from a copied_files folder according to a named ruleset.
# Rulesets (extensions to delete, filename patterns to delete) live in a
# config file (default: cleanup_rules.json) instead of the script's source.
# Run this after copy_files_new_folder.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Configuration ────────────────────────────────────────────────────────────
TARGET_DIR=""
MODE=""
CONFIG_FILE="${SCRIPT_DIR}/cleanup_rules.json"

usage() {
    cat >&2 <<EOF
Usage: ./cleanup_copied_files.sh <folder> [--mode <name>] [--config <file>]

  <folder>          Folder to clean up (required)
  --mode <name>     Ruleset to apply, e.g. "frontend" or "backend".
                     Must match a top-level key in the config file.
                     If omitted, the script guesses from the folder name
                     and prints a warning — it never guesses silently.
  --config <file>   Path to the rules config (default: cleanup_rules.json
                     next to this script)

Examples:
  ./cleanup_copied_files.sh copied_files_App_Frontend --mode frontend
  ./cleanup_copied_files.sh copied_files_App_Backend --mode backend
  ./cleanup_copied_files.sh copied_files_App_Frontend   # falls back to name-based guess
EOF
    exit 1
}

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            shift
            MODE="${1:-}"
            ;;
        --config)
            shift
            CONFIG_FILE="${1:-}"
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
            else
                echo "Error: unexpected argument '$1'" >&2
                usage
            fi
            ;;
    esac
    shift || true
done

[[ -z "$TARGET_DIR" ]] && usage

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a valid directory." >&2
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: config file '$CONFIG_FILE' not found." >&2
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
echo "Target directory : $TARGET_DIR"
echo "Config file      : $CONFIG_FILE"

# ── Resolve mode: explicit flag wins; folder-name guess is a fallback only ────
if [[ -z "$MODE" ]]; then
    if [[ "$TARGET_DIR" == *"Frontend"* || "$TARGET_DIR" == *"frontend"* ]]; then
        MODE="frontend"
    elif [[ "$TARGET_DIR" == *"Backend"* || "$TARGET_DIR" == *"backend"* ]]; then
        MODE="backend"
    else
        echo "Error: no --mode given and could not guess one from the folder name." >&2
        echo "       Pass --mode explicitly, e.g. --mode frontend" >&2
        exit 1
    fi
    echo "⚠️  No --mode given — guessed mode '$MODE' from the folder name." >&2
    echo "    Pass --mode explicitly to avoid relying on this guess." >&2
fi

echo "Mode             : $MODE"
echo ""

# ── Minimal JSON reader ───────────────────────────────────────────────────────
# Extracts the object for a given top-level key, then string arrays within it.
# Deliberately simple: assumes the flat, one-level-deep shape documented in
# cleanup_rules.json (no nested objects, no escaped quotes in values).

extract_mode_block() {
    local mode="$1" file="$2"
    awk -v key="\"${mode}\"" '
        index($0, key) && $0 ~ key ":" { capture=1 }
        capture {
            print
            depth += gsub(/{/, "{") - gsub(/}/, "}")
            if (depth == 0 && capture) { exit }
        }
    ' "$file"
}

extract_array() {
    # $1 = key name, rest = block text on stdin
    local key="$1"
    awk -v key="\"${key}\"" '
        index($0, key) && $0 ~ key "[[:space:]]*:" { capture=1 }
        capture {
            print
            if (/\]/) exit
        }
    ' | grep -oE '"[^"]*"' | tail -n +2 | tr -d '"' | while IFS= read -r line; do
        printf '%s\n' "${line//\\\\/\\}"
    done
}

MODE_BLOCK="$(extract_mode_block "$MODE" "$CONFIG_FILE")"

if [[ -z "$MODE_BLOCK" ]]; then
    echo "Error: mode '$MODE' not found in config file '$CONFIG_FILE'." >&2
    echo "       Available modes: $(grep -oE '^\s*"[a-zA-Z0-9_-]+"\s*:\s*\{' "$CONFIG_FILE" | grep -oE '"[a-zA-Z0-9_-]+"' | tr -d '"' | paste -sd, -)" >&2
    exit 1
fi

mapfile -t EXTENSIONS < <(extract_array "extensions" <<< "$MODE_BLOCK")
mapfile -t PATTERNS   < <(extract_array "patterns"   <<< "$MODE_BLOCK")

if [[ ${#EXTENSIONS[@]} -eq 0 && ${#PATTERNS[@]} -eq 0 ]]; then
    echo "Warning: mode '$MODE' has no extensions or patterns defined — nothing to delete." >&2
fi

# ── Delete ────────────────────────────────────────────────────────────────────
deleted=0

delete_by_extension() {
    local ext="$1"
    while IFS= read -r -d '' file; do
        echo "  [DELETED] $(basename "$file")  (extension: .$ext)"
        rm "$file"
        (( deleted++ )) || true
        # -iname, not -name: assets routinely ship as Logo.PNG or photo.JPG,
        # and a case-sensitive match leaves those binaries in the bundle.
    done < <(find "$TARGET_DIR" -type f -iname "*.${ext}" -print0)
}

delete_by_pattern() {
    local pattern="$1"
    while IFS= read -r -d '' file; do
        if [[ "$(basename "$file")" =~ $pattern ]]; then
            echo "  [DELETED] $(basename "$file")  (pattern: $pattern)"
            rm "$file"
            (( deleted++ )) || true
        fi
    done < <(find "$TARGET_DIR" -type f -print0)
}

echo "Deleting files for mode '$MODE'..."
echo "───────────────────────────────────"

for ext in "${EXTENSIONS[@]}"; do
    [[ -n "$ext" ]] && delete_by_extension "$ext"
done

for pattern in "${PATTERNS[@]}"; do
    [[ -n "$pattern" ]] && delete_by_pattern "$pattern"
done

echo "───────────────────────────────────"
echo "Done. Deleted: $deleted file(s) from $TARGET_DIR"
