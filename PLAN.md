# PLAN.md

The tracker for Warped Cards' work, phase by phase. Each item is one line that points at its spec.

Where things live:

- **Concept, decisions and learnings for each game:** the game's `concept.md` (Crib RPG: [cribbage/minigames/concept.md](cribbage/minigames/concept.md)).
- **Player-facing rules:** the game's `rules.md`. **Stats and the simulator:** `stats.md`.
- **Mocks and their findings:** `mocks/README.md`. **Playtest data and plans:** `playtests/`.
- **Small next tasks:** [TODO.md](TODO.md). **Bugs:** [BUGS.md](BUGS.md). **Changes:** [apps/apple/CHANGELOG.md](apps/apple/CHANGELOG.md) (the Mac app), [CHANGELOG.md](CHANGELOG.md) (spec).

Phases are Crib RPG's, as in its concept doc's Plan section. Two tracks run side by side: design (rules and mocks) and engine (spec, Swift engine, simulator). The Mac beta app follows the engine; iOS comes after it. How the code fits together: [ARCHITECTURE.md](ARCHITECTURE.md).

A game, as decided 2026-11-15: title, menu, start, cut for first dealer, then hands (deal, scoring grid, shop, pegging on the maze) until a player exits the maze, in 5 to 13 hands (`concept.md` › Decisions).

Next: GameRecord on the engine track, the maze on the design track, the first playtest in the beta.

## Done

- Phase 1 · Rules draft: rules drafts 1 to 5, now match rules r23 (`cribbage/minigames/rules.md`)
- Phase 2 · Stats and simulator ideation: scoring curves, timing, event log, telemetry, mock playtests (`stats.md`)
- Phase 3 · Mocks: cards, the match turn (frozen at r16), breakdown, effects, jokers v3 and joker reveals (`mocks/README.md`)
- Phase 4 · Engine spec: match turn, the game, classic cribbage baseline, config files and shared fixtures (`engine.md`, `config/`, `fixtures/`)
- Phase 5 · Swift engine, so far: foundations, classic counting, match turn rules in Swift, bots and `cribmaze-sim` (`ARCHITECTURE.md` › A, B, D)
- Phase 6 · Maze walk mock v1 and the maze tiles style guide (`mocks/maze-walk.html`, `mocks/maze-tiles.html`)
- Phase 6b · Deal and discard screen with a principle hint; deck edits, first cut: made cards stay, the burn joker, the deck shown (`engine.md` › The game)
- Phase 7 · First tuning passes: prizes and edge power from r16 to r22, and hand flushes in r18 (`concept.md` › Decisions, 2026-11-15)
- Phase 10 · Swift app: architecture agreed; Mac beta (Noddy Yookerspiel) with breakdown playback, card movement, the score's flight to the step count, the clock, hints, and signed, notarized release builds (`ARCHITECTURE.md` › E, `RELEASING.md`)

## Phase 5 · Swift engine and simulator

- [x] GameRecord: records, replay, counts; next, before more deck edits (`ARCHITECTURE.md` › C, 0.15.0)
- [ ] The game as hands until a player exits the maze, replacing the 3-turn game (`engine.md` › The game)
- [ ] Classic cribbage hands, pegging and bots in Swift (`ARCHITECTURE.md` › D)
- [ ] Bots that burn, and bots' grid turns that change the deck (`rules.md` › Match turns)
- [ ] Stats reports and graphs, hands per game first (`stats.md` › Targets)

## Phase 6 · The maze, prizes and shop

- [ ] The maze, more of a board game: circular paths, gates, switches, shifts, sized for 5 to 13 hands (`concept.md` › The maze)
- [ ] Gates: what opens each (points, suits, special jokers) and where they go (`rules.md` › Moving through the maze)
- [ ] Spending grid points on gates, switches and shifts (`concept.md` › Decisions, 2026-11-15)
- [ ] Special jokers played during pegging on the maze (`rules.md` › Moving through the maze)
- [ ] Pegging on the maze mock, with grid power multiplying pegging (`rules.md` › 5. Pegging on the maze)
- [ ] Prize cells, and the prize pick mock: where a prize goes, badges (`concept.md` › Deck building and prizes)
- [ ] Power slots: how many, and how you get more (`concept.md` › Open questions)
- [ ] Shop mock, after the scoring grid, started 2026-11-17 alongside the maze build: what you pay with, what's for sale (`rules.md` › 4. The shop)
- [ ] Transitions between mini games, and bonus effects (`concept.md` › Transitions and effects)
- [ ] Maze generator, traps and fog (`concept.md` › The maze)

## Phase 6a · The maze in the beta (playtest)

