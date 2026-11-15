# /debug

Build Noddy Yookerspiel (the Crib Maze beta) as it stands and run it, for review.

Run: scripts/debug.sh [-- flags]

It regenerates the Xcode project from `swift/App/project.yml`, builds the Beta (`CribMazeBeta`, Debug) into `swift/.build-app`, quits a copy that's already running, and opens the new one. Flags after `--` go to the app, for example `scripts/debug.sh -- --demo` (the medium bot plays turns on its own) or `-- --demo --slow` (five times slower); stderr then goes to `swift/.build-app/debug.log`. On a failed build it prints the errors and leaves the running copy alone; the full log is `swift/.build-app-Debug.log`.

Report whether it built and is running, its version and build number, and what's on screen to review: the match turn on the left (drag across touching cards to score), and the side panel on the right (settings for the next turn, the last score's breakdown, this turn's feed, and animation diagnostics with slow motion).
