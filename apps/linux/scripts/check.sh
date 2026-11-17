#!/bin/sh
# The Linux client's checks, run by scripts/check.sh on Linux: build the bridge, then the headless check.
set -eu
. "$(dirname "$0")/env.sh"
echo "== Linux client (apps/linux)"
"$LINUX_APP/scripts/build.sh" debug
cd "$LINUX_APP"
# A script error stops the check without quitting Godot, so give it a time limit.
timeout 120 "$GODOT" --headless --script res://tests/check.gd
