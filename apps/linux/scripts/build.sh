#!/bin/sh
# Builds the Swift bridge and puts it where Godot loads it. Usage: build.sh [debug|release]
set -eu
. "$(dirname "$0")/env.sh"
CONFIG="${1:-debug}"
cd "$LINUX_APP/extension"
swift build -c "$CONFIG"
OUT="$(swift build -c "$CONFIG" --show-bin-path)"
cp "$OUT/libCribMazeGodot.so" "$OUT/libSwiftGodot.so" "$LINUX_APP/bin/"
cd "$LINUX_APP"
# Godot 4.7.2 crashes when an import is the run that registers this extension
# (apps/linux/README.md › Known problems). So import with the extension hidden, then register
# it by writing the one-line list Godot keeps of extensions to load.
if [ ! -f .godot/extension_list.cfg ]; then
  mv bin/crib_maze.gdextension bin/crib_maze.gdextension.off
  "$GODOT" --headless --import >/dev/null 2>&1 || { mv bin/crib_maze.gdextension.off bin/crib_maze.gdextension; exit 1; }
  mv bin/crib_maze.gdextension.off bin/crib_maze.gdextension
  echo "res://bin/crib_maze.gdextension" > .godot/extension_list.cfg
fi
