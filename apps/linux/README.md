# Crib Maze for Linux

Status: 0.1.0, 2026-11-16, spec 2, rules r23. Owner: `@linux` (AGENTS.md).

The Linux client: a Godot 4.7 project that runs the shared Swift engine (`engine/swift/`) through SwiftGodot. It plays the same game as the Mac from the same seed, and reads config, fixtures, the palette and the font where they live in the repo. Decided 2026-11-16 (PORTING.md › Open questions 2).

So far it's the frame: the bridge to the engine, the build, and a headless check. The scenes come next, from `cribbage/minigames/ui.md`.

## Set up

1. Swift 6.4.2 with swiftly, and the two Arch libraries: PORTING.md › Swift, on Linux or Windows.
2. Godot 4.7.2 for your machine from godotengine.org (the plain build, not .NET). Put it on PATH as `godot`, or set `GODOT` to its path.

## Build, run, check

```
apps/linux/scripts/run.sh          # build the bridge, then play in a window
apps/linux/scripts/check.sh        # build, then the headless check (scripts/check.sh runs it on Linux)
apps/linux/scripts/build.sh release
```

The check confirms the extension loads, the engine's spec and rules versions match `spec.json` and `rules.json`, config loads, every golden record verifies inside Godot, and actions go in and steps come back through the bridge.

## How it fits together

```
apps/linux/
  project.godot ......... the Godot project; config/version is the build version
  extension/ ............ Swift package: the bridge (CribEngine), linking engine/swift by path
  bin/ .................. crib_maze.gdextension, and the built libraries (not committed)
  scenes/ ............... scenes and scripts; repo.gd finds the shared data
  tests/check.gd ........ the headless check
  scripts/ .............. build, run, check
```

The bridge passes JSON in the engine's own encoding (engine.md › Records › Encoding): actions go in as engine.md writes them, and steps come back with their events. So the Godot side is written from engine.md and ui.md, never from the Swift types. The engine is called from Godot's main loop; it has no threads or async code.

## Versions

The build version is `config/version` in `project.godot`, `major.minor.patch` as in CLAUDE.md › Versions and tracking. The version hook asks for a bump when `apps/linux/` changes. The build line reads `Linux 0.1.0 · spec 2 · r23`.

## Known problems

- Godot 4.7.2 crashes when an import is the run that first registers the extension. `build.sh` imports with the extension hidden, then registers it by writing `.godot/extension_list.cfg`. Seen on Linux ARM64; not yet reported upstream.
- Swift's crash handler takes over crash reports for the whole Godot process and can crash itself. The scripts set `SWIFT_BACKTRACE=enable=no`, so Godot reports its own crashes.
- The project uses Godot's OpenGL (compatibility) renderer, which runs where Vulkan doesn't, as in a VM.
- The debug bridge library is large (about 200 MB for SwiftGodot). Release builds are smaller.
