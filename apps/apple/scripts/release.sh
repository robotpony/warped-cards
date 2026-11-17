#!/bin/sh
# Build, sign, notarize and publish Crib Maze for Mac (RELEASING.md).
#   apps/apple/scripts/release.sh build     archive, sign with Developer ID, notarize, staple, zip (local only)
#   apps/apple/scripts/release.sh publish   tag the version and post the zip to GitHub releases (public)
# Notarizing needs a keychain profile (default warped-cards-notary, or set NOTARY_PROFILE):
#   xcrun notarytool store-credentials warped-cards-notary --apple-id <id> --team-id 7J49PFSP65
set -eu
cd "$(dirname "$0")/../../.."

SCHEME=CribMaze
APP="Crib Maze"
TEAM=7J49PFSP65
PROFILE=${NOTARY_PROFILE:-warped-cards-notary}
# Outside engine/swift/: an archive whose build folder sits inside the package folder fails to resolve modules.
OUT="$PWD/.build-release"   # absolute: a relative build folder also breaks module resolution in archives
VERSION=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' apps/apple/project.yml)
ZIP="$OUT/Crib-Maze-$VERSION-mac.zip"
NOTES="$OUT/notes-$VERSION.md"
fail() { echo "release: $*" >&2; exit 1; }

# The changelog's top heading names this version, and its section becomes the release notes.
TOP=$(sed -n 's/^## \([0-9][0-9.]*\) — .*/\1/p' apps/apple/CHANGELOG.md | head -1)
[ "$TOP" = "$VERSION" ] || fail "CHANGELOG.md's top version is $TOP but project.yml says $VERSION"

notes() {
  mkdir -p "$OUT"
  # Every release page starts with what the game is (apps/apple/scripts/release-intro.md), then this version's changes.
  { cat apps/apple/scripts/release-intro.md; printf '\n## What'"'"'s new in %s\n' "$VERSION"; } > "$NOTES"
  awk -v v="$VERSION" '$0 ~ "^## "v" " {on=1; next} on && /^## / {exit} on {print}' apps/apple/CHANGELOG.md >> "$NOTES"
  printf '\n---\nA free demo for macOS 26 or later. Unzip and drag Crib Maze to Applications. Every version: [CHANGELOG.md](https://github.com/robotpony/warped-cards/blob/main/apps/apple/CHANGELOG.md)\n' >> "$NOTES"
}

case "${1:-}" in
build)
  [ -z "$(git status --porcelain)" ] || fail "commit or stash changes first, so the build matches a commit"
  rm -rf "$OUT"; mkdir -p "$OUT"
  (cd apps/apple && xcodegen generate --quiet)
  echo "== Archive $APP $VERSION"
  xcodebuild -quiet -project apps/apple/CribMaze.xcodeproj -scheme "$SCHEME" -configuration Release \
    -archivePath "$OUT/CribMaze.xcarchive" -derivedDataPath "$OUT/derived" archive
  cat > "$OUT/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
</dict></plist>
PLIST
  echo "== Export with Developer ID"
  xcodebuild -quiet -exportArchive -archivePath "$OUT/CribMaze.xcarchive" -exportOptionsPlist "$OUT/export.plist" -exportPath "$OUT/export"
  BUNDLE="$OUT/export/$APP.app"
  codesign --verify --deep --strict "$BUNDLE"
  codesign -dv "$BUNDLE" 2>&1 | grep -E "Authority=Developer ID|TeamIdentifier|Runtime" || fail "not signed with Developer ID and hardened runtime"
  echo "== Notarize (profile $PROFILE)"
  xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
    || fail "no notary profile $PROFILE; see RELEASING.md › One-time setup. The signed app is in $OUT/export"
  ditto -c -k --keepParent "$BUNDLE" "$OUT/upload.zip"
  xcrun notarytool submit "$OUT/upload.zip" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$BUNDLE"
  spctl -a -vv -t exec "$BUNDLE"
  ditto -c -k --keepParent "$BUNDLE" "$ZIP"
  notes
  git rev-parse HEAD > "$OUT/commit"   # publish tags the commit that was built, not whatever is checked out later
  echo "== Ready: $ZIP"
  echo "Release notes: $NOTES. Try the app, then run: apps/apple/scripts/release.sh publish"
  ;;
publish)
  [ -f "$ZIP" ] || fail "no $ZIP; run apps/apple/scripts/release.sh build first"
  [ "$(git branch --show-current)" = main ] || fail "publish from main"
  git merge-base --is-ancestor "$(cat "$OUT/commit")" HEAD || fail "the built commit isn't on main"
  TAG="v$VERSION"
  BUILT=$(cat "$OUT/commit")
  git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && fail "tag $TAG already exists"
  notes
  git tag -a "$TAG" "$BUILT" -m "Crib Maze $VERSION"
  git push origin main "$TAG"
  gh release create "$TAG" "$ZIP" --title "Crib Maze $VERSION" --notes-file "$NOTES" --prerelease
  echo "== Published $TAG"
  ;;
*) echo "usage: apps/apple/scripts/release.sh build | publish" >&2; exit 2 ;;
esac
