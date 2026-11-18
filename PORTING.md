# Porting

Status: draft 2, 2026-11-17. Spec 13, rules r28, Apple build 0.22.3.

## Summary

Warped Cards SHOULD run beyond Apple platforms: Linux and Windows first, in Swift or another language. A port plays the same games from the same seeds, reads the same config, and passes the same fixtures. This doc is the porter's entry point: what's true, what to read, how to check a port, and what to watch for. It's also the rulebook for every session working on the Swift build, so the specs stay good enough to port from.

The engine can be ported today: `engine.md`, the config files and the fixtures describe it fully, and a drift check keeps the spec in step with the Swift code. The UI is less ready. Its spec, `ui.md`, is a first draft taken from the beta app.

## Layout

Decided 2026-11-16. Shared code sits under `engine/`, each platform's client under `apps/`:

```
cribbage/minigames/   the game: rules, engine.md, ui.md, config, fixtures, spec.json   shared
design/               the look: palette, shapes, cards                                shared
engine/swift/         the Swift engine package, used by every Swift client             shared
engine/<language>/    another language's engine, only if a client can't use Swift     shared
apps/apple/           the SwiftUI app for Mac and iOS                                  @apple
apps/linux/           the Linux client                                                 @linux
apps/windows/         later                                                            @windows
scripts/              checks every build uses (check.sh, the spec test)
apps/<platform>/scripts/   that platform's build, run and release scripts
```

- A client uses an engine and reads the shared data where it is. It MUST NOT copy config, fixtures or design data.
- Each `apps/<platform>/` has a `README.md` (how to set up, build and run), its own `CHANGELOG.md`, and its own build version (Versions).
- Nothing in `engine/` may depend on `apps/`.
- `engine/swift/` is linked by path from every Swift client, so it MUST keep building and passing `swift test` on Linux. It keeps the package name `CribMazeEngine` and its library names (GameKit, CardKit, CribbageKit, CribMaze, CribMazeBots, GameRecord), and imports Foundation and nothing Apple-only. Actors or async code need a `` `@linux` `` item first: Godot calls the engine from its main loop. A change to an API the clients use (`GameRun.start`, `RecordReader`, `Replayer`, `Config.load`) gets a `` `@linux` `` item in TODO.md.
- `scripts/check.sh` runs the shared checks, then the checks of whichever platform it's on. On Linux it runs `apps/linux/scripts/check.sh` if there is one.
- Who owns each folder: [AGENTS.md](AGENTS.md).

## What's true

