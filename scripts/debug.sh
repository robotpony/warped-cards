#!/bin/sh
# Build Crib Maze Beta as it stands and run it, for review.
#   scripts/debug.sh              Debug build
#   scripts/debug.sh release      Release build (separate derived data)
#   scripts/debug.sh -- --demo    pass launch flags (stderr goes to swift/.build-app/debug.log)
# On a failed build it prints the errors and leaves the running copy alone.
set -eu
cd "$(dirname "$0")/.."

CONFIG=Debug
if [ "${1:-}" = "release" ]; then CONFIG=Release; shift; fi
[ "${1:-}" = "--" ] && shift
SCHEME=CribMazeBeta
APP="Crib Maze Beta"
DERIVED=swift/.build-app
[ "$CONFIG" = Release ] && DERIVED=swift/.build-app-release
LOG=swift/.build-app-$CONFIG.log
mkdir -p "$DERIVED"

(cd swift/App && xcodegen generate --quiet)
if ! xcodebuild -project swift/App/CribMaze.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
     -derivedDataPath "$DERIVED" -skipPackageUpdates build > "$LOG" 2>&1; then
  echo "Build failed ($CONFIG). Errors:" >&2
  grep -E "error:" "$LOG" | sort -u | head -30 >&2
  echo "Full log: $LOG" >&2
  exit 1
fi

BUNDLE="$DERIVED/Build/Products/$CONFIG/$APP.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$BUNDLE"

# Quit any running copy (Debug or Release) and wait for it to go.
PIDS=$(ps -axo pid=,command= | grep -F "$APP.app/Contents/MacOS/" | grep -v -e grep -e "--snapshot" | awk '{print $1}')
if [ -n "$PIDS" ]; then
  kill $PIDS 2>/dev/null || true
  i=0
  while [ $i -lt 50 ] && ps -p $(echo $PIDS | tr ' ' ',') >/dev/null 2>&1; do sleep 0.1; i=$((i + 1)); done
  kill -9 $PIDS 2>/dev/null || true
  sleep 0.3
fi

if [ $# -gt 0 ]; then
  open "$BUNDLE" --stderr "$PWD/$DERIVED/debug.log" --args "$@"
else
  open "$BUNDLE"
fi
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$BUNDLE/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$BUNDLE/Contents/Info.plist")
echo "Running $APP $VERSION ($BUILD), $CONFIG, from $BUNDLE"