Built from `cribbage/minigames/maze.md`, the design handoff from `mocks/maze-board.html` v12 (Bruce, 2026-11-17: playtest it in the Mac beta). Each item moves its part of maze.md into engine.md or ui.md as it lands.

- [x] `@apple` The game as hands until a token reaches the goal, capped at `game.maxHands` (15), with 1 to 3 players in the engine (maze.md › The game around the maze) (engine 0.22.1; the 3-player deal is a TODO.md item)
- [ ] `@apple` Bots' grid turns off screen with `MatchBot`, their own power jokers, and a summary before your turn (maze.md › The game around the maze; concept.md › Phases › 5a) (engine done in 0.22.1, `botTurn`; the summary waits on the scene)
- [x] `@apple` Classic pegging scoring in Swift for duels, checked against `fixtures/pegging.json` (engine.md › Classic cribbage › The play)
- [x] `@apple` `config/maze.json`, and the maze generator in the engine, with a fixture per seed (maze.md › The board)
- [x] `@apple` Plays from the round's sets, turns, walking, doors, switches and closing, as engine actions and events (maze.md › Plays, Turns, Walking)
- [x] `@apple` Power jokers on the maze, fire and mine hazards, stars (maze.md › Power jokers on the maze)
- [x] `@apple` Stuck: the stir and duels, stuck and landing, with classic pegging (maze.md › Stuck, Duels)
- [ ] `@apple` Maze bots and `cribmaze-sim` whole games; check rounds a game and seat balance against maze.md › Stats
- [ ] `@apple` The beta's maze scene: board, camera, hops, fan, play sheet, tray, duel screen, hazard pause, tap to explain (maze.md › The screen)
- [ ] `@apple` A round in the beta: deal, scoring grid, then the maze, until a token reaches the goal; then playtest (`playtests/plan.md`)

## Phase 6b · Game flow and deck building

- [ ] Title, menu and start, and the cut for first dealer (`concept.md` › A round)
- [ ] More deck edits: paint, nudge, clone, forge, merge, badges (`mocks/joker-inventory.html`)
- [ ] Grow the joker inventory and pick the first chips and new jokers to build (`mocks/joker-inventory.html`)
- [ ] Jokers dealt into a hand: wild, with a power each (`rules.md` › A joker dealt into a hand)
- [ ] Bots' grid turns as a sequence of results before yours, hands face down (`rules.md` › Match turns)

## Phase 7 · Tuning

- [ ] Playtest the grid (phases 5b to 5e), then prototype the other first-version phases in order: pegging on the maze with the maze walk (a browser mock first), then the shop, then the cut and the bots' turns (`concept.md` › Phases, Bruce 2026-11-17)
- [ ] Tune with simulation and playtests until the numbers hold up (`stats.md` › Targets)
- [ ] Playtest r26 at its current edge power (25% of steps, was 52%), then add tools that raise scores rather than retuning it (Bruce, `concept.md` › Decisions, 2026-11-17)
- [ ] Retune prizes and made multipliers for a game of hands; later hands score more as the deck builds (`concept.md` › Decisions, r23)
- [ ] Balance the reach joker: it dominates when used at once (`concept.md` › Decisions, 2026-11-15)
- [ ] Simulate grid power carrying into pegging (`rules.md` › 5. Pegging on the maze)
- [ ] Design what else raises the pick limit for a while: combos, prizes (`engine.md` › Pick limit)
- [ ] Tune bot levels so medium scores like a person (`playtests/plan.md`)
- [ ] Tune the stuck-board grace (25 s) and hints from playtests (`rules.md` › Ending the turn)
- [ ] Prove or drop each discard principle, the flush one first (`config/hints.json`)

## Phase 8 · Face-card art

- [ ] Full graphics for J, Q and K (letters until then)

## Phase 9 · Card backs

- [ ] More backs (crosshatch until then)

## Phase 10 · Swift app

- [ ] First human playtest of the beta, a whole game once the maze plays (`playtests/plan.md`)
- [ ] Publish the first release on GitHub, after the first playtest (`RELEASING.md`)
- [ ] Joker reveals, and the begin and end effects, in the beta (`ARCHITECTURE.md` › Effects)
- [ ] More hints: an idle player, a missed set, a joker never used (`apps/apple/Shared/Hints.swift`)
- [ ] Beta tools: records, replay, stats, animation lab, tuning; after GameRecord (`ARCHITECTURE.md` › F)
- [ ] The rest of a round: the maze, pegging on it and the shop, as each design settles (`ARCHITECTURE.md` › G)
- [ ] iOS, and TestFlight for sharing the beta (`ARCHITECTURE.md` › H)
