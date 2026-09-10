#!/usr/bin/env bash
set -euo pipefail

PROJECT=App_Backend

# One pass over the source tree: excluded directories are never descended into
# and rule-matched files are never read. Nothing is copied and nothing is
# deleted. For an inspectable intermediate folder instead, see the README.
./bundle_files.sh "./${PROJECT}" --mode backend
