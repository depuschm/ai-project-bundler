#!/usr/bin/env bash
set -euo pipefail

PROJECT=App_Backend

# One pass over the source tree; the source is only ever read.
./bundle_files.sh "./${PROJECT}" --mode backend --by-extension --suffix backend --max-size 800
