#!/usr/bin/env bash
set -euo pipefail

PROJECT=App_Backend
COPIED="./copied_files_${PROJECT}"

./copy_files_new_folder.sh "./${PROJECT}"
./cleanup_copied_files.sh "$COPIED" --mode backend
./bundle_files.sh "$COPIED" --by-extension --suffix backend --max-size 800
