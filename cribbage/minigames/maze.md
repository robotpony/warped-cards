# Crib RPG: The maze, design for the build

Status: design handoff, 2026-11-17, from the browser mock `mocks/maze-board.html` v12 (commit 16496ef). This is what the Swift engine and the Mac beta (Noddy Yookerspiel) build next, so Bruce can playtest pegging on the maze in the beta. Player-facing wording lives in `rules.md` › 5 and Moving through the maze; the reasons and dates live in `concept.md` › Decisions. This doc holds the numbers, the order of things and the algorithms, so the builder can work from it without reading the mock.

When the build lands, the engine parts move into `engine.md` and the screens into `ui.md`, in the same commits as the code (`PORTING.md` › Keeping the spec true). Then this doc keeps only what isn't built yet.

Scope (Bruce, 2026-11-17): the beta builds all of this doc before the playtest, not a slice of it. It starts with 1 bot, but the engine MUST take 1 to 3 players (1 human, 1 or 2 bots) wherever this doc allows it, so a second bot needs only the 3-player deal.

A **round** in this doc is a **hand** in `engine.md` › The game as steps: the deal, the show, every player's grid turn, then the maze.

## The game around the maze

These replace `engine.md` › The game's fixed `game.turns` (Bruce, 2026-11-17).

- **Hands until the goal.** A game deals hands until a token reaches the goal. The maze is built once, when the game starts, and lasts the game.
- **Round cap.** `game.maxHands` (15, in `rules.json`). If no token has reached the goal when hand 15's maze phase ends, the player cheapest to the goal on the cost field wins. A tie goes to the tied player with more steps scored over the game, then to the first of them in turn order from the player after the last dealer.
- **Bots' grid turns.** Each bot plays a whole grid turn of its own, off screen, with `MatchBot` at its level (`engine.md` › Bots), from its own 4 kept cards and the starter, as the simulator already does. Its sets, hand count and crib count become its plays, and its prize joins its own power jokers. The screen shows only a summary of each bot's result, before your turn (`concept.md` › Phases › 5a).
  - A bot's turn starts its dice again from FNV-1a 64 of the text `<hand seed>/seat<n>`, so it never shifts the player's turn.
  - Each player has their own power jokers, from `specials.start`, carried from hand to hand.
  - With `deck.shared` true, every grid turn of a hand deals from the deck as it stood when the hand started. Cards made and burned are applied at the hand's end: the player's first, then each bot's in seat order.
- **Hand order.** Deal and discard, the show, the grid turns (bots first, then yours), then the maze. The next hand starts when every play is used, or when a token reaches the goal ends the game.

## What a player does

Each round, after the scoring grid, players peg on a shared maze. Every set a player scored on the grid, and their hand and crib counts, becomes a **play**: a card-like tile with its steps (the points) and its suit. Players take turns spending plays until every play is used. The first token into the goal wins the game.

On your turn you MUST use one play, in one of three ways:

- **Walk** it: your token moves one cell a step.
- **Close a door** with it: an open passage becomes a door of the play's suit.
- **Flip a switch** with it.

You MAY also use one power joker in the turn, before the play or after it.

The mock games run 6 to 12 rounds with a 900-step golden path (Stats, below).

## The board

### Size and seed

- The maze is a square grid, side `W = ceil(sqrt(length × 2.2))`, where `length` is the golden path's steps (900, so 45 × 45).
- Everything comes from the game's seed on the `maze` dice stream (`PORTING.md` › Same game, every build). The `maze` stream starts once, from the game seed, when the game starts, and is never started again: hands restart the other streams (`engine.md` › The game as steps), not this one. Nothing draws on it after the board is built (engine.md › The maze › The board).
- **Directions.** Every list of directions, and "clockwise", is up, right, down, left (N, E, S, W), with y growing downward. A cell's neighbours are listed in that order, skipping the edge of the grid; a pick "among" them draws an index into that list.
- **Ties.** Where this doc says nearest, cheapest or best and two are equal, the one earlier in the list it was picked from wins (candidates in clockwise order from the arrow, plays biggest first, walls in walls-list order).
- The start is the bottom-left cell. The goal is a cell exactly `length` steps from the start along the maze.

