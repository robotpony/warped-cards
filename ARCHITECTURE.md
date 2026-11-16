# Architecture

Status: agreed, 2026-11-14. Tools and libraries are listed in [LIBRARIES.md](LIBRARIES.md).

## Summary

The first app is a Mac beta of Crib Maze, built for playing, testing and tuning. It plays the match turn from the mocks first, records every game so it can be replayed and measured, and has a lab for trying animation, sound and haptic ideas. iOS follows from the same code.

The game and the UI are separate. The rules live in a pure Swift package with no UI, no wall clock and no unseeded randomness, so the same code runs the app, the bots, the simulator and the tests. Swift replaces the Python engine we'd planned: one rules implementation, not two. The numbers and tables the rules need live in JSON config files, and the engine spec is plain Markdown, so the engine can be ported later from the spec, the config and the test fixtures. The app sends the engine a player's choice and gets back what happened; a presenter turns that into animation, sound and haptics on a timeline.

Game tracking is its own reusable component, GameRecord. It writes one file per game: a header (versions, date and time, seed, settings) and then every action, random roll and event in order. Only the beta app links it. The release app has no tracking code at all.

## Goals

1. Start with a Mac app, built so the move to iOS is mostly layout, input and haptics.
2. Keep gameplay separate from the UI: the engine MUST NOT import SwiftUI, AppKit or UIKit.
3. Track games in beta builds only, through a separate component and interface that other games can reuse. A record MUST hold the app and rules versions, the date and time, and every move and random roll, so games can be replayed and every kind of thing counted.
4. Use Swift with standard Apple tools and techniques we agree on up front, and leave room for effects, sounds and haptics from the start.

Out of scope for now: online play, accounts, sync, sending logs from release builds, and the parts of a round that aren't designed yet (pegging on the maze, the maze walk, the shop). Each gets added to the engine as its design settles.

## Layers

```
Crib Maze app (SwiftUI, Mac first, then iOS)
  Scenes ............ match turn now; deal, pegging, maze, shop later
  Presenter ......... turns engine events into cues on a timeline
  GameFX ............ plays cues: animation, sound, haptics
  Beta tools ........ records, replay, stats, animation lab, tuning   [beta app only]

GameSession (in the app)
  holds the engine state, the clock, the bots and the observers
  sends actions in, hands each step to the presenter and observers

Engine (Swift package, no UI)
  GameKit ........... game protocols, seeded dice, steps, clock time
  CardKit ........... cards, ranks, suits, decks, jokers
  CribbageKit ....... classic counting and pegging rules
  CribMaze .......... Crib Maze rules: match turn, the game and its deck, jokers, config loading
  CribMazeBots ...... bots, from random to perfect

GameRecord (Swift package target, reusable)                  [beta app only]
  writer, reader, replayer, generic counts
CribMazeStats ...... Crib Maze stats over records             [beta app, CLI]
cribmaze-sim ....... command-line simulator, replay checker, reports
```

Arrows only point down. The engine knows nothing about the app, GameRecord or GameFX. GameRecord knows GameKit's protocols but not Crib Maze. GameFX knows nothing about cards.

## How a move flows

```
Player traces a set
  > Scene sends an intent to GameSession
  > GameSession stamps it with the clock time and the player
  > Engine applies the action, drawing from the dice as needed
  > Engine returns a step: the action, the rolls it drew, the events
  > GameSession hands the step to every observer (the recorder, in beta)
  > Presenter turns the events into cues: breakdown, flights, sounds
  > Scene shows the presented state as the cues play
```

The engine's state is always the truth and is always current. The scene shows a presented state that lags behind it while cues play, so a score breakdown can take three seconds without the rules waiting on it. Input during cues follows each scene's rules: the match turn lets the player skip the breakdown, and queues nothing else behind it.

Bots use the same path. A bot picks an action from its view of the game, and GameSession sends it in like a player's.

## Engine

### Core protocol

Each game implements one protocol from GameKit. Classic cribbage and Crib Maze share it, so the simulator can run either.

