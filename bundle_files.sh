#!/usr/bin/env bash
# bundle_files.sh
# Bundles all files from a folder into a single .md file for AI project knowledge (e.g. Claude, ChatGPT, Gemini).
# With --by-extension, creates one .md per file extension in a new folder.
# With --suffix <name>, adds a suffix to all output filenames.
# With --max-size <kb>, splits output into numbered files if size limit is exceeded.
# Run this after cleanup_copied_files.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=rules_lib.sh
source "${SCRIPT_DIR}/rules_lib.sh"

# Rule state stays empty unless --mode is given, so the default behaviour is
# unchanged: bundle every file found.
EXCLUDE_DIRS=(); EXTENSIONS=(); PATTERNS=(); KEEP=()
RULES_PRUNE_ARGS=()
MODE=""
CONFIG_FILE="${SCRIPT_DIR}/cleanup_rules.json"
ignored=0

# ── Configuration ────────────────────────────────────────────────────────────
SOURCE_DIR="${1:-}"
BY_EXTENSION=false
OUTPUT_FILE=""
MAX_SIZE_KB=0  # 0 = no limit
SUFFIX=""

usage() {
    cat >&2 <<EOF
Usage: ./bundle_files.sh <folder> [output_file.md] [options]

  <folder>            Folder to bundle (required)
  output_file.md      Output filename, single mode only
                       (default: <folder_name>.md)
  --by-extension      Write one .md per file extension
  --suffix <name>     Append a suffix to all output filenames
  --max-size <kb>     Split output into numbered parts past this size
  --mode <name>       Apply a ruleset from the config while walking, so
                       excluded directories and files are never read
  --rules <file>      Path to the ruleset config
                       (default: cleanup_rules.json next to this script)
  -h, --help          Show this message

Examples:
  ./bundle_files.sh copied_files_App_Frontend
  ./bundle_files.sh copied_files_App_Frontend frontend.md
  ./bundle_files.sh copied_files_App_Frontend --by-extension --max-size 800
EOF
    exit 1
}

shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --by-extension) BY_EXTENSION=true ;;
        --max-size)
            # Without this guard a missing value shifts past the end and
            # set -e aborts the run with no output at all.
            [[ $# -ge 2 ]] || { echo "Error: --max-size requires a value in KB." >&2; usage; }
            shift
            MAX_SIZE_KB="$1"
            [[ "$MAX_SIZE_KB" =~ ^[0-9]+$ ]] || {
                echo "Error: --max-size expects a whole number of KB, got '$MAX_SIZE_KB'." >&2; usage; }
            ;;
        --suffix)
            [[ $# -ge 2 ]] || { echo "Error: --suffix requires a value." >&2; usage; }
            shift
            SUFFIX="_$1"
            ;;
        --mode)
            [[ $# -ge 2 ]] || { echo "Error: --mode requires a name." >&2; usage; }
            shift
            MODE="$1"
            ;;
        --rules)
            [[ $# -ge 2 ]] || { echo "Error: --rules requires a file." >&2; usage; }
            shift
            CONFIG_FILE="$1"
            ;;
        -h|--help) usage ;;
        # Anything else beginning with - is a mistyped flag. Falling through to
        # OUTPUT_FILE would silently turn --by-extention into an output called
        # "--by-extention.md" while quietly running in single mode.
        -*) echo "Error: unknown option '$1'." >&2; usage ;;
        *)
            if [[ -z "$OUTPUT_FILE" ]]; then
                OUTPUT_FILE="$1"
            else
                echo "Error: unexpected argument '$1'." >&2
                usage
            fi
            ;;
    esac
    shift
done
# ─────────────────────────────────────────────────────────────────────────────

if [[ -z "$SOURCE_DIR" ]]; then
    echo "Error: Please provide a folder to bundle." >&2
    echo "Usage: ./bundle_files.sh <folder> [output_file.md] [--by-extension] [--max-size <kb>]" >&2
    exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: '$SOURCE_DIR' is not a valid directory." >&2
    exit 1
fi

SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
FOLDER_NAME="$(basename "$SOURCE_DIR")"

if [[ -n "$MODE" ]]; then
    rules_load_mode "$MODE" "$CONFIG_FILE" || exit 1
    rules_build_prune_args
fi

# ── Detect language for code block ───────────────────────────────────────────
get_language() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}"
    case "$ext" in
        ts|tsx)       echo "tsx" ;;
        js|jsx)       echo "jsx" ;;
        css)          echo "css" ;;
        scss|sass)    echo "scss" ;;
        html)         echo "html" ;;
        json)         echo "json" ;;
        xml)          echo "xml" ;;
        md)           echo "markdown" ;;
        py)           echo "python" ;;
        sh|bash)      echo "bash" ;;
        cs)           echo "csharp" ;;
        java)         echo "java" ;;
        go)           echo "go" ;;
        rs)           echo "rust" ;;
        sql)          echo "sql" ;;
        yaml|yml)     echo "yaml" ;;
        toml)         echo "toml" ;;
        env)          echo "bash" ;;
        txt)          echo "text" ;;
        *)            echo "" ;;
    esac
}

