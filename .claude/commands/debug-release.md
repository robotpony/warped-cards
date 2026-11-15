# /debug-release

Build Noddy Yookerspiel (the Crib Maze beta) in Release and run it, for checking speed and animation smoothness.

Run: scripts/debug.sh release [-- flags]

Same as /debug, but builds Release into `swift/.build-app-release` (kept apart from the Debug build). The full log is `swift/.build-app-Release.log`.

Report whether it built and is running, its version and build number, and anything that differs from the Debug build.