### Generation, in order

Built in the engine (Apple 0.22.3): the algorithm, with its integer rounding and every number from `config/maze.json`, is now in `engine.md` › The maze › The board, and `fixtures/mazes.json` checks 5 seeds. The Swift build makes exactly the mock's mazes (all 20 seeds checked, junction arrows and stars included).

One thing the build settled from the mock: nothing draws on the `maze` stream after the board is built. A cell that gains a fork after a flip or an opened wall starts with its arrow pointing up.

Results across seeds 1 to 20 at v12, Swift and mock alike:

- 24.3 doors a maze, between 21 and 27.
- 135 of 280 golden doors got a way round; 4.25 shortcuts a maze; 4 switches every time.
- 23 stars (900 / 40 is 22.5, rounded half up).
- About 30 junctions are crossed in a game (mock; the build's number comes with the simulator).

### What a cell and a passage can be

| Thing | Data | Notes |
|---|---|---|
| Passage | open, wall, door, switch | Every passage between two side-by-side cells |
| Door | strength, damage, suit or none, closed by (seat), shortcut and steps saved | "Strength left" is strength minus damage. A broken door is open for good |
| Switch | its letter (A to H), on or off | The two passages of a pair are always opposite |
| Junction | arrow direction | Only cells with 3 or more exits that aren't pockets show an arrow |
| Star | | Gone once taken |
| Hazard | fire or mine, set by (seat) | One a cell. Gone once it hits someone |

## Plays

- **Where they come from.** A play is one set scored on the grid this round, or the hand or crib count. Its steps are its points, and its cards are kept for the sheet and the duel.
- **Suit.** A play's suit is the one that appears most among the cards it scored with: a grid set's cards (the starter too, when the set used it), or the hand or crib's 4 cards and the starter. A tie for most means no suit.
- **The kept hand.** Each player's 4 kept cards for the round are stored too. The duel uses them.
- **Hand order.** Plays are shown biggest first.
- **Mock data.** The mock used 180 real medium-bot grid turns (`mocks/maze-sets.js`), about 14 plays and 226 steps a round. The build uses the round's real sets.

## Turns

1. A round's maze phase starts with the player after the dealer, as in pegging (`rules.md` › 5), and goes round the table.
2. A player with no plays left is skipped. When nobody has a play left, the round ends.
3. At the start of every round after the first, in this order:
   1. Plays owed to fire and mine damage come off the round's plays (Hazards).
   2. Then the stuck check runs (Stuck, below).
4. **The turn:** one play, plus at most one power joker, before or after the play.
   - If a human still holds a usable joker after their play, the turn waits for a joker or for End turn.
   - A bot uses its joker first, then its play.
5. The first token to reach the goal wins at once, mid-walk.

## Walking

A walk spends every step. One step is one cell. At each cell, work out where to go next:

1. **Candidates.** The exits you can pass: open passages, doors, and switches that are on.
   - Remove the way you came in.
   - If any candidate isn't a pocket, drop the pockets.
   - If nothing is left, allow every exit, so a stuck walk turns back.
2. **Doors you can't open.** If any candidate isn't a door of another suit, drop the doors of another suit. A key counts as opening them.
3. **Standing at a door.** If your token stopped against a door last time, and a door is still a candidate, keep only the doors.
4. **Choosing between candidates.**
   - **With a reach,** the play picks its way. A human's way is the one they tapped, otherwise the candidate nearest the goal (cost field, below). A reach doesn't turn the arrow.
   - **Otherwise,** take the first candidate clockwise from the arrow, starting at the arrow itself. Then turn the arrow to the next exit clockwise after the way taken, counting only exits that aren't pockets, if there are any.
5. **Wrong-suit door.**
   - If you hold a key, it's used up and you pass.
   - Otherwise the walk stops on this side, and the rest of its steps are lost. Mark the token as standing at a door.
6. **A door of your suit, or with no suit.** Spend steps on it, up to its strength left, and they don't move you.
   - If it's still standing, the walk ends there.
   - If it breaks, it's open for everyone, and the walk goes on with the steps left.
7. **Otherwise,** step into the next cell.
   - If it's the goal, you win.
   - If it holds a hazard, note it; the hazard goes off as you pass (Hazards).
8. **When the walk ends,** in this order:
   1. Hazards go off, in the order passed.
   2. A star in the end cell gives a joker.
   3. Landing on another player starts a duel (Duels).

A walk never fails. A whole play can be previewed by walking a copy of the state, and the game MUST show that preview before you commit:

- the path
- where it ends
- the cost to the goal from there
- "hits a door", "stopped by a door", "runs over a fire", "stops on a mine"

### The cost field

Bots, the header's % to go, the stuck check, the burn and mine targets and reach's default all use the same cost to the goal. It's Dijkstra from the goal over passable passages:

- An open passage costs 1.
- A door costs its strength left plus 1, plus 8 more if it has a suit.
- A switch that's off can't be passed.

## Closing a door and flipping a switch

### Close a door

- It takes a play with a suit. The play's steps × `closeMul` (1) become the door's strength, at least 2, and the play's suit becomes its suit.
- The passage MUST be open, with no token on either cell, and not at the goal. It can be anywhere on the board (`closeWhere`: anywhere).
- A player closes at most `closeMax` (1) doors a round.
- You can't close a door on the way of a player who closed a door on your way this round. A closer is marked as having closed on everyone whose way (downhill on the cost field) the passage was on.

### Flip a switch

- It uses a play of any size.
- Each switch flips at most once a round, whoever flips it.
- The pockets are worked out again after a flip.

## Power jokers on the maze

One set of power jokers for the whole game, shared with the scoring grid (`rules.md` › Special jokers). The maze effects:

| Joker | Target | Effect |
|---|---|---|
| Swapper | Another player | Trade places. Neither token is marked as standing at a door. Not the same pair back in the same round |
| Bomb | A door within 10 steps of you, or a hazard cell (as burn) | Door: opens if its strength left is 12 or less (`bombPower`), otherwise loses 12. Cell: a mine |
| Reach | None; used at once | Your next play picks its way at each junction. On the board, the junctions on your previewed path get a violet ring; tapping one turns that junction to its next way, for that play only |
| Burn | A hazard cell | A fire |
| Key | None; works by itself | The next wrong-suit door your walk meets lets you through. Used up |

- **Doors within 10 steps** means either end of the door is within 10 steps of you through passable passages.
- **Hazard cells** are cells on another player's way (downhill on the cost field), within 10 steps of them. Not the start, the goal, a cell with a token, or a cell that already has a hazard.

### Getting jokers

- **Stars.** A walk that ends on a star wins a joker (stream `maze.star`, purpose `star`). The weights are key 30, swapper 20, burn 20, bomb 15, reach 15.
- **At the start.** The mock starts each player with the grid's starting set: 2 swappers, a bomb, a reach and a burn. In the build, the maze uses whatever the player holds after the grid turn.

### Hazards: fire and mine

The first token to pass over a hazard sets it off, whoever placed it. The plays lost are picked at random from those left (stream `maze.burn`, purposes `burn_pass` or `burn_land`, then `burn_play` for each play).

| Hazard | Running over it | Stopping on it |
|---|---|---|
| Fire (burn) | 1 or 2 plays | 4 or 5 plays |
| Mine (bomb) | 2 or 3 plays | 6 or 7 plays |

- A hazard is gone once it goes off.
- **Plays owed.** If you have fewer plays left than you lose, the rest come off your next round's plays, as soon as they're dealt.
- **On screen,** the walk pauses on the hazard. A card shows "FIRE!" or "BOOM!", what happened ("You run over a fire: 2 plays burn"), and the lost play tiles burning out. It holds for 1.8 s, or 2.2 s when you stop on it, then the walk goes on.

## Stuck: the maze stirs, or a duel

At the start of each round after the first, a player is stuck if their cost to the goal hasn't dropped since the start of the last round. One event a round, at most:

- **Two or more players stuck:** the two furthest from the goal duel.
- **One player stuck, behind a door another player closed:** they duel the closer.
- **One player stuck, any other way:** the maze stirs for them. Pick from these (stream `maze.plot`, purpose `plot`):

| Opening | Weight | When it can happen | Effect |
|---|---|---|---|
| Fade | 50 | There is a door on their way | The door loses its suit, and its strength left halves, rounded up |
| Star | 25 | Their way is more than 5 cells long | A star falls on their way, 6 cells ahead, or at the way's end if shorter |
| Shift | 25 | A wall beside them has a way round of 20 steps or less | That wall opens; the one nearest the goal is picked |

A card tells everyone what happened ("The maze stirs: the ♥ door ahead of Bot 1 fades…").

## Duels

A duel is classic two-player pegging, played with each player's 4 kept cards from this round.

- **The cards.** A player with no kept hand on record, or whose hand shares a card with the other's, gets 4 dealt from the rest of the deck (stream `maze.duel`, purpose `duel_deal`).
- **Scoring.** Back and forth to 31, as in cribbage pegging:
  - fifteen 2, thirty-one 2
  - a pair 2, a pair royal 6, a double pair royal 12
  - runs of 3 or more, 1 a card
  - go 1, last card 1
- **Who leads.** The player first after the dealer, in turn order.
- **Winning.** The higher score wins.
  - A tie plays again once, with the other player leading.
  - Tied again, a coin decides (purpose `duel_coin`).
- **What the winner gets.** The loser's biggest play left moves to the winner, and a stuck duel also opens the winner's way:
  - If a door is on the winner's way, it breaks.
  - Otherwise, one of the openings above (purpose `duel_open`).

| Why | When | Extra for the winner |
|---|---|---|
| Stuck | Round start (Stuck, above) | Their way opens |
| Landing | A walk ends on another player's cell | None |

**When a landing counts.** The walk used all its steps there: it wasn't stopped by a door, and its last steps weren't spent on a door. Not at the start. At most once per pair a round. The turn goes on after the duel.

**Bot pegging.** A bot plays the card that scores most now, then avoids leaving the count at 5 or 21, then plays its highest card.

**On screen.**

- A human's duel takes the whole screen:
  - At the top: "DUEL!", one line saying why ("You landed on Bot 1's cell."), then the scoreboard.
  - **Scoreboard:** the two players side by side, each with their token and a 72 pt score. Gold border on the player to play, pink on the winner.
  - The bot's 4 cards show the card back (`design/cards/back.svg`).
  - In the middle, the count and the cards played. Each score is said ("Bot 1: fifteen, 2").
  - Your cards are at the bottom. The cards you can play are lit, with "Your card: tap one" under them.
  - Bot cards come about 850 ms apart.
- **The result:**
  - "You win" or "Bot 1 wins".
  - The play that changes hands, from your side: a big green + and the play's tile when you take it, a red − when you lose it.
  - "The way opens: …" for a stuck duel.
  - The game scores, only after a tie.
  - A "Back to the maze" button.
- **Between two bots,** no screen: the result shows as a card over the maze.

## Bots

Every bot style shares the same rules; they only choose differently. The mock's styles, for the beta to start from (they belong in `config/bots.json`):

| Style | Plays | Doors and switches | Jokers |
|---|---|---|---|
| Balanced | The play whose walk leaves it cheapest to the goal, all ways considered | Closes a door before the leader when the leader is more than 30 ahead and under 200 from the goal, using a middling suited play (of its suited plays of 6 steps or more, biggest first, the one at index n ÷ 2 rounded down; it needs 2 or more). Flips a switch when its gain is 15 or more | Yes |
| Racer | Its biggest play first | Never | Never |
| Timer | As balanced | Never | Never |
| Door closer | As balanced | Closes a door before anyone level with it or ahead, using its biggest suited play | Yes |
| Jokers | As balanced | Flips switches eagerly (gain 4) | Uses every joker as soon as it helps at all |

**Judging a walk.** Lower is better:

- the cost from where the walk ends
- 10 off for breaking a door
- 25 more for running over a fire, 70 for stopping on one
- 40 more for running over a mine, 100 for stopping on one

A switch's gain is the bot's own saving plus half the leader's loss.

**Joker use**, in this order, at most one a turn:

1. **Burn.** A fire where the leader's biggest play would end, else a hazard cell on the leader's way. Only if the leader is ahead (door closer: within 10 behind; jokers: always).
2. **Reach.** If picking the ways saves 8 or more (jokers: 1).
3. **Bomb.** The first door on its own way if it's within reach, and either it would open or the bot holds no play of its suit. Otherwise, a mine on the leader's way, if the leader is more than 20 ahead (jokers: always).
4. **Swapper.** With the leader, if the leader is more than 60 ahead (jokers: 10).

## The screen

The beta's maze scene. Sizes are for the 393 pt phone frame the beta shows.

```
  [HAND 3]  ( ● 1st 42% )  ( ■ 2nd 57% )         header: hand number, then each player:
                                                  place and % of the way still to go
  +--------------------------------------------+
  |                                            |
  |   neon maze, camera on the tokens          |  tap anything to have it explained
  |                                            |
  +--------------------------------------------+
  Hand 3: your grid made 14 plays, 237 steps      one status line
  YOUR PLAYS · 11 LEFT · 212 STEPS
   (36)(24)(24)(22)(22)(20)(16) ...               a fan of play cards: steps over suit
  .-------------- POWER JOKERS ---------------.
  |  [swap 2] [bomb 1] [reach 1] [burn 1] [key] |
  '--------------------------------------------'
```

- **Look.**
  - The neon maze art (`design/neon/neon-maze.js`, palette.json).
  - Walls are drawn double with a gap: two lines, each max(1.6, 4% of a cell) thick, max(3, 11% of a cell) apart. The mock has a single-wall setting.
  - Doors are cards laid across the passage, turned 18° (or −72° across an up-down passage). They show their strength left as the rank and their suit; with no suit, a dash.
  - A broken door shows as cracked.
  - Switches are lettered discs.
  - Fires show the burn card's flame. Mines show the bomb card's bomb on a pale disc.
- **Junction arrows.** These are subtle chevrons, drawn only at real forks near the tokens and along a previewed path. The way a walk takes shows in gold.
- **Camera.** It always fits every token, plus the walk or the previewed walk, closing in no further than about 7 cells across (54 pt a cell on a 380 pt board). It eases toward its target.
- **Walking.**
  - Tokens hop from cell to cell with a small lift and a shadow, 90 ms a step (normal: 160).
  - The walk starts after 350 ms, while the camera pulls back.
  - Hazards pause the walk (Hazards).
- **The fan.** Your plays, as small cream cards showing steps over suit. Tapping one opens the play sheet over the fan and the tray, without moving anything else.
- **The play sheet.**
  - It shows the play's tile (steps, suit, cards) and a "✕ Cancel" button.
  - **Walk N steps:** "Ends 82 from the goal, hits a door".
  - **Close a door:** "Put a ♥36 door on an open path". Greyed with the reason when it can't be used.
  - **Flip a switch:** a row per switch.
  - Choosing Close or Flip highlights the passages or switches you can pick on the board.
- **The tray.**
  - The scoring turn's power jokers tray (`ui.md` › Power jokers), with 5 slots, a violet count, cards stacked behind when you hold 2 or more, faded when you hold none, and raised when armed.
  - Below it: "One a turn, before or after your play", "Joker used this turn", or "Play a joker now, or end your turn" with an End turn button.
  - While a reach is on: "Reach is on: your next play picks its ways".
- **Targets.** An armed bomb or burn rings its target cells in pink. A bomb also marks its doors with a pink bar.
- **Tap to explain.** Tapping a door, switch, junction, star, hazard, token, the start or the goal shows a short card saying what it is and what it does ("Door ♥, 12 left (of 18). Only ♥ steps wear it down…"). Tapping a player in the header shows their steps to go, plays left, jokers and doors closed.
- **Event cards** for the stir and bot duels show over the top of the maze until tapped.
- **The end.** "You reach the goal!" or "Bot 1 reaches the goal".

## Config

These numbers live in `config/maze.json` (built, Apple 0.22.3), shaped and checked as `engine.md` › Config › maze.json says. Against the proposal here, the build makes every fraction a whole percent (`sizePercent` 220 for 2.2, `close.mulPercent` 100, `roundDoorPercent` 60) and names the generator's other numbers (`widenEvery`, `pathMargin`, `roundMinPercent`, `roundMaxExtra`, `roundNearPercent`, the switch numbers, `plot.starMinWay`). The duel's pegging points are `duel.peg`. The bot styles go in `config/bots.json`.

## Engine and records

The maze runs in the engine, one action at a time, so it can be recorded and replayed like the match turn (`engine.md` › Records). These names are a starting point; the build settles them in `engine.md`.

**Actions:**

- `maze_walk {play}`
- `maze_close {play, passage}`
- `maze_flip {play, switch}`
- `maze_joker {kind, target}`
- `maze_end_turn`
- `duel_card {card}`

**Events:**

- `maze_built` (the seed's summary)
- `round_plays`
- `walk` (cells, junctions taken, doors hit, stopped, star, hazards)
- `door_closed`, `switch_flipped`, `door_bombed`
- `hazard_set`, `hazard_hit` (plays lost, plays owed)
- `star`
- `stir`
- `duel_start`, `duel_card`, `duel_go`, `duel_end`
- `goal`

**Dice streams:**

| Stream | Purposes |
|---|---|
| `maze` | carve, goal, walls, door_suit, variant_suit, switch_edge, switch_wall, junction, prize_cells. Started once from the game seed (Size and seed) |
| `maze.star` | star |
| `maze.plot` | plot |
| `maze.duel` | duel_deal, duel_coin, duel_open |
| `maze.burn` | burn_pass, burn_land, burn_play |

The maze's streams have their own names, so the grid's `prize` stream and its draws never shift when a star is won (as with `opening`, `concept.md` › Decisions, r26). Every `maze.*` stream starts again each hand from the hand's seed, like the grid's.

**Fixtures:**

- one maze per seed
- a walk through a junction, a wrong-suit stop, a door broken mid-walk
- a fire passed and a mine landed on, with plays owed
- a stuck duel and a landing duel with a tie
- a whole game

**`cribmaze-sim`** SHOULD play whole games with bots, so hands per game, seat balance and joker use can be checked against the mock's numbers below.

## Stats from the mock

Bot-only games, seeds 1 to n, final settings (v12, 2026-11-17):

| Matchup | Games | Rounds a game | In 6 to 12 |
|---|---|---|---|
| Balanced vs balanced | 300 | 4 to 12, median 8 | 290 of 300 |
| Balanced vs racer | 40 | 6 to 13, median 8 | 39 |
| Door closer vs door closer | 40 | 7 to 15, median 11 | 28 |
| Balanced vs jokers | 40 | 4 to 10, median 7 | 36 |
| Three balanced | 60 | 5 to 11, median 8 | 59 |

- **Seats.** In 300 balanced games, the seats won 142 and 158, within chance. Three balanced players won 18, 21 and 21.
- **Per game,** balanced vs balanced:
  - about 2.5 duels (the first landing-duel runs counted 2.3)
  - 2.6 fires and 1.3 mines going off
  - 1.1 doors bombed
  - 2.5 reaches used
  - about 46 wrong-suit stops
- **Racer.** A racer loses almost every game to a balanced bot (2 to 5 of 40). Choosing well matters.

## Not in this build

- Fog (`rules.md` › Fog).
- The shop.
- Grid power multiplying pegging.
- A minimum strength for a closed door (question 39, open).
- More than 3 players.
- Pegging scores outside duels.

## Open questions

1. A minimum strength for closed doors (question 39)?
2. Is about 46 wrong-suit stops a game too many, with about 22 doors a maze? Playtest first.
3. Do 14 plays a round drag at 28 to 42 turns? Playtest first.
4. Does a landing duel need a cost, so players don't chase them?