# ── Build a file block as a string ───────────────────────────────────────────
build_block() {
    local file="$1"
    local relative_path="${file#$SOURCE_DIR/}"
    local lang
    lang="$(get_language "$file")"

    printf '%s\n' "---" "## ${relative_path}" "---" "\`\`\`${lang}"
    cat "$file"
    printf '\n%s\n\n' '```'
}

# ── Write to file, split if max size exceeded ─────────────────────────────────
# current_part and current_file are deliberately global: write_block_to must be
# callable without a subshell so its part counter survives between files.
current_part=1
current_file=""
write_block_to() {
    local block="$1"
    local base_name="$2"

    # Determine current output filename
    if [[ "$MAX_SIZE_KB" -gt 0 ]]; then
        current_file="${base_name}_${current_part}.md"
    else
        current_file="${base_name}.md"
    fi

    # Initialize file with header if it doesn't exist
    if [[ ! -f "$current_file" ]]; then
        {
            echo "# ${FOLDER_NAME} — bundled files (part ${current_part})"
            echo "# Generated by bundle_files.sh on $(date '+%Y-%m-%d')"
            echo ""
        } > "$current_file"
    fi

    # Check if adding this block would exceed max size
    if [[ "$MAX_SIZE_KB" -gt 0 ]]; then
        current_size_kb=$(( $(wc -c < "$current_file") / 1024 ))
        block_size_kb=$(( ${#block} / 1024 ))
        if (( current_size_kb + block_size_kb >= MAX_SIZE_KB )); then
            current_part=$(( current_part + 1 ))
            current_file="${base_name}_${current_part}.md"
            if [[ ! -f "$current_file" ]]; then
                {
                    echo "# ${FOLDER_NAME} — bundled files (part ${current_part})"
                    echo "# Generated by bundle_files.sh on $(date '+%Y-%m-%d')"
                    echo ""
                } > "$current_file"
            fi
        fi
    fi

    echo "$block" >> "$current_file"
}

# ── Bundle files ──────────────────────────────────────────────────────────────
bundle_files() {
    local base_name="$1"
    local filter_ext="${2:-}"  # optional: only bundle files with this extension

    local bundled=0
    local skipped=0
    local ignored=0

    while IFS= read -r -d '' file; do
        relative_path="${file#$SOURCE_DIR/}"
        filename="$(basename "$file")"

        # Ruleset filter. Excluded directories are already pruned by find, so
        # only name-based rules are checked here. A keep rule overrides them.
        if [[ -n "$MODE" ]] && ! rules_should_keep "$filename" \
           && rules_matches "$filename"; then
            echo "  [IGNORED]  $relative_path  ($RULES_MATCH_REASON)" >&2
            (( ignored++ )) || true
            continue
        fi

        # Filter by extension if specified
        if [[ -n "$filter_ext" ]]; then
            filename="$(basename "$file")"
            ext="${filename##*.}"
            # Must mirror the extension-collection logic below. Without this,
            # extensionless files match no bucket and are silently dropped.
            [[ "$filename" == "$ext" ]] && ext="no_extension"
            ext="${ext,,}"
            [[ "$ext" != "$filter_ext" ]] && continue
        fi

        # Skip binary files. -b prints the type only; without it the file's
        # own path is part of the matched string, so any file inside a
        # directory whose name contains "text" is misdetected as text.
        if ! file -b "$file" | grep -qE 'text|empty|JSON|ASCII'; then
            echo "  [SKIP]     $relative_path  (binary)" >&2
            (( skipped++ )) || true
            continue
        fi

        block="$(build_block "$file")"
        # Called directly, not in $(...): a subshell would discard the
        # current_part increment, so every file after the first would land on
        # part 2 and truncate it. write_block_to reports back via current_file.
        write_block_to "$block" "$base_name"
        echo "  [BUNDLED]  $relative_path → $(basename "$current_file")" >&2
        (( bundled++ )) || true

    done < <(find "$SOURCE_DIR" ${RULES_PRUNE_ARGS[@]+"${RULES_PRUNE_ARGS[@]}"} -type f -print0 | sort -z)

    # Returned rather than left in globals: this function is called inside
    # $(...), so any counter incremented here dies with the subshell.
    echo "$bundled $skipped $ignored"
}

# ── MODE: single .md ─────────────────────────────────────────────────────────
if [[ "$BY_EXTENSION" == false ]]; then
    OUTPUT_DIR="${FOLDER_NAME}_bundled"

    if [[ -e "$OUTPUT_DIR" ]]; then
        echo "Error: '$OUTPUT_DIR' already exists." >&2
        exit 1
    fi

    mkdir "$OUTPUT_DIR"

    BASE_NAME="${OUTPUT_FILE:-$FOLDER_NAME}"
    BASE_NAME="${BASE_NAME%.md}"  # strip .md if provided
    BASE_NAME="${OUTPUT_DIR}/${BASE_NAME}${SUFFIX}"

    echo "Source directory : $SOURCE_DIR"
    echo "Output folder    : $OUTPUT_DIR"
    [[ "$MAX_SIZE_KB" -gt 0 ]] && echo "Max file size    : ${MAX_SIZE_KB}KB"
    [[ -n "$SUFFIX" ]] && echo "Suffix           : ${SUFFIX#_}"
    echo ""

    read -r bundled skipped ignored <<< "$(bundle_files "$BASE_NAME")"

    # If no splitting occurred, remove the _1 suffix
    if [[ -f "${BASE_NAME}_1.md" && ! -f "${BASE_NAME}_2.md" ]]; then
        mv "${BASE_NAME}_1.md" "${BASE_NAME}.md"
    fi

    echo ""
    echo "───────────────────────────────────"
    echo "Done. Bundled: $bundled  |  Skipped: $skipped binary file(s)"
    (( ignored > 0 )) && echo "Ignored by mode '$MODE': $ignored file(s)"
    echo "Output folder: $OUTPUT_DIR"
fi

# ── MODE: one .md per extension ──────────────────────────────────────────────
if [[ "$BY_EXTENSION" == true ]]; then
    OUTPUT_DIR="${FOLDER_NAME}_bundled"

    if [[ -e "$OUTPUT_DIR" ]]; then
        echo "Error: '$OUTPUT_DIR' already exists." >&2
        exit 1
    fi

    mkdir "$OUTPUT_DIR"

    echo "Source directory : $SOURCE_DIR"
    echo "Output folder    : $OUTPUT_DIR"
    [[ "$MAX_SIZE_KB" -gt 0 ]] && echo "Max file size    : ${MAX_SIZE_KB}KB"
    [[ -n "$SUFFIX" ]] && echo "Suffix           : ${SUFFIX#_}"
    echo ""

    # Collect all unique extensions
    declare -A seen_exts
    total_ignored=0
    while IFS= read -r -d '' file; do
        filename="$(basename "$file")"
        if [[ -n "$MODE" ]] && ! rules_should_keep "$filename" \
           && rules_matches "$filename"; then
            # Counted here rather than summed from each per-extension pass:
            # bundle_files re-walks the tree once per bucket, so accumulating
            # there would count the same ignored file once per bucket.
            (( total_ignored++ )) || true
            continue
        fi
        ext="${filename##*.}"
        [[ "$filename" == "$ext" ]] && ext="no_extension"
        ext="${ext,,}"   # one bucket per extension, regardless of its case
        seen_exts["$ext"]=1
    done < <(find "$SOURCE_DIR" ${RULES_PRUNE_ARGS[@]+"${RULES_PRUNE_ARGS[@]}"} -type f -print0)

    total_bundled=0
    total_skipped=0

    for ext in "${!seen_exts[@]}"; do
        current_part=1
        read -r bundled skipped ignored <<< "$(bundle_files "$OUTPUT_DIR/${ext}${SUFFIX}" "$ext")"

        # If no splitting occurred, remove the _1 suffix
        if [[ -f "${OUTPUT_DIR}/${ext}${SUFFIX}_1.md" && ! -f "${OUTPUT_DIR}/${ext}${SUFFIX}_2.md" ]]; then
            mv "${OUTPUT_DIR}/${ext}${SUFFIX}_1.md" "${OUTPUT_DIR}/${ext}${SUFFIX}.md"
        fi

        (( total_bundled += bundled )) || true
        (( total_skipped += skipped )) || true
    done

    echo ""
    echo "───────────────────────────────────"
    echo "Done. Bundled: $total_bundled  |  Skipped: $total_skipped binary file(s)"
    (( total_ignored > 0 )) && echo "Ignored by mode '$MODE': $total_ignored file(s)"
    echo "Output folder: $OUTPUT_DIR"
fi
