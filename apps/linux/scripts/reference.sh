#!/bin/sh
# Shoots the Linux build's match turn as docs/images/reference/ shoots the Mac's, same seed and
# flags, to compare side by side. Usage: reference.sh [out folder] (default: a temp folder).
# Runs under X11 so the window gets the exact size asked for (a tiling Wayland compositor may not).
set -eu
. "$(dirname "$0")/env.sh"
OUT="${1:-$(mktemp -d)}"
mkdir -p "$OUT"
"$LINUX_APP/scripts/build.sh" debug
cd "$LINUX_APP"
shoot() {
  name="$1"; shift
  "$GODOT" --display-driver x11 --path . -- --seed 1 --shot "$OUT/$name.png" "$@" >/dev/null 2>&1
  echo "$OUT/$name.png"
}
shoot turn
shoot turn-toast --toast
shoot trace --select g00,g01
shoot trace-combo --select g02,g03
shoot armed-bomb --arm bomb
shoot pop --pop g02,g03 --no-breakdown
shoot pop-bomb --pop g00 --bomb
shoot warning --trace g02,g03,g13
for t in hand crib starter tray counter; do shoot "info-$t" --info "$t"; done
shoot summary --end --after 1500
for n in 1 2 3 4 5 6 7 8 9; do shoot "breakdown-$n" --breakdown g32,g33,c3,h2 --stage "$n" --after 500; done
shoot breakdown-hold --breakdown g32,g33,c3,h2 --after 300
