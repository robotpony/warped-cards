# Crib Maze for Apple platforms

The SwiftUI app for Mac (iOS later), in two editions: Crib Maze, the release app, and Noddy Yookerspiel, the beta with records, replay and tuning tools. It uses the Swift engine in [engine/swift/](../../engine/swift/) and reads the shared config and design data where they are. Owned by `@apple` ([AGENTS.md](../../AGENTS.md)).

## Set up

- macOS 26 or later, Xcode 26 or later.
- XcodeGen: `brew install xcodegen` ([LIBRARIES.md](../../LIBRARIES.md)).

## Build and run

From the repo root:

```
apps/apple/scripts/debug.sh                 # build Noddy Yookerspiel (Debug) and open it
apps/apple/scripts/debug.sh release         # the same, in Release
apps/apple/scripts/debug.sh -- --demo       # watch the medium bot play turn after turn
scripts/check.sh                            # every check: JS, engine tests, both apps
```

The Xcode project (`CribMaze.xcodeproj`) is generated from [project.yml](project.yml) and isn't checked in. Builds go to `apps/apple/.build-app`.

## Layout

```
project.yml    XcodeGen: both apps, the engine package, the bundled config and palette
Shared/        scenes, GameSession, effects, theme
Beta/          Noddy Yookerspiel only: records, replay, snapshots
Release/       Crib Maze's stand-ins for the beta's tools
scripts/       debug.sh (build and run), release.sh (sign, notarize, publish; RELEASING.md)
```

## Versions

The build version is `MARKETING_VERSION` in [project.yml](project.yml). Player-visible changes go in [CHANGELOG.md](CHANGELOG.md). The spec version it implements is in [spec.json](../../cribbage/minigames/spec.json) (PORTING.md › Versions).
