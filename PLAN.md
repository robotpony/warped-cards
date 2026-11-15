# PLAN.md

The tracker for Warped Cards' work, phase by phase. Each item is one line that points at its spec.

Where things live:

- **Concept, decisions and learnings for each game:** the game's `concept.md` (Crib Maze: [cribbage/minigames/concept.md](cribbage/minigames/concept.md)).
- **Player-facing rules:** the game's `rules.md`. **Stats and the simulator:** `stats.md`.
- **Mocks and their findings:** `mocks/README.md`. **Playtest data:** `playtests/`.
- **Small next tasks:** [TODO.md](TODO.md). **Bugs:** [BUGS.md](BUGS.md). **Changes:** [CHANGELOG.md](CHANGELOG.md).

Phases are Crib Maze's, as in its concept doc's Plan section. Two tracks run side by side: design (rules and mocks) and engine (spec, Swift engine, simulator). The Mac beta app follows the engine; iOS comes after it. How the code fits together: [ARCHITECTURE.md](ARCHITECTURE.md).

## Phase 1 · Rules draft

- [x] First rules draft (`cribbage/minigames/rules.md`)
- [x] Draft 4: match turns for match rules r7, doors, suit gates for sets (`rules.md` › Match turns)

## Phase 2 · Stats and simulator ideation

- [x] Scoring curves, timing, event log, telemetry rules (`cribbage/minigames/stats.md`)
- [x] Mock playtest runs with rules versions (`stats.md` › Mock playtests)

## Phase 3 · Mocks

- [x] Cards: standard layout, four-colour suits, back, jokers (`design/cards/index.html`)
- [x] Match turn, rules r8, bot skill levels, play-out and clear-board ending (`cribbage/minigames/mocks/match-turn.html`)
- [x] Playtest the match turn and tune it with your runs (`playtests/`)
- [x] Match turn begin and end effects: deal-in, board cleared, wrap-up (`mocks/match-turn.html` v8)
- [x] One score: edge power multiplies, capped; pips removed (rules r15, mock v9)
- [x] Score breakdown in the match turn (`mocks/match-turn.html`)
- [x] Jokers v3: amber, teal, title and blank cards with hidden chances tables, the reveal, simulation (`mocks/jokers.html`)
- [x] Joker reveals in the match turn, rules r14 (`rules.md` › Jokers and extra cards)

## Phase 4 · Engine spec

- [x] Match turn, rules r15: data model, actions, events, dice streams, config files, bots, clock (`cribbage/minigames/engine.md` draft 1)
- [x] Classic cribbage game for the baseline: deal, discard, cut, pegging, show, bots (`engine.md` › Classic cribbage, draft 3)
- [x] Write the config files and shared fixtures the spec names (`cribbage/minigames/config/`, `fixtures/`)

## Phase 5 · Swift engine and simulator

Build plan phases A to D in `ARCHITECTURE.md`.

- [x] Foundations: package, app targets, version stamping, checks (A)
- [x] Classic cribbage counting written fresh against shared fixtures, as the baseline (B)
- [ ] GameRecord: records, replay, counts (C)
- [x] Match turn rules r15 in Swift, tested against the spec (D)
- [x] Match turn bots and `cribmaze-sim` (D)
- [ ] Classic cribbage hands, pegging and bots in Swift (D)
- [ ] Stats reports and graphs (`stats.md` › Scoring curves)

## Phase 6 · Maze, prizes and shop design

- [ ] Doors, prizes and power slots rules (`rules.md` › Doors, Prizes)
- [ ] Prize pick mock: where a prize goes, badges (`concept.md` › Deck building and prizes)
- [ ] Shop mock: what you pay with (pips are gone since r15), what's for sale
- [x] Maze walk mock v1: seeded maze, forks, gates, doors, prize cells, fog (`mocks/maze-walk.html`)
- [x] Maze tiles style guide (`mocks/maze-tiles.html`)
- [ ] Maze walk with real match turn sets, bots on the same maze (`concept.md` › The maze walk)
- [ ] Pegging on the maze mock, after maze inspiration
- [ ] Transitions between mini games, and bonus effects (`concept.md` › Transitions and effects)
- [ ] Multi-turn match mock: the tray carries over (`rules.md` › Special jokers), if still needed
- [ ] Door strengths and placement; rules so far in `rules.md` › Doors
- [ ] Branches, traps, fog, generator (`concept.md` › The maze)

## Phase 7 · Tuning

- [ ] Tune with simulation until the numbers hold up (`stats.md` › Targets)
- [ ] Retune prizes and edge power for r16, where the starter joins every set (`concept.md` › Decisions, 2026-11-15)
- [ ] Design what raises the pick limit for a while: combos, jokers, prizes (`engine.md` › Pick limit)

## Phase 8 · Face-card art

- [ ] Full graphics for J, Q and K (letters until then)

## Phase 9 · Card backs

- [ ] More backs (crosshatch until then)

## Phase 10 · Swift app

- [x] Agree the architecture, tools and libraries ([ARCHITECTURE.md](ARCHITECTURE.md), [LIBRARIES.md](LIBRARIES.md))
- [x] Mac beta, playable match turn (`ARCHITECTURE.md` › Build plan E), without effects yet
- [x] Breakdown playback and card movement in the beta
- [ ] Joker reveals, and the begin and end effects, in the beta (`ARCHITECTURE.md` › Effects)
- [ ] The total flies up to the step counter at the end of a breakdown, as in the mock
- [ ] Beta tools: records, replay, stats, animation lab, tuning (F)
- [ ] The rest of a round, as each part's design settles (G)
- [ ] iOS, and TestFlight for sharing the beta (H)
- [ ] Release build (I)
