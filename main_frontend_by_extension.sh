#!/usr/bin/env bash
set -euo pipefail

PROJECT=App_Frontend

# One pass over the source tree; the source is only ever read.
./bundle_files.sh "./${PROJECT}" --mode frontend --by-extension --suffix frontend --max-size 800
