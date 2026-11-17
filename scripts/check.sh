#!/bin/sh
# Format check, build and test everything this machine can build (ARCHITECTURE.md › Testing).
# Warnings fail the build. Each platform's checks run only on that platform (PORTING.md › Layout).
set -eu
cd "$(dirname "$0")/.."
echo "== JS fixtures and the spec drift check"
node --test cribbage/minigames/
echo "== Engine: build and test (engine/swift)"
(cd engine/swift && swift test --quiet)
case "$(uname -s)" in
Darwin)
  echo "== Swift format (lint only)"
  swift format lint --recursive engine/swift/Sources engine/swift/Tests apps/apple/Shared apps/apple/Beta apps/apple/Release || echo "(format notes above don't fail the check yet)"
  echo "== Apple apps (apps/apple)"
  (cd apps/apple && xcodegen generate --quiet)
  for scheme in CribMazeBeta CribMaze; do
    xcodebuild -quiet -project apps/apple/CribMaze.xcodeproj -scheme "$scheme" -configuration Debug -derivedDataPath apps/apple/.build-app build
  done
  ;;
Linux)
  # apps/linux/ (owned by @linux) adds its checks here.
  if [ -x apps/linux/scripts/check.sh ]; then apps/linux/scripts/check.sh; else echo "(no apps/linux/scripts/check.sh yet)"; fi
  ;;
esac
echo "== All checks passed"
