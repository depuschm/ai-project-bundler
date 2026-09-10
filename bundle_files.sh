#!/usr/bin/env bash
# bundle_files.sh
# Bundles all files from a folder into a single .md file for AI project knowledge (e.g. Claude, ChatGPT, Gemini).
# With --by-extension, creates one .md per file extension in a new folder.
# With --suffix <name>, adds a suffix to all output filenames.
# With --max-size <kb>, splits output into numbered files if size limit is exceeded.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=rules_lib.sh
source "${SCRIPT_DIR}/rules_lib.sh"

# Rule state stays empty unless --mode is given, so the default behaviour is
# unchanged: bundle every file found.
EXCLUDE_DIRS=(); EXTENSIONS=(); PATTERNS=(); KEEP=()
RULES_PRUNE_ARGS=()
# Absolute path of the output folder. When bundling a directory that contains
# the output folder (e.g. bundling "."), --by-extension re-walks the tree once
# per extension, so a later bucket would otherwise ingest bundles written by an
# earlier one — md.md swallowing sh.md and json.md whole.
OUTPUT_ABS=""
MODE=""
CONFIG_FILE="${SCRIPT_DIR}/rules.json"
ignored=0
STRICT=false

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
  --strict            Fail before writing anything if a file cannot be read,
                       instead of warning and carrying on
  --mode <name>       Apply a ruleset from the config while walking, so
                       excluded directories and files are never read
  --rules <file>      Path to the ruleset config
                       (default: rules.json next to this script)
  -h, --help          Show this message

Examples:
  ./bundle_files.sh ./App_Frontend --mode frontend
  ./bundle_files.sh ./App_Frontend --mode frontend frontend.md
  ./bundle_files.sh ./App_Frontend --mode frontend --by-extension --max-size 800
EOF
    exit "${1:-1}"
}

# Checked before $1 is consumed as the source directory, otherwise
# `bundle_files.sh --help` treats --help as a folder name and reports that it
# is not a valid directory.
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage 0 ;;
    esac
done

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
        --strict)
            STRICT=true
            ;;
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

# ── Pre-flight: find unreadable files before writing anything ────────────────
# Deliberately done here, in the parent shell, and before the output folder is
# created. The bundling functions run inside $(...), so an exit there would
# only kill the subshell — and under --strict we must fail without having
# written a partial bundle that looks complete.
# A keep rule that matches nothing is almost always a typo, and this key fails
# in the dangerous direction: a mistake in an ignore rule leaves a file in the
# bundle, while a mistake here drops a file the user believed was protected.
# Checked in the parent shell — the bundling functions run inside $(...), so
# hits recorded there would not survive.
report_unused_keep_rules() {
    [[ -n "$MODE" ]] || return 0
    local rule f found
    for rule in "${KEEP[@]}"; do
        [[ -z "$rule" ]] && continue
        found=false
        while IFS= read -r -d '' f; do
            if [[ "$(basename "$f")" =~ $rule ]]; then found=true; break; fi
        done < <(find "$SOURCE_DIR" ${RULES_PRUNE_ARGS[@]+"${RULES_PRUNE_ARGS[@]}"} \
                      -type f -not -path "${OUTPUT_ABS}/*" -print0)
        if [[ "$found" == false ]]; then
            echo "⚠️  keep rule '$rule' matches no file — check it for typos." >&2
            echo "    Anything it was meant to protect has been left out." >&2
        fi
    done
}

echo "Source directory : $SOURCE_DIR"
[[ -n "$MODE" ]] && echo "Ruleset          : $MODE ($CONFIG_FILE)"
printf 'Scanning         : '

UNREADABLE=0
scanned=0
ALL_FILES=()
declare -A FILE_IS_TEXT
TYPES_OK=false
while IFS= read -r -d '' f; do
    (( scanned++ )) || true
    if [[ -r "$f" ]]; then
        ALL_FILES+=("$f")
        continue
    fi
    if [[ "$STRICT" == true ]]; then
        echo "Error: cannot read '${f#"$SOURCE_DIR"/}'." >&2
        echo "       Running with --strict, so nothing was written." >&2
        exit 1
    fi
    echo "  [WARN]     ${f#"$SOURCE_DIR"/}  (unreadable — not bundled)" >&2
    (( UNREADABLE++ )) || true
done < <(find "$SOURCE_DIR" ${RULES_PRUNE_ARGS[@]+"${RULES_PRUNE_ARGS[@]}"} -type f -print0)
printf '%s file(s) found\n' "$scanned"

