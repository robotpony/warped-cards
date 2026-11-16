# PLAN.md

The tracker for Warped Cards' work, phase by phase. Each item is one line that points at its spec.

Where things live:

- **Concept, decisions and learnings for each game:** the game's `concept.md` (Crib Maze: [cribbage/minigames/concept.md](cribbage/minigames/concept.md)).
- **Player-facing rules:** the game's `rules.md`. **Stats and the simulator:** `stats.md`.
- **Mocks and their findings:** `mocks/README.md`. **Playtest data:** `playtests/`.
- **Small next tasks:** [TODO.md](TODO.md). **Bugs:** [BUGS.md](BUGS.md). **Changes:** [CHANGELOG.md](CHANGELOG.md).

Phases are Crib Maze's, as in its concept doc's Plan section. Two tracks run side by side: design (rules and mocks) and engine (spec, Swift engine, simulator). The Mac beta app follows the engine; iOS comes after it. How the code fits together: [ARCHITECTURE.md](ARCHITECTURE.md).

## Done

- Phase 1 · Rules draft: rules drafts 1 to 5, now match rules r18 (`cribbage/minigames/rules.md`)
- Phase 2 · Stats and simulator ideation: scoring curves, timing, event log, telemetry, mock playtests (`stats.md`)
- Phase 3 · Mocks: cards, the match turn (frozen at r16), breakdown, effects, jokers v3 and joker reveals (`mocks/README.md`)
- Phase 4 · Engine spec: match turn, classic cribbage baseline, config files and shared fixtures (`engine.md`, `config/`, `fixtures/`)
- Phase 5 · Swift engine: foundations, classic counting, match turn rules in Swift, bots and `cribmaze-sim` (`ARCHITECTURE.md` › A, B, D)
- Phase 7 · Tuning: prizes and edge power retuned for the joining starter, and hand flushes in r18 (`concept.md` › Decisions, 2026-11-15)
- Phase 10 · Swift app: architecture agreed; Mac beta (Noddy Yookerspiel) with breakdown playback, card movement, the score's flight to the step count, the clock, hints, and signed, notarized release builds (`ARCHITECTURE.md` › E, `RELEASING.md`)

## Phase 5 · Swift engine and simulator

- [ ] GameRecord: records, replay, counts (`ARCHITECTURE.md` › C)
- [ ] Classic cribbage hands, pegging and bots in Swift (`ARCHITECTURE.md` › D)
- [ ] Stats reports and graphs (`stats.md` › Scoring curves)

## Phase 6 · Maze, prizes and shop design

- [x] Maze walk mock v1: seeded maze, forks, gates, doors, prize cells, fog (`mocks/maze-walk.html`)
- [x] Maze tiles style guide (`mocks/maze-tiles.html`)
- [ ] Doors, prizes and power slots rules (`rules.md` › Doors, Prizes)
- [ ] Prize pick mock: where a prize goes, badges (`concept.md` › Deck building and prizes)
- [ ] Shop mock: what you pay with (pips are gone since r15), what's for sale
- [ ] Maze walk with real match turn sets, bots on the same maze (`concept.md` › The maze walk)
- [ ] Pegging on the maze mock, after maze inspiration
- [ ] Transitions between mini games, and bonus effects (`concept.md` › Transitions and effects)
- [ ] Multi-turn match: power jokers carry over between turns (`rules.md` › Special jokers)
- [ ] Door strengths and placement; rules so far in `rules.md` › Doors
- [ ] Branches, traps, fog, generator (`concept.md` › The maze)

## Phase 6b · Game flow

- [ ] Title, Options and Start screens (`concept.md` › A round)
- [ ] Deal and discard screen, untimed, with a principle hint (`concept.md` › Discard principles)
- [ ] Playtest the discard principles, and prove or drop the flush one with data (`config/hints.json`)
- [ ] Bots' grid turns as a sequence of results before yours, hands face down (`rules.md` › Match turns)
- [ ] Jokers dealt into a hand: wild, with a power each (`rules.md` › A joker dealt into a hand)
- [ ] Simulate grid power carrying into pegging (`rules.md` › Pegging on the maze)

## Phase 7 · Tuning

- [ ] Tune with simulation until the numbers hold up (`stats.md` › Targets)
- [ ] Balance the reach joker: it dominates when used at once (`concept.md` › Decisions, 2026-11-15)
- [ ] Design what else raises the pick limit for a while: combos, prizes (`engine.md` › Pick limit)
- [ ] Tune the stuck-board grace (25 s) and hints from playtests (`rules.md` › Ending the turn)

## Phase 8 · Face-card art

- [ ] Full graphics for J, Q and K (letters until then)

## Phase 9 · Card backs

- [ ] More backs (crosshatch until then)

## Phase 10 · Swift app

- [ ] Joker reveals, and the begin and end effects, in the beta (`ARCHITECTURE.md` › Effects)
- [ ] More hints: an idle player, a missed set, a joker never used (`swift/App/Shared/Hints.swift`)
- [ ] Beta tools: records, replay, stats, animation lab, tuning (`ARCHITECTURE.md` › F)
- [ ] Publish the first release on GitHub (`RELEASING.md`)
- [ ] The rest of a round, as each part's design settles (`ARCHITECTURE.md` › G)
- [ ] iOS, and TestFlight for sharing the beta (`ARCHITECTURE.md` › H)
