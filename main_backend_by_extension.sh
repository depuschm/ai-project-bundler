#!/usr/bin/env bash
set -euo pipefail

PROJECT=App_Backend

# One pass over the source tree: excluded directories are never descended into
# and rule-matched files are never read. Nothing is copied and nothing is
# deleted — the only thing written is the output folder.
./bundle_files.sh "./${PROJECT}" --mode backend --by-extension --suffix backend --max-size 800
