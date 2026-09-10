#!/usr/bin/env bash
# rules_lib.sh
# Shared reader for rules.json, sourced by every script that takes --mode.
# Kept in one place because the parser is hand-rolled and deliberately simple —
# two copies of it would drift.
#
# A ruleset is a named mode containing any of:
#   exclude_dirs  directory names; files anywhere beneath one are ignored
#   extensions    file extensions, matched case-insensitively
#   patterns      filenames matched as extended regular expressions
#   keep          exceptions; a match here wins over every rule above
#
# Every key is optional.

# ── Minimal JSON reader ───────────────────────────────────────────────────────
# Extracts the object for a given top-level key, then string arrays within it.
# Assumes the flat, one-level-deep shape documented in rules.json
# (no nested objects, no escaped quotes in values).

rules_extract_mode_block() {
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

rules_extract_array() {
    # $1 = key name, block text on stdin
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

rules_available_modes() {
    grep -oE '^\s*"[a-zA-Z0-9_-]+"\s*:\s*\{' "$1" \
        | grep -oE '"[a-zA-Z0-9_-]+"' | tr -d '"' | paste -sd, -
}

# Populates EXCLUDE_DIRS, EXTENSIONS, PATTERNS and KEEP for the given mode.
rules_load_mode() {
    local mode="$1" config="$2"

    if [[ ! -f "$config" ]]; then
        echo "Error: config file '$config' not found." >&2
        return 1
    fi

    local block
    block="$(rules_extract_mode_block "$mode" "$config")"

    if [[ -z "$block" ]]; then
        echo "Error: mode '$mode' not found in config file '$config'." >&2
        echo "       Available modes: $(rules_available_modes "$config")" >&2
        return 1
    fi

    mapfile -t EXCLUDE_DIRS < <(rules_extract_array "exclude_dirs" <<< "$block")
    mapfile -t EXTENSIONS   < <(rules_extract_array "extensions"   <<< "$block")
    mapfile -t PATTERNS     < <(rules_extract_array "patterns"     <<< "$block")
    mapfile -t KEEP         < <(rules_extract_array "keep"         <<< "$block")
}

# Builds the -prune arguments that stop find descending into excluded
# directories. Pruning beats filtering after the fact: a large node_modules or
# .git is never read at all rather than read and then discarded.
# Result is placed in the array RULES_PRUNE_ARGS.
rules_build_prune_args() {
    RULES_PRUNE_ARGS=()
    local dir first=true
    for dir in "${EXCLUDE_DIRS[@]}"; do
        [[ -z "$dir" ]] && continue
        if [[ "$first" == true ]]; then
            RULES_PRUNE_ARGS+=( '(' -type d -name "$dir" )
            first=false
        else
            RULES_PRUNE_ARGS+=( -o -type d -name "$dir" )
        fi
    done
    if [[ "$first" == false ]]; then
        RULES_PRUNE_ARGS+=( ')' -prune -o )
    fi
}

# True when the filename matches a keep rule. Records the hit so unused rules
# can be reported: this key fails dangerous, since a typo means a file the user
# believed was protected is silently dropped.
declare -A RULES_KEEP_HITS
rules_should_keep() {
    local filename="$1" rule matched=1
    for rule in "${KEEP[@]}"; do
        [[ -z "$rule" ]] && continue
        if [[ "$filename" =~ $rule ]]; then
            RULES_KEEP_HITS["$rule"]=$(( ${RULES_KEEP_HITS["$rule"]:-0} + 1 ))
            matched=0
        fi
    done
    return $matched
}

# True when a delete/ignore rule matches the filename. Sets RULES_MATCH_REASON.
rules_matches() {
    local filename="$1" ext lower rule
    RULES_MATCH_REASON=""

    lower="${filename,,}"
    for ext in "${EXTENSIONS[@]}"; do
        [[ -z "$ext" ]] && continue
        if [[ "$lower" == *."${ext,,}" ]]; then
            RULES_MATCH_REASON="extension: .$ext"
            return 0
        fi
    done

    for rule in "${PATTERNS[@]}"; do
        [[ -z "$rule" ]] && continue
        if [[ "$filename" =~ $rule ]]; then
            RULES_MATCH_REASON="pattern: $rule"
            return 0
        fi
    done

    return 1
}