```swift
public protocol GameRules {
    associatedtype Config: Codable & Sendable   // rules options, tuning values
    associatedtype State: Sendable              // everything, hidden cards included
    associatedtype Action: Codable & Sendable   // a choice by a player, or the session
    associatedtype Event: Codable & Sendable    // something that happened
    associatedtype Result: Codable & Sendable   // how a finished game came out

    static var gameID: String { get }           // "crib-maze"
    static var rulesVersion: String { get }     // "match-r23"

    static func start(_ config: Config, players: [PlayerSeat], dice: inout Dice) -> (State, [Event])
    static func apply(_ action: Action, by player: PlayerID?, to state: inout State, dice: inout Dice) throws -> [Event]
    static func hand(of state: State) -> Int?       // the hand (round, stage) the game is in
    static func result(of state: State) -> Result?  // nil until the game is over
}
```

Built in phase C (0.15.0). `legalActions` and `view` come when the bots and the presenter move onto the protocol; the bots still take a `MatchTurn`. `State` isn't `Codable` yet: nothing stores it, since resume replays the actions. `player` is nil for the session's own actions (`timeUp`, `reachOver`, a stuck board's `endTurn`).

A step is the unit everything else consumes:

```swift
public struct Step<G: GameRules>: Codable, Sendable {
    public let seq: Int            // 1 is the opening step
    public let hand: Int?          // the hand the game is in after this step
    public let clockMs: Int        // game time, from GameSession's clock
    public let player: PlayerID?
    public let action: G.Action?   // nil for the opening step
    public let rolls: [Roll]       // every random draw, in order
    public let events: [G.Event]
}
```

`GameRun<G>` in GameKit holds a game's state and dice and turns each action into a step: it numbers the steps, keeps only the rolls the action drew, and leaves the state as it was when an action is illegal. The beta, the simulator and the replayer all play through it.

Crib Maze plays as `CribMazeGame`, a game of hands (`engine.md` › The game as steps). Each hand is a deal and a match turn now; pegging and the maze join the same hand as they're built, so a record holds 5 to 13 hands without a format change.

### Rules for the engine

These keep the engine deterministic, so a seed and a list of actions always give the same game.

- The engine MUST get all randomness from `Dice`. `SystemRandomNumberGenerator`, `Int.random`, `shuffled()` without a generator and `UUID()` MUST NOT appear in engine code.
- The engine MUST NOT read the wall clock. Time arrives on the action, stamped by GameSession.
- Rules MUST NOT depend on `Dictionary` or `Set` order, which Swift changes from run to run. Sort first, or use arrays.
- Rules SHOULD use integers. Chances are stored as whole weights (90, 9, 1), not as fractions.
- State and actions are value types. `apply` is the only way state changes.
- A test greps the engine sources for the banned calls above, so a slip fails the build.

### Dice

`Dice` holds named streams, each a seeded generator (SplitMix64 to seed, xoshiro256** to draw) derived from the game's seed. The exact algorithm and draw order are in [engine.md](cribbage/minigames/engine.md) › Dice.

| Stream | Draws |
|---|---|
| `deal` | Shuffles, cuts, how many jokers a round has |
| `reveal` | Joker and extra-card outcomes, what a made card becomes |
| `board` | Where a special joker lands in the stock |
| `prize` | The special joker a turn's best score wins |
| `bot.<seat>` | A bot's own choices, one stream per seat |

Separate streams keep things apart: a bot that thinks differently MUST NOT change the next deal, and a new joker kind MUST NOT shift every shuffle after it. Every draw produces a `Roll` (stream, purpose, range, value) that lands in the step, so the record holds every roll. `Dice` can also run scripted, handing back recorded rolls in order; that is how a replay survives a change to the generator.

### Clock and timers

GameSession owns the clock. In the app it counts real time, paused while a score breakdown plays (as the rules say); in the simulator it is a modelled clock that adds each action's duration from a timing profile (`stats.md` › Timing). The match turn timer running out is an action (`timeUp`), sent by GameSession and recorded like any other, so replays don't need the clock.

### Bots

```swift
public protocol Bot: Sendable {
    var level: BotLevel { get }   // random, then a gradient up to perfect
    func choose(_ view: PlayerView<CribMaze>, legal: [CribMaze.Action], dice: inout Dice) async -> CribMaze.Action
}
```

Bots see only a player's view, never the whole state, so they can't cheat on hidden cards. They run off the main actor, so a perfect bot searching the board doesn't freeze the UI. Bots are game features: their levels, names and pacing live in CribMazeBots and ship in the release app.

### Config files

Code holds behaviour; config holds data. Any number, table or list the game needs MUST live in a config file, not in Swift source. Config is JSON, so the JS mocks, the Swift engine, scripts and a future port can all read the same files.

| File | Holds |
|---|---|
| `rules.json` | Timer, card budget, set size, left-over cost, clear-board bonus, prize tiers |
| `jokers.json` | Joker kinds, how many a round can have, each kind's hidden chance table (as whole weights), special joker supplies |
| `bots.json` | Bot levels and their limits (starting cards, search depth; classic discard and play styles), names, on-screen pacing |
| `classic.json` | The classic game: target, deal table, cut, show and pegging values, its own copy of the scoring |
| `timing.json` | Timing profiles for the modelled clock: human speed and bot speed, per action (`stats.md` › Timing) |
| `fx.json` | The FX catalogue: what each cue looks, sounds and feels like (see Presentation) |

- Files live in `cribbage/minigames/config/`, next to the specs, and are bundled into the app. The mocks SHOULD move their constants into the same files as they're touched.
- Each file carries its own `version`. The engine loads config into `CribMaze.Config` (a `Codable` struct) and checks it on load: weights add up, ranges hold, every referenced kind exists. A bad file MUST fail loudly in beta and tests, never quietly fall back.
- The release app bundles one set. The beta app can edit the rules, jokers and bots files live, like the mock's game-maker panels, and save a copy; "Export" writes it back to the repo for review.
- Every record stores the full config it ran with, so stats never mix two configs by accident.

### Written to port

The engine spec (PLAN.md Phase 4, in `cribbage/minigames/engine.md`) describes the data model, actions, events, dice streams and their order of draws, and the config schemas in plain language. It MUST NOT lean on Swift-only ideas. Together with the config files and the shared fixtures, it is enough to build the engine again in another language and check it against the same records. The Swift code follows the spec; when they disagree, fix one in the same change. How to port, and the rules that keep the specs portable: [PORTING.md](PORTING.md).

## GameRecord: tracking, replay and counts

GameRecord is generic over any `GameRules`, so another card game can use it unchanged.

### Interface

GameKit defines the hook; GameRecord implements it. The release app never imports GameRecord.

```swift
// GameKit
public protocol StepObserver<G>: AnyObject {
    associatedtype G: GameRules
    func gameStarted(_ header: GameHeader<G>)
    func record(_ step: Step<G>)
    func gameEnded(_ result: GameResult)
}

// GameRecord
public final class RecordWriter<G: GameRules>: StepObserver { ... }   // writes JSON Lines
public enum RecordReader<G: GameRules> { ... }                         // reads one file or a folder
public struct Replayer<G: GameRules> { ... }                           // verify, scripted, step through
public struct Counts { ... }                                           // events by type, rolls by purpose
```

`gameEnded` takes the game's own `G.Result`. GameRecord never reads the clock: the writer is handed one, so tests write byte-identical records. In the app, GameSession doesn't name GameRecord: it hands steps to a small `GameRecorder` the beta target provides (`App/Beta/Recording.swift`) and the release target leaves out. The beta holds a game's first steps back until the player makes a choice, so the game the app opens on launch leaves no file.

### File format

The exact format, field by field and byte by byte, is `engine.md` › Records; the sketch below is the design as first agreed. One JSON Lines file per game, written as the game is played and flushed after every step, so a crash keeps everything up to the last move. The first line is the header; every line after is a step.

```
{"kind":"header","format":1,"game":"crib-maze","rules":"match-r14",
 "app":"0.4.0","build":57,"commit":"03155ff","platform":"macOS 26.6",
 "started":"2026-11-14T19:02:03.120-08:00","install":"r-7f3c...",
 "seed":"9c41e2...","config":{...},"players":[{"seat":0,"kind":"human"},{"seat":1,"kind":"bot","level":"medium"}]}
{"kind":"step","seq":1,"at":"2026-11-14T19:02:03.400-08:00","clock_ms":0,"player":null,
 "rolls":[{"stream":"deal","purpose":"shuffle","range":[0,51],"value":17}, ...],
 "events":[{"turn_start":{...}}]}
{"kind":"step","seq":2,"at":"...","clock_ms":24100,"player":0,
 "action":{"trace":{"cards":["6H","4S","5S","6S","5H"]}},"rolls":[],
 "events":[{"score":{...}},{"prize_won":{...}}]}
{"kind":"end","at":"...","clock_ms":91000,"result":{...}}
```

- `at` is the wall time on the player's Mac, with its offset; `clock_ms` is game time.
- `install` is a random ID made on first launch. Records MUST NOT hold names, contacts or device identifiers (`stats.md` › App telemetry).
- Event names follow the tables in `stats.md` › Event log, so records and the mocks' logs read the same way.
- Files live in the beta app's container, under `Records/<YYYY-MM-DD>/<time>-<game>.jsonl`. The beta app can reveal them in Finder or export a set into `playtests/`.

As built (format 1, 0.15.0):

- Keys are camelCase, as the Swift types and `engine.md`'s field names are: `clockMs`, `{"turnStart": …}`. Event names match `stats.md` › Event log by meaning, not by case. JSON keys are sorted, so the same game writes the same bytes; `kind` isn't first on the line.
- The seed is decimal text (`"seed":"12345"`), the number the beta shows, since JSON numbers lose precision past 2^53.
- A roll is `{"stream","purpose","n","value"}`, a draw below n, as `engine.md` › Dice reports it.
- The header's `config` is the config files as the game ran them, plus `firstDealer`. Each hand's own settings (deal on or off, fixed cards, card budget, timer) ride on its `startHand` action, since the beta's settings can change between hands.
- `{"kind":"note","after":<seq>,"name":…,"data":…}` lines hold app behaviour that isn't an action, such as the deal's hint (`deal_hint`). Replays skip them.
- A record without an end line is a game that was left, or is still going. A last line cut short by a crash is dropped and the rest is kept.
- The beta writes under Application Support/Noddy Yookerspiel/Records. Its old per-turn records (`match-….json`, 0.8.0 to 0.14.0) stay in the same folder, untouched: they lack the config and each action's own events, so they can't be replayed, and GameRecord doesn't read them.
- `cribmaze-sim record` writes bot games in the same format; the golden replays in `cribbage/minigames/fixtures/records/` are made with it.

### Replay

| Mode | How | Used for |
|---|---|---|
| Verify | Start from the seed, apply the recorded actions, compare every roll and event | Tests and CI; catching engine changes that alter old games |
| Scripted | Feed the recorded rolls back instead of drawing new ones | Replaying old games after the generator or a stream changes |
| Watch | Run either mode through the presenter, step by step or at speed | Reviewing a playtest in the beta app |

A record from another rules version MAY still replay in scripted mode, but stats MUST NOT pool records across rules versions (`stats.md` › Mock playtests).

`cribmaze-sim replay <file or folder>... [--scripted] [--counts]` checks records from the command line and exits 1 if any differ; it says which step and which roll or event, and notes a record made under other rules. In scripted mode `Dice` hands back the recorded rolls and, at the first one out of step, says where and carries on from the seed, so the replay reports it instead of stopping. Each Crib Maze hand starts its dice again from the hand's seed (`Dice.reseed`); scripted dice carry on through their script.

### Stats

GameRecord counts what any game has: events by type, rolls by stream and purpose (so the beta app can check that amber jokers really land 90, 9, 1), time between actions. CribMazeStats adds Crib Maze's own: steps per turn, singles and multis, combos, left-over costs, suits and ties, clear-board rate, prizes by tier, bot against person. Both run in the beta app's dashboard and in `cribmaze-sim report`.

## Presentation and effects

### Presenter and cues

The presenter is the only part of the app that knows how events should look. It turns each step's events into a cue sheet: an ordered list of cues, each with a start, a duration and whether it can be skipped.

```
Score event, a multi with three combos
  0 ms ...... cue match.set.lock          cards pulse, tick sound, light haptic
  120 ms .... cue match.combo × 3         each combo's cards glow, points count up
  900 ms .... cue match.total             total and suit badge, chime by size
  1400 ms ... cue match.steps.fly         steps fly to the counter
  skip ...... jumps to the end state, plays only the last cue's sound
```

A cue is data: an ID (`match.combo`), its parameters (cards, points, suit) and its timing. What a cue looks, sounds and feels like comes from the FX catalogue (`config/fx.json`, bundled into the app), which maps cue IDs to animation presets, sound files and haptic patterns. Tuning an effect means editing the catalogue, not the presenter.

Speed comes from three settings that multiply: the player's base speed (which quickens as they learn, per the concept doc), a global speed for testing, and skip. Reduce Motion swaps movement for short fades but keeps the order and the sounds.

### GameFX

GameFX plays cues and knows nothing about cards. It has three players behind protocols, so each platform can supply its own:

| Player | Mac | iOS |
|---|---|---|
| Animation | SwiftUI animations, keyframes and phase animators; matched geometry for cards moving between zones; Canvas with TimelineView for particles; Metal shader effects for glows and shimmers | Same |
| Sound | AVAudioEngine with preloaded buffers, a pool of players, and buses for effects, UI and music, each with its own volume | Same, plus the audio session (respect the silent switch for effects) |
| Haptics | Trackpad feedback where it exists (three patterns only); the beta app also flashes a small marker when a haptic fires, so haptics can be tuned without a phone | Core Haptics with AHAP pattern files |

Sound and haptics MUST each have an off switch. Effects MUST NOT carry game information that isn't also on screen, so a muted player loses nothing.

### Effect requirements

SwiftUI is the effects stack if it meets these. Each one gets proven in a spike at the start of Phase E, on the development Mac, before scenes are built on it; the iPhone check follows in Phase H.

| Need | Examples | SwiftUI approach |
|---|---|---|
| Minor particles | Sparks on a big multi, dust as cards land, confetti on a cleared board | Canvas in a TimelineView, drawing a few hundred particles from a small particle model in GameFX |
| The mocks' animations | Cards falling into place, flights between board, tray and counter, combo glow, points counting up, the joker shuffle, wheel and die, skip to the end | Animations with keyframes and phase animators, matched geometry for flights, numeric text transitions, 3D rotation for flips and the wheel |
| Effects on the whole output | Pixelate in or out, bounce, stretch, shake, ripple, a colour flash | Metal shaders through SwiftUI's layer, distortion and colour effects, applied to the scene's root view, plus scale and offset keyframes on the root for bounce and shake |

Each requirement passes when:

- It runs at the display's full frame rate (60 fps, 120 on ProMotion) with the match board on screen, measured in Instruments.
- It can be triggered as a cue, tuned in the animation lab and skipped.
- It respects Reduce Motion (a whole-screen effect becomes a short fade or nothing).

Known limits to plan around:

- Shader effects rasterize the view, and views backed by AppKit or UIKit (text fields, scroll views, some controls) don't render inside them. The board and anything a whole-screen effect covers MUST be plain SwiftUI views; beta panels sit outside the effected area.
- A layer effect that samples neighbouring pixels (pixelate, ripple) has to declare how far it reaches, or edges clip.

If particles miss the frame rate, a SpriteKit view for particles only goes on top of the board; the other two needs stay in SwiftUI. If a whole-screen effect can't be done this way, we look again before adding anything.

### Animation lab (beta)

A beta window that plays any cue, or any cue sheet from a record, on a test board. It has sliders for duration, delay, curve and scale, sound and haptic pickers, and a speed control. Changes apply live and save to a catalogue override; "Export" writes the catalogue to the repo, and that file becomes the bundled one after review. New effect ideas start here as new cue IDs.

## App

### Targets and builds

| Target | Bundle ID | Links | For |
|---|---|---|---|
| Noddy Yookerspiel (the beta) | `ca.robotpony.cribmaze.beta` | Engine, GameFX, GameRecord, CribMazeStats, beta tools | Bruce and testers: play, record, replay, tune |
| Crib Maze | `ca.robotpony.cribmaze` | Engine, GameFX | Players |

Two targets, not one target with a flag: a release build can't reach tracking code by mistake, because it isn't linked. The targets share every scene; the beta target adds its tools and wires a `RecordWriter` into GameSession at its one composition root. They install side by side with different bundle IDs. Both start as Mac apps, on macOS 26; the iOS destinations, on iOS 26, get added to the same targets later.

The beta is shared as local builds on the Mac for now. When the iOS destination arrives, TestFlight becomes the way to share it with testers.

### Mac first, iOS later

- Shared code is SwiftUI only. AppKit and UIKit appear only in small platform adapters (haptics, file export, window setup).
- The Mac window holds the board at phone proportions, with the beta panels beside it as tabs, like the mocks.
- Tracing works with a mouse or trackpad drag, using the same "near the centre" hit test as the mock (70% by default, a setting).
- Card size, layout and touch targets get tuned when the iOS destination is added; scenes SHOULD lay out from the board size, not from fixed points.

### State and concurrency

- Swift 6 language mode with complete concurrency checking. Warnings fail the build, as in Scorekeep.
- GameSession is `@MainActor @Observable`; scenes read it directly.
- Engine types are `Sendable` value types. Bots and the simulator run them off the main actor.

### Saving and resuming

The release app saves a game in progress as its seed, config and actions, the same data a record holds, and resumes by replaying them. That reuses the replay path without linking GameRecord: GameKit holds the small resume format, GameRecord holds the full record. Resume is not needed for the first beta.

## Versions

| Version | Where | Example |
|---|---|---|
| App version | `CHANGELOG.md` top heading, kept in step with `MARKETING_VERSION` in `project.yml` | 0.4.0 |
| Build | Git commit count, stamped at build time (as Scorekeep does) | 57 |
| Commit | Short git hash, stamped into Info.plist | 03155ff |
| Rules version | `CribMaze.rulesVersion`, the same numbering as the mock's `RULES` | match-r14 |
| Record format | `GameRecord.formatVersion` | 1 |

All five go in every record header. A change to match turn rules bumps the rules version in the engine and the mock together, and adds a line to `mocks/README.md` › rules versions.

## Testing

- Swift Testing for all tests.
- Scoring and rules fixtures are JSON files in `cribbage/minigames/fixtures/`. The JS mock tests and the Swift tests read the same files, so the mocks and the engine can't drift apart quietly.
- Determinism: the same seed and actions twice MUST give byte-identical records (ignoring `at`).
- Golden replays: a few recorded games live in the test fixtures and MUST verify on every build. When a rules change breaks one on purpose, re-record it and say so in the commit.
- Soak: random bots play 10,000 games per run in `cribmaze-sim` without an error or an illegal action.
- UI is checked by hand in the beta app for now; snapshot tests can come later if layouts start breaking.

## Repo layout

```
swift/
  Package.swift ............ engine, GameRecord, GameFX, stats, CLI
  Sources/
    GameKit/  CardKit/  CribbageKit/  CribMaze/  CribMazeBots/
    GameRecord/  CribMazeStats/  GameFX/  cribmaze-sim/
  Tests/ ................... one test target per module
  App/
    project.yml ............ XcodeGen: Crib Maze, Noddy Yookerspiel
    Shared/ ................ scenes, presenter, GameSession
    Beta/ .................. records, replay, stats, animation lab, tuning
    Resources/ ............. sounds, haptic patterns, card art
cribbage/minigames/
  engine.md ................ engine spec, written to port
  config/ .................. rules, jokers, bots, timing, fx (JSON)
  fixtures/ ................ shared test fixtures (mocks and Swift)
```

One package with many targets keeps builds and versions simple. A module moves into its own package only when another repo needs it.

## Build plan

Each phase ends with something that runs. Phases A to D are engine work and can start now; E onward needs the match turn rules to hold still long enough to build against.

| Phase | What | Done when |
|---|---|---|
| A · Foundations | `swift/` package and XcodeGen project with both targets, version stamping, `scripts/check.sh` (format, build, test), the banned-calls test | Both apps launch to an empty window showing their versions |
| B · Cards and counting | Engine spec first draft; GameKit (protocol, Dice, Step), CardKit, CribbageKit counting written fresh; port `scoring.test.js` to shared fixtures; config loading and checks | Swift and JS pass the same fixtures |
| C · Records | Done in 0.15.0 (2026-11-16). GameRecord writer, reader, replayer, counts; `cribmaze-sim replay` and `record`; the beta writes through it | A toy game records, verifies and replays in scripted mode |
| D · Match turn engine | CribMaze match turn at the rules of the time (r15; r23 now), jokers and reveals, special jokers, config; bots at every level; `cribmaze-sim run` and `report` | 10,000 bot turns run clean; bot numbers match the mock's within noise |
| E · Mac beta, playable | Effects spike (`Effect requirements`), then the match turn scene, GameSession, presenter, basic GameFX (breakdown, joker reveal, sounds), recording on | Bruce plays a match turn and finds its record |
| F · Beta tools | Records browser, replay viewer, stats dashboard (Swift Charts), animation lab, tuning panel | A playtest can be replayed, graphed and its effects retuned without code |
| G · The rest of a round | Deal and discard, cut, pegging, maze walk, shop, transitions, each as its design settles | A full game plays until a player exits the maze |
| H · iOS | iOS destinations, touch input, Core Haptics, layout and card size for phones | The beta runs on an iPhone |
| I · Release | Release target polish, resume, App Store setup | Not scheduled |

## Decisions

| Date | Decision |
|---|---|
| 2026-11-14 | The first app is a Mac beta for playing, testing and tuning; iOS follows from the same code |
| 2026-11-14 | Gameplay lives in a Swift package with no UI; the app talks to it only through actions and steps |
| 2026-11-14 | Game tracking is a separate, reusable component (GameRecord), linked only into the beta app; records hold versions, date and time, every action, roll and event |
| 2026-11-14 | Tools and libraries are agreed up front and listed in LIBRARIES.md; anything new needs an entry there first |
| 2026-11-14 | The Swift engine replaces the planned Python engine; the simulator is a Swift command-line tool |
| 2026-11-14 | Engine specs are written to port, and every number and table the code needs lives in JSON config files |
| 2026-11-14 | Beta and release are two app targets, not one target with a flag |
| 2026-11-14 | Effects use SwiftUI, Canvas and Metal shaders if they meet the effect requirements (particles, the mocks' animations, whole-screen effects such as pixelate, bounce and stretch); SpriteKit only if particles need it |
| 2026-11-14 | Testers don't share records; each beta keeps its own. Revisit later |
| 2026-11-14 | Release builds don't send logs |
| 2026-11-14 | Release builds don't record or send logs for now, replacing the opt-in sending in `stats.md` › App telemetry until it's revisited |
| 2026-11-14 | Apple frameworks only; Apple's own packages when needed; anything else needs a LIBRARIES.md row first |
| 2026-11-14 | Swift Testing for all tests; macOS 26 and iOS 26 minimum |
| 2026-11-14 | The beta is local Mac builds; TestFlight comes with iOS |
| 2026-11-14 | Classic counting is written fresh for this game, against shared fixtures. ScorekeepCore's `Cribbage.swift` MAY be read where it helps; we compare notes as the engine grows |
| 2026-11-16 | A record is one game of hands, not one match turn; each step carries its hand. Each hand's settings ride on its `startHand` action |
| 2026-11-16 | Old per-turn beta records (before 0.15.0) are left as they are, not converted: they can't be replayed |

## Card counting: why fresh

Crib Maze counts more than a cribbage hand. A set is up to 5 cards traced on a grid, every card must belong to a combo or cost steps, combos light up card by card while tracing, sets carry a suit (or none on a tie), and bots search the board for sets. So the counter needs to report which cards each combo uses, not just a total, and it has to be fast enough for a perfect bot to check every path. Classic hands and pegging still need to score exactly as classic cribbage does, per SCOREKEEP's rules doc.

The plan: write CribbageKit from the engine spec, with combos as first-class results (kind, cards, points). The shared fixtures check it, starting with every case in `scoring.test.js` plus classic hands with known counts (29, 28, 24, 0, his nobs, flush rules for hand and crib). When the fixtures pass, run ScorekeepCore's counting over the same classic hands as a cross-check. If Scorekeep's code turns out to do the classic part well, we'll talk about sharing it then.

## Open questions

1. Does SwiftUI meet the effect requirements? The Phase E spike answers it.

## Later ideas

- Sending game parameters from release builds. Because every shuffle and roll is seeded, a game can be rebuilt from its seed, config and actions, so a release build could send just those instead of a full log: small, and with nothing personal in it. Not planned; it would need its own decision and the opt-in rules in `stats.md` › App telemetry.
- Sharing or merging records between testers.
