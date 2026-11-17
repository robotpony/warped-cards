#!/bin/sh
# Builds and runs the Linux client in a window. Extra arguments go to the game.
set -eu
. "$(dirname "$0")/env.sh"
"$LINUX_APP/scripts/build.sh" debug
cd "$LINUX_APP"
exec "$GODOT" --path . -- "$@"
