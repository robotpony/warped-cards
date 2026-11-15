# Warped Cards

Free card game demos, with the specs, simulations and tests behind them. Each game is 1 player against 1 or 2 bots, on one standard 52-card deck.

## Games

| Game | What it is | Status |
|---|---|---|
| Crib Maze | Cribbage where your points walk you through a maze instead of up a pegboard. Between pegging rounds, match turns score sets traced across a 4 × 4 grid of cards | Mac beta 0.8.3 (match turns only), match rules r17, rules draft 5 |
| Classic cribbage | The classic game, sharing Crib Maze's engine | Engine spec and fixtures; no app yet |

## Downloads

The demos are free. Released builds will be posted on the GitHub releases page:

**https://github.com/robotpony/warped-cards/releases**

Nothing is released yet; [RELEASING.md](RELEASING.md) covers how builds get there (signed and notarized by Apple). Until then:

- **Mac:** build Crib Maze Beta yourself (see Build and play).
- **iPhone and iPad:** testers will get the beta through TestFlight once the iOS version is ready.

## Build and play

You need macOS 26, Xcode 27 (Swift 6.4) and XcodeGen (`brew install xcodegen`).

```sh
scripts/debug.sh                 # build Crib Maze Beta (Debug) and open it
scripts/debug.sh release         # the same, in Release
scripts/debug.sh -- --demo       # watch the medium bot play turn after turn
scripts/debug.sh -- --demo --slow
```

In Claude Code, `/debug` and `/debug-release` run the same script.

How to play a match turn: drag across 2 to 4 touching cards and let go. Every card you pick should be part of a combo (fifteens, pairs, runs, flushes, his nobs). The starter counts with every set for free. Tap the HAND, CRIB, STARTER or POWER JOKERS tag, or the card counter, to read what each one does. The gear in the top line opens the settings. The full rules are in [rules.md](cribbage/minigames/rules.md).

The beta saves each finished turn as a JSON record in `~/Library/Application Support/Crib Maze Beta/records/`. It sends nothing anywhere, and release builds don't record at all.

### Simulator

`cribmaze-sim` plays match turns with a bot and reports steps, prizes, the best set and how much comes from edge power:

```sh
cd swift
swift build -c release --product cribmaze-sim
.build/release/cribmaze-sim run --level medium --turns 1000 --seed 1 --dealer
```

Levels are `weak`, `medium`, `strong` and `perfect`. Balance numbers in the docs come from runs like this; [concept.md](cribbage/minigames/concept.md) › Decisions lists them with their dates.

## Tests

Run everything with `scripts/check.sh`. It runs the JS tests, a Swift format lint (notes only, not a failure yet), the Swift tests, and builds both apps with warnings as errors.

State on 2026-11-15, version 0.8.3: **48 tests, all passing** (28 Swift, 20 JS).

| Suite | Tests | What it covers |
|---|---|---|
| GameKit › Dice | 4 | Seeded dice match the reference vectors and the shared `dice.json` fixture; scripted dice replay |
| CribbageKit › Counting | 3 | Counting matches the shared `counting.json` cases; suit ties; card notation |
| CribMaze › Config | 2 | The repo's config files load; bad config fails loudly |
| CribMaze › Board | 3 | Positions, touching, lines, and every connected set in order |
| CribMaze › Match turn | 7 | Same seed, same turn; setup; rejected traces; scoring; the left-over warning and cost; scripted replay; special jokers |
| CribMaze › Starter joins (r16) | 4 | The starter counts with every set, is free under the card counter, and is named in a score only when it scores; off by default in older configs |
| CribMaze › Bots | 4 | Every level plays whole turns with only legal moves; the same seed plays the same turn; each seat has its own dice stream; perfect finds the best set |
| CribMaze › Engine rules | 1 | The engine never calls the clock, system randomness or UI code |
| JS › Fixtures | 5 | `dice.json`, `counting.json`, `classic-hands.json` and `pegging.json` agree with the reference code; the config files pass the load checks |
| JS › Scoring | 10 | Cribbage counting in the mocks: fifteens, pairs, runs, double runs, flushes, his nobs, singles and multis, sets over 5 cards, made cards |
| JS › Jokers | 5 | Joker tables add up, roll the right outcomes at the edges, and match their chances over 100,000 rolls |

Run one part:

```sh
node --test cribbage/minigames/            # JS tests
(cd swift && swift test)                   # Swift tests
(cd swift && swift test --filter StarterJoins)
```

## Mocks

The HTML mocks open straight from disk: see [mocks/README.md](cribbage/minigames/mocks/README.md). Crib Maze Beta replaced the match turn mock on 2026-11-15; `match-turn.html` stays frozen at r16. The maze walk, maze tiles and jokers mocks are still live.

## Docs

- Crib Maze: [rules](cribbage/minigames/rules.md) (player-facing), [concept](cribbage/minigames/concept.md) (intent, decisions, plan), [engine](cribbage/minigames/engine.md) (spec for ports), [stats](cribbage/minigames/stats.md), [ideation](cribbage/minigames/ideation.md), [maze inspiration](cribbage/minigames/maze-inspiration.md).
- App: [ARCHITECTURE.md](ARCHITECTURE.md) (Swift app, engine, records, effects) and [LIBRARIES.md](LIBRARIES.md) (tools and libraries).
- Design: the [card renderer](design/cards/index.html) and the [neon asset gallery](design/neon/).
- Tracking: [PLAN.md](PLAN.md), [TODO.md](TODO.md), [BUGS.md](BUGS.md), [CHANGELOG.md](CHANGELOG.md).

## Layout

```
cribbage/minigames/
  config/       rules, jokers, bots, timing and classic config (JSON)
  fixtures/     cases shared by the JS mocks and Swift tests
  mocks/        HTML mocks
  playtests/    saved playtest runs
swift/
  Sources/      GameKit, CardKit, CribbageKit, CribMaze, CribMazeBots, cribmaze-sim
  Tests/        Swift tests
  App/          Crib Maze Beta and the release app (XcodeGen: project.yml)
design/         card renderer and the neon asset set
scripts/        check.sh (all checks), debug.sh (build and run the beta)
```

## Licence

MIT ([LICENSE](LICENSE)).