| Area | Source of truth | When it and the code disagree |
|---|---|---|
| Player-facing rules | [rules.md](cribbage/minigames/rules.md) | rules.md wins; fix the spec and code |
| Engine behaviour, actions, events, dice | [engine.md](cribbage/minigames/engine.md) | Fix one of them in the same change |
| Record format and its encoding | engine.md › Records, and the checked-in records | The records win until the section is fixed |
| Numbers and tables | [config/*.json](cribbage/minigames/config/) | Config wins; code MUST NOT hold its own copy |
| Scenes, input, cues, layout | [ui.md](cribbage/minigames/ui.md) (draft 1) | Fix one of them in the same change |
| Look | [design/neon/](design/neon/) `palette.json`, `shapes.json` | Data wins |
| Conformance | [fixtures/README.md](cribbage/minigames/fixtures/README.md) | Fixtures win; re-record only on purpose |
| Classic cribbage wording | SCOREKEEP's `cribbage.md` | Ask SCOREKEEP |

The Swift build is the reference build, not the spec. Where the Swift code does something no doc says, that's a gap in the doc. Add the doc text; don't copy the Swift.

## Reading order

1. [rules.md](cribbage/minigames/rules.md): what the game is.
2. [engine.md](cribbage/minigames/engine.md): Ground rules, Cards, Dice, then the rest in order. Records last.
3. [fixtures/README.md](cribbage/minigames/fixtures/README.md): the rungs a port climbs.
4. [ui.md](cribbage/minigames/ui.md): scenes, input, cues, layout, Platform seams.
5. [ARCHITECTURE.md](ARCHITECTURE.md): why things are split the way they are. Its Swift details are the Apple build's choices, not requirements.

## Two ways to port

### Swift, on Linux or Windows

The engine package (`engine/swift/Package.swift`: GameKit, CardKit, CribbageKit, CribMaze, CribMazeBots, GameRecord, `cribmaze-sim`) imports Foundation and nothing from Apple's UI frameworks.

**Linux: passes, checked 2026-11-16** by `@linux` at spec 1, on Omarchy (Arch) on ARM64 with Swift 6.4.2. A clean `swift build` (warnings fail it) and all 68 tests in `swift test` pass with no code changes, including rung 8 (`goldenRecordsWriteTheSameBytes`): Linux Foundation's `JSONEncoder` sorts keys the same as the Mac's, and `ISO8601DateFormatter`, `FileHandle` and `CocoaError` in `GameRecord/Record.swift` all behave. Windows hasn't been tried.

Setting up Swift on an Arch-based Linux:

1. Install swiftly from swift.org, telling it the nearest supported platform: `swiftly init --skip-install --platform ubuntu24.04`.
2. `swiftly install --use 6.4.2`. Run it outside the repo, or delete the `.swift-version` file it writes into the folder it's run from.
3. The toolchain wants two libraries under their Ubuntu names. Install the old libxml2: `sudo pacman -S libxml2-legacy`. Link ncurses, which Arch builds only as the wide version: `sudo ln -s libncursesw.so.6 /usr/lib/libncurses.so.6` (pacman doesn't own this link). `LD_LIBRARY_PATH` isn't enough, because the build system clears it before linking.
4. lldb also wants Python 3.12 and `libedit.so.2`. It isn't needed to build or test.

Re-run the check after a Swift upgrade, and before a Linux build ships.

If the engine passes, a Swift port is a new UI over the same engine. The apps (`apps/apple`) are SwiftUI and stay Apple-only.

### Another language

Build the engine from engine.md and climb the rungs in order: dice, counting, classic hands, pegging, then the records (read, scripted, verify, written). Don't read the Swift to learn the rules. When the spec is unclear, say so, fix the spec (with Bruce's say on anything that changes play), then build.

A port's engine lives in `engine/<language>/` and its client in `apps/<platform>/` (Layout). It reads `cribbage/minigames/config/` and `cribbage/minigames/fixtures/` where they are, and MUST NOT copy them. Its language, tools and libraries get a row in [LIBRARIES.md](LIBRARIES.md) first.

## Same game, every build

Two builds given the same seed, config and actions MUST draw the same rolls and produce the same events. These are the usual ways they don't:

| Hazard | Rule |
|---|---|
| Floating point | Rules math is integers. Multipliers are whole percents. Round as the spec says at each step (half up, or half away from zero for `starts`). Compare integers, never floats: a mean is compared as a total |
| Rounding | Say the mode every time. Languages differ (Swift `rounded()` is half away from zero, JS `Math.round` is half up, Python `round` is half even) |
| Ordering | Every "in order" is the spec's order. MUST NOT depend on hash, map or set order, or on locale string comparison |
| Ties | Every search says how it breaks a tie (usually first found). Keep the search order the spec gives, or ties break differently |
| Sorting | Only sort where the spec says, by the key it says. If two items can compare equal, the spec MUST give a second key |
| Randomness | Only from the named dice streams, in the spec's draw order. No language RNG, ever |
| Big numbers | Seeds and hashes are unsigned 64-bit. Seeds travel as decimal text, never as JSON numbers |
| Time | The engine never reads a clock. Wall time (`at`, `started`) is ISO 8601 with milliseconds and an offset, and never affects play |
| JSON output | Follow engine.md › Records › Encoding, not the language's defaults: key order, left-out fields, tagged values |
| Text | UTF-8. Card notation and every value are ASCII; player-facing words come from the app, not the engine |

## Platform seams

Every place a build needs a platform's own feature sits behind an interface, with a neutral description of what any platform must provide. ui.md › Platform seams lists them. The known ones:

| Seam | Apple build | Any platform MUST provide |
|---|---|---|
| Haptics | Core Haptics | Named patterns (light tap, success) from a neutral JSON description, or nothing on desktop |
| Sound | AVAudioEngine | Low-latency playback of preloaded short sounds, on separate volume buses |
| Effects | SwiftUI, Canvas, Metal shaders | The cues in ui.md at their timings; whole-screen effects MAY be simpler |
| Files | Application Support, Finder reveal | A per-user data folder for records and the player profile |
| Input | Trackpad, mouse, touch | Tracing a set by dragging across cards, as ui.md describes |

Assets SHOULD be kept in open formats (WAV or OGG, PNG or SVG, JSON for patterns and palettes). Apple-only formats are built from them, not the other way round.

## Versions

Decided 2026-11-16. Two versions, kept apart:

| Version | What it names | Where it lives | Bumped when |
|---|---|---|---|
| Spec version, `spec 1` | The shared contract: rules.md, engine.md, ui.md, config, fixtures and the record format | `specVersion` in [spec.json](cribbage/minigames/spec.json) | A port would have to change something: an action, event, field, fixture, config shape, record encoding or scene behaviour. Wording fixes don't bump it |
| Build version, `0.15.2` | One platform's build | Each platform's own place (Apple: `MARKETING_VERSION` in `apps/apple/project.yml`) | That platform's own testing and releases, as in CLAUDE.md › Versions and tracking |

- The spec version is one whole number. It never resets.
- A rules version bump (`match-r23` to `match-r24`) always bumps the spec version too. `spec.json` names the rules version it covers, and the drift check fails if that's behind `config/rules.json`.
- The status lines of engine.md, ui.md and this doc name the spec version they describe.
- Each build MUST say which spec version it implements and how far up the fixture rungs it passes, for example `Linux 0.1.0 · spec 1 · r23 · rungs 1 to 8`. Records and the About screen show this line.
- Two builds that name the same spec version MUST play the same game from the same seed, config and actions. Their build versions can differ freely.

Who works on which platform, and how agents leave each other work: [AGENTS.md](AGENTS.md).

## Keeping the spec true

For every session working on the Swift build, not just porters:

- A change to engine behaviour, an action, an event, a field or the record format MUST update engine.md in the same commit. A change to how a scene looks, plays or takes input MUST update ui.md in the same commit.
- New numbers or tables go in config, and the config section of engine.md shows the file's shape.
- New behaviour comes with a fixture a port can check, not only a Swift test. If the golden records don't reach it, add a record or a fixture case (fixtures/README.md › What the records don't reach yet).
- Specs describe behaviour in plain words. They MUST NOT lean on one language's ideas (Swift's `Codable`, optionals, protocols, JS objects). Name the data, its order and its encoding.
- `cribbage/minigames/fixtures/spec.test.js` (run by `scripts/check.sh`) fails when engine.md misses an action, an event or a field, when a config file's shape changes, or when the status lines fall behind the rules or spec version. Fix the spec, don't loosen the test.

## Status

| Part | Specced | Built in Swift | Checked by fixtures |
|---|---|---|---|
| Dice | Yes | Yes | Yes (JS and Swift) |
| Counting, classic show | Yes | Yes | Yes (JS and Swift) |
| Classic pegging and game | Yes | The play (for duels, Apple 0.22.2); not the game | Pegging in JS and Swift |
| Match turn, r23 | Yes | Yes | Through records |
| The game: deal, discard, hands | Yes | Yes | Through records |
| Bots, match and classic keep | Yes | Yes | Through records |
| Records | Yes | Yes | Yes (Swift) |
| Scenes, cues, layout | Draft (ui.md) | Yes (beta app) | No; by hand |
| Cue motions and waits (`fx.json`) | Yes (ui.md › Motion) | Yes (Apple 0.15.5) | Shape only (spec.test.js) |
| Pegging on the maze, maze walk, shop | Not designed | No | No |

## Open questions

1. Answered 2026-11-16: each port keeps its own build version and names the spec version it implements (Versions).
2. Answered 2026-11-16: the Swift engine with a new UI. The Linux client is Godot 4.7 with the engine loaded through SwiftGodot (Bruce, after a trial build: the golden record verifies inside Godot on Linux ARM64). Known risks: a crash on a project's first import with the extension present, and the OpenGL renderer in a VM with no Vulkan.
3. Answered 2026-11-16 by Bruce: yes. The UI's cue timings move into config before the Linux UI is built, so every client reads them instead of copying numbers. Done at spec 3: `config/fx.json`, specced in ui.md › Motion.
