# PLAN.md

The tracker for Warped Cards' work, phase by phase. Each item is one line that points at its spec.

Where things live:

- **Concept, decisions and learnings for each game:** the game's `concept.md` (Crib Maze: [cribbage/minigames/concept.md](cribbage/minigames/concept.md)).
- **Player-facing rules:** the game's `rules.md`. **Stats and the simulator:** `stats.md`.
- **Mocks and their findings:** `mocks/README.md`. **Playtest data:** `playtests/`.
- **Small next tasks:** [TODO.md](TODO.md). **Bugs:** [BUGS.md](BUGS.md). **Changes:** [CHANGELOG.md](CHANGELOG.md).

Phases are Crib Maze's, as in its concept doc's Plan section. Two tracks run side by side: design (rules and mocks) and engine (spec, Python, simulator). Swift comes last.

## Phase 1 · Rules draft

- [x] First rules draft (`cribbage/minigames/rules.md`)
- [x] Draft 4: match turns for match rules r7, doors, suit gates for sets (`rules.md` › Match turns)
- [ ] Doors, prizes and power slots once designed (`rules.md` › Doors, Prizes)

## Phase 2 · Stats and simulator ideation

- [x] Scoring curves, timing, event log, telemetry rules (`cribbage/minigames/stats.md`)
- [x] Mock playtest runs with rules versions (`stats.md` › Mock playtests)

## Phase 3 · Mocks

- [x] Cards: standard layout, four-colour suits, back, jokers (`design/cards/index.html`)
- [x] Match turn, rules r7, bot skill levels (`cribbage/minigames/mocks/match-turn.html`)
- [x] Score breakdown v1 (`mocks/score-breakdown.html`)
- [ ] Playtest the match turn and tune it with your runs (`playtests/`)
- [ ] Score breakdown in the match turn
- [ ] Prize pick: where a prize goes, badges (`concept.md` › Deck building and prizes)
- [ ] Shop: spending pips between rounds
- [ ] Maze walk after a match turn (`concept.md` › The maze walk)
- [ ] Transitions between mini games, and begin, end and bonus effects (`concept.md` › Transitions and effects)
- [ ] Pegging on the maze, after maze inspiration

## Phase 4 · Engine spec

- [ ] Data model, event log, bot interface, sim clock (`stats.md` › Event log, Simulator)

## Phase 5 · Python engine and simulator

- [ ] Classic cribbage as the baseline
- [ ] Crib Maze rules, bots (random, greedy, planning), simulator at 1x, 100x, 1000x and flat out
- [ ] Stats reports and graphs (`stats.md` › Scoring curves)

## Phase 6 · Maze design

- [ ] Door strengths and placement; rules so far in `rules.md` › Doors
- [ ] Branches, traps, wall shifts, fog, generator (`concept.md` › The maze)

## Phase 7 · Tuning

- [ ] Tune with simulation until the numbers hold up (`stats.md` › Targets)

## Phase 8 · Face-card art

- [ ] Full graphics for J, Q and K (letters until then)

## Phase 9 · Card backs

- [ ] More backs (crosshatch until then)

## Phase 10 · Swift app

- [ ] iPhone app built from the specs
