# Porting

Status: draft 1, 2026-11-16. Rules r23, app 0.15.1.

## Summary

Warped Cards SHOULD run beyond Apple platforms: Linux and Windows first, in Swift or another language. A port plays the same games from the same seeds, reads the same config, and passes the same fixtures. This doc is the porter's entry point: what's true, what to read, how to check a port, and what to watch for. It's also the rulebook for every session working on the Swift build, so the specs stay good enough to port from.

The engine can be ported today: `engine.md`, the config files and the fixtures describe it fully, and a drift check keeps the spec in step with the Swift code. The UI is less ready. Its spec, `ui.md`, is a first draft taken from the beta app.

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

The engine package (`swift/Package.swift`: GameKit, CardKit, CribbageKit, CribMaze, CribMazeBots, GameRecord, `cribmaze-sim`) imports Foundation and nothing from Apple's UI frameworks. It SHOULD build and pass `swift test` on Linux as is. Nobody has tried yet. Check these first:

- Rung 8 (`goldenRecordsWriteTheSameBytes`): Foundation's `JSONEncoder` on Linux MUST sort keys by code point, as on the Mac. Older Linux Foundation sorted differently.
- `ISO8601DateFormatter` with fractional seconds, `FileHandle`, and `CocoaError` in `GameRecord/Record.swift`.
- Every test in `swift test`, not just the build.

If the engine passes, a Swift port is a new UI over the same engine. The apps (`swift/App`) are SwiftUI and stay Apple-only.

### Another language

Build the engine from engine.md and climb the rungs in order: dice, counting, classic hands, pegging, then the records (read, scripted, verify, written). Don't read the Swift to learn the rules. When the spec is unclear, say so, fix the spec (with Bruce's say on anything that changes play), then build.

A port lives in its own top-level folder (for example `rust/` or `web/`), reads `cribbage/minigames/config/` and `cribbage/minigames/fixtures/` where they are, and MUST NOT copy them. Its language, tools and libraries get a row in [LIBRARIES.md](LIBRARIES.md) first.

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

## Keeping the spec true

For every session working on the Swift build, not just porters:

- A change to engine behaviour, an action, an event, a field or the record format MUST update engine.md in the same commit. A change to how a scene looks, plays or takes input MUST update ui.md in the same commit.
- New numbers or tables go in config, and the config section of engine.md shows the file's shape.
- New behaviour comes with a fixture a port can check, not only a Swift test. If the golden records don't reach it, add a record or a fixture case (fixtures/README.md › What the records don't reach yet).
- Specs describe behaviour in plain words. They MUST NOT lean on one language's ideas (Swift's `Codable`, optionals, protocols, JS objects). Name the data, its order and its encoding.
- `cribbage/minigames/fixtures/spec.test.js` (run by `scripts/check.sh`) fails when engine.md misses an action, an event or a field, when a config file's shape changes, or when the status line falls behind the rules version. Fix the spec, don't loosen the test.

## Status

| Part | Specced | Built in Swift | Checked by fixtures |
|---|---|---|---|
| Dice | Yes | Yes | Yes (JS and Swift) |
| Counting, classic show | Yes | Yes | Yes (JS and Swift) |
| Classic pegging and game | Yes | No | Pegging in JS only |
| Match turn, r23 | Yes | Yes | Through records |
| The game: deal, discard, hands | Yes | Yes | Through records |
| Bots, match and classic keep | Yes | Yes | Through records |
| Records | Yes | Yes | Yes (Swift) |
| Scenes, cues, layout | Draft (ui.md) | Yes (beta app) | No; by hand |
| FX catalogue (`fx.json`) | No | No | No |
| Pegging on the maze, maze walk, shop | Not designed | No | No |

## Open questions

1. Do ports share the app's version (`MARKETING_VERSION`), or keep their own and name the rules version they play?
2. Which comes first off Apple: the Swift engine with a new UI, or another language? The Linux check above decides how much work the Swift path is.
3. Should the UI's cue timings move into config (`timing.json` or `fx.json`) before a port, so a port reads them instead of copying numbers? ui.md lists the numbers that are written into code today.
