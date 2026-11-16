# Crib Maze: First Playtest Plan

Status: draft, 2026-11-15. The first human playtest of the Mac beta, Noddy Yookerspiel.

## Summary

People play the beta, and their records answer the tuning questions that are waiting on playtests. The playtest waits for the maze, so it tests a whole game: title to menu, the cut for first dealer, then hands of deal, scoring grid, shop and pegging on the maze until a player exits (decided 2026-11-15). The first GitHub release waits on this playtest (`RELEASING.md` › Each release).

## What it answers

Each question decides something already in the plan. A question that wouldn't change a rule or a number is left out (`stats.md` › Principles).

| Question | What we measure | It decides |
|---|---|---|
| Is the game the right length? | Hands and minutes a game, by person | Maze size, circular paths and gates (`stats.md` › Targets: 5 to 13 hands) |
| Do pegging and the grid both matter? | Who won, against who won more grids and who pegged more | The split between moving and working the maze (`stats.md` › Targets) |
| Do gates, switches and shifts read and play well? | Grid points spent on each, gates opened by jokers, and players' notes | Gate costs and the maze's pieces (`rules.md` › Moving through the maze) |
| How often does a person clear the board? | Share of turns ending in `board_cleared`, by person | How hard clearing should be (`TODO.md`) |
| Does the medium bot score like a person? | Steps a turn, person against the medium bot on the same seeds | Bot levels (`config/bots.json`) |
| How do people use the reach? | When it's played (seconds in, stuck or not) and its share of the turn's steps | Balancing the reach (`PLAN.md` › Phase 7) |
| How do people use the burn? | Burns a game, which cards, and how soon | Burn tuning and the 40-card floor |
| Is the 25 s stuck-board grace right? | How often a turn ends on `no_sets_left`, and whether a power joker was tried first | The grace (`rules.md` › Ending the turn) |
| Do the discard hints help? | Grid steps when the hint's principle was followed against when it wasn't; how often Hint is tapped | Keeping or dropping each principle, the flush one first (`config/hints.json`) |
| How often do sets tie on suit? | Share of a person's sets whose steps carry no suit | The tie rule (`rules.md` › Suit gates) |
| Is it clear and fun? | A few lines from each player after each game | What the next round looks at |

The beta's records carry the grid's answers already: the `deal` record and the events in `engine.md` › Events. The maze, pegging and the whole game need their own events, recorded through GameRecord. A field found missing MUST be added before the playtest, not guessed afterwards.

## Who and how

- Bruce, and SHOULD be at least two others: one who plays cribbage and one who doesn't.
- Each player plays at least 3 full games, every stage from title to exiting the maze, against the medium bot, on the build named below, with default settings.
- Everyone plays the same seed list first, so their scores compare with each other and with the bot (`cribmaze-sim` on the same seeds). Free play after that is fine.
- Players MUST NOT be coached during a game. Questions are written down and answered after.

## Build and records

- One build for the whole round, named by its version, with one match rules version. Runs from different rules versions MUST NOT be pooled.
- Records are local files in `~/Library/Application Support/Noddy Yookerspiel/records`. After each session they're copied into `playtests/<date>-p<n>/`, one folder a player.
- Players are numbered (p1, p2 and so on). Records and notes MUST NOT carry names or other personal details.

## Done when

The playtest starts once a whole game plays in the beta, maze included. It's done when every player has finished their games and the answers are written up in `concept.md` › Learnings, with the numbers. The first GitHub release goes ahead once:

1. No open bug in `BUGS.md` stops a game from finishing.
2. Every player finished a game without help.
3. The reach and the burn have numbers from people, not only bots.

## Open questions

1. Who are the other players, and when is the round?
