#!/usr/bin/env bash
set -euo pipefail

PROJECT=App_Frontend
COPIED="./copied_files_${PROJECT}"

./copy_files_new_folder.sh "./${PROJECT}"
./cleanup_copied_files.sh "$COPIED"
./bundle_files.sh "$COPIED"
