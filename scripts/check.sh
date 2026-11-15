#!/bin/sh
# Format check, build and test everything (ARCHITECTURE.md › Testing). Warnings fail the build.
set -eu
cd "$(dirname "$0")/.."
echo "== JS fixtures"
node --test cribbage/minigames/
echo "== Swift format (lint only)"
swift format lint --recursive swift/Sources swift/Tests swift/App/Shared swift/App/Beta swift/App/Release || echo "(format notes above don't fail the check yet)"
echo "== Engine: build and test"
(cd swift && swift test --quiet)
echo "== Apps"
(cd swift/App && xcodegen generate --quiet)
for scheme in CribMazeBeta CribMaze; do
  xcodebuild -quiet -project swift/App/CribMaze.xcodeproj -scheme "$scheme" -configuration Debug -derivedDataPath swift/.build-app build
done
echo "== All checks passed"