# One `file` process for the whole tree instead of one per file. On a few
# thousand files that is the difference between ~13s and ~1s. Falls back to
# per-file probing if the batch output doesn't line up — `file -f -` reads
# newline-separated names, so a filename containing a newline would desync it.
if (( ${#ALL_FILES[@]} > 0 )); then
    mapfile -t _types < <(printf '%s\n' "${ALL_FILES[@]}" | file -b -f - 2>/dev/null)
    if (( ${#_types[@]} == ${#ALL_FILES[@]} )); then
        for _i in "${!ALL_FILES[@]}"; do
            case "${_types[_i]}" in
                *text*|*empty*|*JSON*|*ASCII*) FILE_IS_TEXT["${ALL_FILES[_i]}"]=1 ;;
                *)                             FILE_IS_TEXT["${ALL_FILES[_i]}"]=0 ;;
            esac
        done
        TYPES_OK=true
    fi
    unset _types _i
fi
echo

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

# ── Pick a fence longer than any run of backticks inside the file ────────────
# A three-backtick fence is closed early by any file that itself contains one —
# and Markdown files, which this tool exists to produce, are full of them.
# CommonMark closes a fence only with a run at least as long as the opener, so
# wrapping in one backtick more than the longest run inside is always safe.
fence_for() {
    local file="$1" longest n=3
    # One awk rather than grep piped into awk: this runs once per file, and on
    # a few thousand files the extra process costs seconds. The backtick is
    # written as its octal escape \140 throughout, so the awk source contains
    # none literally and cannot unbalance the surrounding shell quoting.
    longest="$(awk '
        BEGIN { bt = "\140" }
        substr($0, 1, 1) == bt {
            i = 1
            while (substr($0, i, 1) == bt) i++
            if (i - 1 > m) m = i - 1
        }
        END { print m+0 }' "$file" 2>/dev/null)"
    (( longest >= n )) && n=$(( longest + 1 ))
    printf '%*s' "$n" '' | tr ' ' '\140'
}

# ── Build a file block as a string ───────────────────────────────────────────
build_block() {
    local file="$1"
    local relative_path="${file#$SOURCE_DIR/}"
    local lang fence
    lang="$(get_language "$file")"
    fence="$(fence_for "$file")"

    printf '%s\n' "---" "## ${relative_path}" "---" "${fence}${lang}"
    cat "$file"
    printf '\n%s\n\n' "$fence"
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

        # An unreadable file also fails the type check below, where it would be
        # reported as binary. Say what actually happened instead — permissions
        # are fixable, "binary" invites the reader to shrug. Counted apart from
        # binaries because the two mean opposite things: a binary is correctly
        # excluded, an unreadable file is source silently missing from the
        # bundle. That is what makes the run exit non-zero.
        # Already reported by the pre-flight scan; just leave it out.
        [[ -r "$file" ]] || continue

        # Binary check. Answered from the batch probe done during the scan;
        # the per-file fallback keeps -b so the file's own path is not part of
        # the matched string — a directory named e.g. "context" contains "text"
        # and would make every binary inside it look like a text file.
        if [[ "$TYPES_OK" == true ]]; then
            _is_text="${FILE_IS_TEXT["$file"]:-0}"
        elif file -b "$file" | grep -qE 'text|empty|JSON|ASCII'; then
            _is_text=1
        else
            _is_text=0
        fi
        if [[ "$_is_text" != 1 ]]; then
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

    done < <(find "$SOURCE_DIR" ${RULES_PRUNE_ARGS[@]+"${RULES_PRUNE_ARGS[@]}"} \
                  -type f -not -path "${OUTPUT_ABS}/*" -print0 | sort -z)

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
    OUTPUT_ABS="$(cd "$OUTPUT_DIR" && pwd)"

    BASE_NAME="${OUTPUT_FILE:-$FOLDER_NAME}"
    BASE_NAME="${BASE_NAME%.md}"  # strip .md if provided
    BASE_NAME="${OUTPUT_DIR}/${BASE_NAME}${SUFFIX}"

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
    (( UNREADABLE > 0 )) && echo "Unreadable: $UNREADABLE file(s) — NOT in the bundle" >&2
    (( ignored > 0 )) && echo "Ignored by mode '$MODE': $ignored file(s)"
    echo "Output folder: $OUTPUT_DIR"
    report_unused_keep_rules
    # Non-zero so a caller notices the bundle is incomplete. The bundle is
    # still written: one stray artifact should not cost you the whole run.
    # Written as an if, not `(( ... )) && exit 1`: a false arithmetic test has
    # exit status 1, and as the last statement in the block that would become
    # the script's status, failing every clean run.
    if (( UNREADABLE > 0 )); then
        exit 1
    fi
fi

# ── MODE: one .md per extension ──────────────────────────────────────────────
if [[ "$BY_EXTENSION" == true ]]; then
    OUTPUT_DIR="${FOLDER_NAME}_bundled"

    if [[ -e "$OUTPUT_DIR" ]]; then
        echo "Error: '$OUTPUT_DIR' already exists." >&2
        exit 1
    fi

    mkdir "$OUTPUT_DIR"
    OUTPUT_ABS="$(cd "$OUTPUT_DIR" && pwd)"

    echo "Output folder    : $OUTPUT_DIR"
    [[ "$MAX_SIZE_KB" -gt 0 ]] && echo "Max file size    : ${MAX_SIZE_KB}KB"
    [[ -n "$SUFFIX" ]] && echo "Suffix           : ${SUFFIX#_}"
    echo ""

    # Collect all unique extensions
    declare -A seen_exts
    total_ignored=0
    while IFS= read -r -d '' file; do
        filename="$(basename "$file")"
        # Counted here, once, rather than summed from the per-bucket passes.
        [[ -r "$file" ]] || continue
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
    done < <(find "$SOURCE_DIR" ${RULES_PRUNE_ARGS[@]+"${RULES_PRUNE_ARGS[@]}"} \
                  -type f -not -path "${OUTPUT_ABS}/*" -print0)

    total_bundled=0
    total_skipped=0

    for ext in "${!seen_exts[@]}"; do
        current_part=1
        read -r bundled skipped ignored _unused <<< "$(bundle_files "$OUTPUT_DIR/${ext}${SUFFIX}" "$ext")"

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
    (( UNREADABLE > 0 )) && echo "Unreadable: $UNREADABLE file(s) — NOT in the bundle" >&2
    (( total_ignored > 0 )) && echo "Ignored by mode '$MODE': $total_ignored file(s)"
    echo "Output folder: $OUTPUT_DIR"
    report_unused_keep_rules
    # Non-zero so a caller notices the bundle is incomplete. The bundle is
    # still written: one stray artifact should not cost you the whole run.
    # Written as an if, not `(( ... )) && exit 1`: a false arithmetic test has
    # exit status 1, and as the last statement in the block that would become
    # the script's status, failing every clean run.
    if (( UNREADABLE > 0 )); then
        exit 1
    fi
fi

exit 0
