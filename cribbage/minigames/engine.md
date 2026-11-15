# Crib Maze: Engine Spec

Status: draft 1, 2026-11-14. Covers the match turn at match rules r14. Deal, discard, cut, pegging, the maze walk and the shop get their own sections as their designs settle. Phase 4 of [PLAN.md](../../PLAN.md).

## Summary

This spec says exactly what the engine does, in plain language, so it can be built (in Swift first) and built again in another language that plays the same games from the same seeds. The player-facing rules are in [rules.md](rules.md); this doc adds what the rules leave open: card identity, the order of every random draw, how actions are checked, the events they produce, and the config the engine reads. How the code is laid out is in [ARCHITECTURE.md](../../ARCHITECTURE.md).

When this spec and the match turn mock disagree, this spec wins and the mock gets fixed or noted. When this spec and rules.md disagree, rules.md wins and this spec gets fixed. Differences from the mock are listed at the end.

## Ground rules

- The engine is a function: given a state, an action and the dice, it returns the new state and a list of events. It never reads a clock, a file or a random source of its own.
- Every random draw comes from a named dice stream, in the order this spec gives. Two engines that draw in the same order from the same seed MUST produce the same game.
- Every number and table the rules use comes from config (see Config). Nothing tunable is written into the code.
- Ordering MUST NOT depend on hash order. Wherever this spec says "in order", it means the order given here.
- Names shown to players (combo names, prize names) are not engine data. Events carry kinds and numbers; the app turns them into words.

## Cards

### Card identity

Every card in a game has an ID that never changes, so the same card can be followed across a turn, a round and a record.

| Cards | IDs | Notes |
|---|---|---|
| Standard 52 | 0 to 51: suit index × 13 + rank − 1 | Suit order: S, H, D, C. Ranks 1 (A) to 13 (K) |
| Extra cards (jokers, title, blank) | 100 upward, in the order they're added to the deck | Kind: amber, teal, title, blank |
| Made cards (from a joker) | 200 upward, in the order they're made | A rank and suit, plus the made flag; kept in the deck for the game |
| Special jokers in the stock | 300 upward, in the order they're shuffled in | Kind: swapper or bomb |

A card's value for fifteens is its rank, with 11, 12 and 13 counting 10.

### Notation

Records and fixtures write cards as rank then suit: `AS`, `10H`, `JD`, `KC`. Made cards add a star: `5H*`. Extra cards and special jokers use their kind: `amber`, `teal`, `title`, `blank`, `swapper`, `bomb`. Each event that names a card also gives its ID.

## The match board

### Positions

```
Positions on the match board

  g00 g01 g02 g03   c0        g  grid, row r and column c, 0 to 3
  g10 g11 g12 g13   c1        c  crib, top to bottom (dealer only)
  g20 g21 g22 g23   c2        h  hand, left to right
  g30 g31 g32 g33   c3        s  starter, in the corner
  h0  h1  h2  h3    s
```

Each position has board coordinates: grid `g(r,c)` is (r, c), crib `c(i)` is (i, 4), hand `h(i)` is (4, i), starter is (4, 4).

- Two positions touch when their coordinates differ by at most 1 in both row and column (8 neighbours, diagonals included).
- Hand, crib and starter are edge positions. Grid positions are the rest.
- The canonical position order, used wherever this spec says "in position order": grid row by row (g00, g01 ... g33), then hand h0 to h3, then crib c0 to c3, then the starter.

### Match turn state

| Field | Holds |
|---|---|
| player, dealer | Whose turn, and whether they hold the crib |
| hand, crib, starter | Edge cards; the crib is empty for a non-dealer |
| grid | 4 × 4 cells, each a card or empty |
| stock | Cards in order; the top is the next card drawn |
| drawn | Cards drawn from the stock this turn (for the card budget) |
| power | Power level per edge card ID, all 0 at the start |
| steps, pips | This turn's steps (can go below 0) and pips earned this turn |
| tray | Special jokers the player holds, by kind, plus items |
| scoredSets | Each scored set, as its sorted card IDs |
| best | The turn's best score so far (points and card IDs) |
| warned | Whether this player has seen the left-over warning (see Left-over warning) |
| stockOut, dead, over | Flags: nothing left to draw; no set can score; turn ended |
| made, extraLog | Cards made this turn, and each extra card's outcome |

## Setting up a match turn

There are two ways in. A full game sets up each match turn from the round (to be specced with the deal). Until then, the engine MUST support a standalone turn, as the mock plays it, for the simulator, the tests and the first beta app.

### Standalone turn

Inputs: the seed, config, whether the player is the dealer, the player's tray, and optionally fixed cards (a hand and starter) for tests and scenarios.

1. Build the standard 52 in ID order. Shuffle it (stream `deal`, purpose `shuffle`).
2. If fixed cards are given, take them out of the deck in the order given. Otherwise deal the hand (the top 4) and then the starter (the next card).
3. Deal the crib (the next 4). A non-dealer's crib cards are still removed, so the stock is the same size either way, but the crib stays empty on their board.
4. Remove the next 4 cards: the other player's hand.
5. Decide the jokers: a count from `jokers.perRound` (stream `deal`, purpose `joker_count`), then each joker's kind from `jokers.kinds` weights (purpose `joker_kind`, one draw per joker). Add them, then the configured extras (`title`, `blank`), to the end of the deck, giving IDs in that order.
6. Shuffle the remaining deck, extras included (stream `deal`, purpose `shuffle`). This is the stock.
7. Fill the grid from the top of the stock, row by row (g00 first). These draws count toward the card budget.
8. Emit `turn_start`. Then resolve any extra cards on the grid (see Extra cards), then run the after-action checks.

Later: in a full game, the round's shuffle decides the jokers (rules r14), and each match turn shuffles every card not in a hand, the crib or the starter.

## Actions

Each action names the player and carries the clock time (`clockMs`) from the session. An action that isn't allowed in the current state is an error, not an event: the app and bots MUST only send legal actions. A trace that the rules reject is legal; it produces a rejection event.

| Action | Fields | Allowed when |
|---|---|---|
| `trace` | positions, in the order traced | Turn not over |
| `swap` | line of grid positions; source: `tray` or the board position of a swapper | Turn not over; the player has the swapper |
| `bomb` | target grid position; source: `tray` or the board position of a bomb | Turn not over; the player has the bomb; the target holds a card |
| `end_turn` | none | Turn not over |
| `time_up` | none | Turn not over and the timer is on; sent by the session |

Arming and disarming a special joker is UI state, not an action. The app MAY log it separately for playtests.

### Trace

Checks run in this order. The first that fails decides the result.

| Step | Check | If it fails |
|---|---|---|
| 1 | 2 to `maxSet` positions, no repeats, each holding a card, none of them a special joker | `trace_rejected`, reason `size` or `special`; costs nothing |
| 2 | At least one grid position | `trace_rejected`, reason `no_grid_card`; costs nothing |
| 3 | The positions are connected through touching (in any order; the traced order doesn't matter) | `trace_rejected`, reason `not_touching`; costs nothing |
| 4 | This set of card IDs hasn't scored this turn | `trace_rejected`, reason `already_scored`; costs nothing |

Then count the set (see Counting a set). Each card in no combo is left over.

| Combos | Left over | Warned before? | Result |
|---|---|---|---|
| 1 or more | none | either | Score |
| 1 or more | some | no | `leftover_warning`; set warned; nothing else happens |
| 1 or more | some | yes | Score, with the left-over cost taken off |
| none | all | no | `leftover_warning`; set warned; nothing else happens |
| none | all | yes | `leftover_penalty`: steps go down by cost × cards; nothing clears; the set isn't marked scored |

A score, in order:

1. Points: combo points minus `leftOverCost` × left-over cards. This MAY be 0 or less; the set still scores and clears.
2. Pips: add the current power of every edge card in the set. Then each of those edge cards goes up `edgePower.step` levels.
3. Steps: add the points.
4. Suit: the suit most cards in the set share. A tie for most is no suit.
5. Mark the set's card IDs as scored. If the points beat the best so far (strictly), it becomes the best.
6. Emit `score`.
7. Clear the set's grid cells and refill (see Refilling the grid). Edge cards stay.
8. Resolve extra cards, then run the after-action checks.

### Swap

The line MUST be 2 to 4 grid positions in a straight, gap-free line: along a row, a column or a diagonal, each next to the last. Every position MUST hold a card (special jokers included). Order the line by row, then column, and reverse the cards along it.

- From the tray: the tray loses one swapper.
- From the board: the swapper's cell clears and refills after the swap.
- Emit `swap`, then refill if a cell cleared, resolve extra cards, and run the after-action checks.

### Bomb

The blast is the target cell plus its neighbours: the 4 beside it (`plus`) or all 8 (`square`), from `specials.bombShape`. Only cells holding a card are cleared. A bomb used from the board also clears its own cell.

- From the tray: the tray loses one bomb.
- Emit `bomb` with the cleared cards, refill, resolve extra cards, run the after-action checks. A bomb scores nothing.

### End turn and time up

Both end the turn (see Ending the turn), with reason `player` or `timer`.

## Refilling the grid

For each column from left to right that lost a card:

1. The cards left in the column fall to the bottom, keeping their order.
2. The empty cells above them fill from the stock, starting with the lowest empty cell and working up.
3. A draw takes the top card of the stock and counts toward the card budget. When the stock is empty, or `cardBudget` is above 0 and `drawn` has reached it, nothing is drawn and the cell stays empty.

The refill emits one `board_changed` event: the cells cleared, each card that fell (from, to) and each card drawn (cell, card).

## Extra cards

After setup and after every refill, look for an extra card on the grid. Scan in position order; resolve the first one found; repeat until none are left. A resolved extra card can bring another (a refill can draw one), so this is a loop.

For each extra card:

1. Roll its kind's table in `jokers.tables` (stream `reveal`, purpose `outcome:<kind>`).
2. Make the prize, from the outcome's `makes` or `special`:
   - A card: build the pool of 52 rank and suit pairs in ID order, filtered by the outcome (any card; a scoring card, which is a rank in `scoringRanks`; or a 5). Pick one (stream `reveal`, purpose `made_card`). It gets the next made-card ID.
   - A special joker: pick one from `specials.known`, in order (stream `reveal`, purpose `special_kind`).
   - Pips or an item: nothing to draw.
3. Place it, by the outcome's `goes`:
   - `board`: the made card takes the extra card's cell.
   - `stock`: the special joker goes into the stock at a position from 0 to the cards still drawable (inclusive), drawn from stream `board`, purpose `stock_insert`, so it stays within reach of the card budget. If nothing is drawable, it goes to the tray instead. The extra card's cell refills.
   - `tray`: the special joker or item goes to the tray. The cell refills.
   - `pips`: add the outcome's amount to pips. The cell refills.
4. Emit `extra_drawn` (the card, its outcome, the prize, where it went), then the `board_changed` from any refill.

A refill here draws one card for one cell, at the extra card's position, with no falling.

## After-action checks

Run after setup and after every action that changed the board, in this order:

1. If nothing more can be drawn and `stockOut` isn't set yet: set it, emit `stock_out` (reason `stock_empty` or `budget_used`).
2. If every grid cell is empty: end the turn with reason `board_cleared`.
3. Otherwise check whether any set can score: any connected set of 2 to `maxSet` positions, holding no special joker, with at least one grid card, not yet scored, whose points (after the left-over cost) are above 0. If none and `dead` wasn't set, emit `no_sets_left`. Set `dead` to the result.

## Ending the turn

1. If the reason is `board_cleared`, add the clear-board bonus (`clearBonus`: steps, pips or none) and emit `board_cleared`.
2. If a best score exists, award the prize: rare at `prize.rareAt` points or more, epic at `prize.epicAt` or more, common below. The prize is a special joker for the tray, picked by `prize.special` weights (stream `prize`, purpose `prize_special`). Emit `prize_won`.
3. Emit `turn_end` with the reason (`board_cleared`, `timer`, `player`) and the turn's totals.

Bots end their turn with reason `player` when they stop (see Bots).

## Counting a set

Counting is shared with classic cribbage (CribbageKit). It takes a list of cards and options, and returns every combo with the cards it uses, in this order:

| Order | Combo | How it's found | Points (config `scoring`) |
|---|---|---|---|
| 1 | Fifteens | Every subset of 2 or more cards whose values add to 15, each one a combo. Subsets in increasing bitmask order of card index | `fifteen` each |
| 2 | Pairs | Group by rank, ranks ascending. A group of 2, 3 or 4 is one combo | `pair`, `pairRoyal`, `doublePairRoyal` |
| 3 | Runs | Each maximal stretch of 3 or more consecutive distinct ranks, ascending. Multiplier = product of each rank's count. One combo per stretch, using every card of those ranks | `runPerCard` × length × multiplier |
| 4 | Flush | All cards one suit, and at least `flushMin` cards. Classic hands also allow a 4-card flush of the hand's cards without the starter (option `handFlush4`) | `flushPerCard` × cards |
| 5 | His nobs | A jack from the hand or crib, of the starter's suit, in the same set as the starter (option: the two indexes) | `nobs` |

- Each combo reports its kind, its multiplier or size, its points and its card indexes.
- A card is used if any combo includes it. Unused cards are the left-over cards.
- A set is a single with exactly one combo, a multi with two or more.
- Ace is low only: runs don't wrap (Q-K-A is not a run).
- Classic hand and crib counts use the same function: the crib needs all 5 cards for a flush, a hand needs its 4 (`handFlush4`). Classic wording stays with SCOREKEEP's rules doc; this spec only fixes the algorithm.

In the match turn, `flushMin` is 4, so any 4 or 5 cards of one suit traced together are a flush, and his nobs needs the starter and the jack in the set.

## Events

Every event names its type and carries the fields below. Cards appear as `{id, card}` pairs (for example `{"id": 17, "card": "5H"}`); positions as `g12`, `h0`, `c3`, `s`.

| Event | Fields |
|---|---|
| `turn_start` | rulesVersion, dealer, hand, crib, starter, grid, stockSize, timer, cardBudget, jokers (count and kinds), tray |
| `trace_rejected` | positions, reason |
| `leftover_warning` | positions, leftOver |
| `leftover_penalty` | positions, leftOver, cost |
| `score` | positions, cards, combos (kind, size or multiplier, points, card indexes), comboPoints, leftOver, cost, points, single or multi, suit, pips (power paid), powerAfter |
| `board_changed` | cleared, fell (card, from, to), drawn (card, cell) |
| `extra_drawn` | card, outcome, prize, goes, cell |
| `swap` | line, before, after, source |
| `bomb` | target, shape, cleared, source |
| `stock_out` | reason, cardsLeftOnGrid |
| `no_sets_left` | stockLeft, tray |
| `board_cleared` | bonus kind and amount |
| `prize_won` | tier, bestPoints, bestCards, special |
| `turn_end` | reason, steps, pips, best, scores, rejected, swaps, bombs, drawn, penalty total, left-over total, steps by suit, steps from sets with and without edge cards |

These names follow `stats.md` › Event log, with the turn's details added. `stats.md` will be brought in step once the Swift engine settles them.

## Dice

Each game has a 64-bit seed. Each stream is its own generator:

1. The stream's seed is the game seed XOR the 64-bit FNV-1a hash of the stream's name (UTF-8).
2. SplitMix64, started from the stream's seed, fills the four 64-bit words of a xoshiro256** generator.
3. A draw of an integer below n takes xoshiro256** output and uses Lemire's method with rejection, so every value is equally likely.
4. A weighted pick from integer weights draws below the total weight and walks the entries in the order given, taking the first whose running total passes the draw.
5. A shuffle is Fisher-Yates from the end: for i from the last index down to 1, draw j below i + 1 and swap i and j.

Every draw is reported as a roll: stream, purpose, range (n), value. A shuffle reports one roll per swap step.

| Stream | Purposes, in the order they happen |
|---|---|
| `deal` | `shuffle` (the 52), `joker_count`, `joker_kind` per joker, `shuffle` (the stock) |
| `reveal` | Per extra card: `outcome:<kind>`, then `made_card` or `special_kind` if the outcome needs one |
| `board` | `stock_insert` |
| `prize` | `prize_special` |
| `bot.<seat>` | A bot's own choices (see Bots) |

## Clock and timer

- The session stamps every action with `clockMs`, the game time since the turn started. The engine stores it on the step and never reads a clock.
- The timer is the session's job: it counts player time, pauses while a score breakdown or a joker reveal plays, and sends `time_up` when it reaches `timerSeconds`. A timer of 0 is off.
- In the simulator, the session advances a modelled clock by each action's duration from `timing.json`, using the same pauses.

## Bots

A bot sees the player's view (no hidden cards: the stock order is hidden) and returns one action. Its randomness comes from its own stream, `bot.<seat>`.

Each bot turn repeats until the turn is over:

1. Find the best set (below). If one scores above 0, trace it.
2. Otherwise, if it has a swapper (on the board first, then the tray), find the best swap: try every pair of touching grid cells (each cell, then its neighbours to the right, below, below-right and below-left), swap them in a copy, and find the best set. Take the swap that opens the highest score. If one opens a score above 0, swap.
3. Otherwise, if it has a bomb (on the board first, then the tray) and the grid isn't empty, bomb the cell whose blast clears the most cards (the first in position order on a tie).
4. Otherwise, end the turn.

Bots count as already warned about cards left over.

Finding the best set, by level (`bots.json`):

- Search `all` (perfect): every combination of 2 to `maxSet` positions, in position order, that passes the trace checks. Highest points wins; on a tie, the larger set; then the first found.
- Search `traced` (the lower levels): shuffle the positions holding cards (stream `bot.<seat>`, purpose `starts`), take the first `round(n × starts)` (at least 1) as starting cards, and walk paths from each: each next card touches the last, up to `depth` cards and never past `maxSet`, never repeating a card. Every path of 2 or more is checked. Highest points wins; on a tie, the first found.

## Config

All files live in `cribbage/minigames/config/` and carry a `version`. Values below are rules r14 as the mock plays them by default. The engine MUST check config on load: weights are positive integers, ranges hold (`min` ≤ `max`), every kind a table names exists, and `epicAt` ≥ `rareAt`.

### rules.json

```json
{
  "version": 1,
  "rulesVersion": "match-r14",
  "scoring": { "fifteen": 2, "pair": 2, "pairRoyal": 6, "doublePairRoyal": 12,
               "runPerCard": 1, "flushPerCard": 1, "nobs": 1 },
  "match": {
    "maxSet": 5, "flushMin": 4, "timerSeconds": 90, "cardBudget": 0,
    "leftOverCost": 2,
    "clearBonus": { "kind": "steps", "amount": 10 },
    "edgePower": { "start": 0, "step": 1 },
    "prize": { "rareAt": 8, "epicAt": 16, "special": [["swapper", 60], ["bomb", 40]] }
  },
  "specials": {
    "known": ["swapper", "bomb"],
    "start": { "swapper": 2, "bomb": 1 },
    "bombShape": "plus"
  }
}
```

A `cardBudget` of 0 means the whole stock. `timerSeconds` of 0 means no timer.

### jokers.json

```json
{
  "version": 1,
  "perRound": { "min": 0, "max": 2 },
  "kinds": [["amber", 1], ["teal", 1]],
  "extras": ["title", "blank"],
  "scoringRanks": [5, 10, 11, 12, 13],
  "outcomes": {
    "card":    { "goes": "board", "tier": "quiet", "makes": "any" },
    "scoring": { "goes": "board", "tier": "glint", "makes": "scoring" },
    "five":    { "goes": "board", "tier": "glint", "makes": "five" },
    "item":    { "goes": "tray",  "tier": "burst" },
    "power":   { "goes": "stock", "tier": "burst", "special": "any" },
    "named":   { "goes": "tray",  "tier": "burst", "special": "any" },
    "pips":    { "goes": "pips",  "tier": "glint", "amount": 5 }
  },
  "tables": {
    "amber": [["card", 90], ["scoring", 9], ["item", 1]],
    "teal":  [["card", 80], ["scoring", 15], ["power", 5]],
    "title": [["five", 34], ["named", 33], ["pips", 33]],
    "blank": [["five", 34], ["named", 33], ["pips", 33]]
  }
}
```

Weights are lists of pairs, not objects, so their order is fixed in every language.

### bots.json

```json
{
  "version": 1,
  "levels": [
    { "id": "perfect", "search": "all" },
    { "id": "strong",  "search": "traced", "depth": 5, "starts": 0.15 },
    { "id": "medium",  "search": "traced", "depth": 4, "starts": 0.5 },
    { "id": "weak",    "search": "traced", "depth": 3, "starts": 0.25 }
  ]
}
```

`starts` is a fraction, the one place config uses a non-integer. The engine MUST round `n × starts` half away from zero, so every language agrees.

### timing.json

Durations in milliseconds per action, for the simulator's modelled clock. These are placeholders until playtest records give real ones (`stats.md` › Timing).

```json
{
  "version": 1,
  "profiles": {
    "human": { "trace": 4000, "swap": 3000, "bomb": 2500, "breakdownBase": 1200, "breakdownStep": 0.85,
               "breakdownMin": 400, "reveal": 2500, "dealIn": 1600, "ending": 1500 },
    "bot":   { "trace": 300, "swap": 300, "bomb": 300, "breakdownBase": 0, "breakdownStep": 1,
               "breakdownMin": 0, "reveal": 0, "dealIn": 0, "ending": 0 }
  }
}
```

### fx.json

The effects catalogue belongs to the app, not the engine. Its format is set in Phase E (`ARCHITECTURE.md` › Presentation and effects).

## Left-over warning

The warning shows once per player, ever, not once per turn. The engine treats `warned` as an input: the session passes it in when the turn starts (from the player's saved profile) and reads it back after. The event `leftover_warning` tells the session to save it.

## Fixtures

Shared test cases live in `cribbage/minigames/fixtures/` as JSON. The JS mock tests and the Swift tests both read them.

| File | Cases |
|---|---|
| `counting.json` | A list of cards, options, and the expected combos (kind, size or multiplier, points, card indexes) and total |
| `classic-hands.json` | Classic hands and cribs with known counts: 29, 28, 24, 0, his nobs, the hand and crib flush rules |
| `dice.json` | For a few seeds and stream names: the first draws, a weighted pick and a shuffle of 52, so every port matches the generator exactly |
| `turns/*.jsonl` | Whole recorded turns (a header and steps). Replaying each MUST give the same events |

## Differences from the mock

The mock is a design tool, so it cuts corners the engine can't. These are engine decisions, not rule changes.

| Mock | Engine |
|---|---|
| `Math.random`, no seed | Seeded named streams; every draw recorded |
| Logs outcomes (cards scored) | Records actions, rolls and events, so turns replay |
| Picks only the last run in a set | Counts every run of 3 or more (no 5-card set can hold two, so scores don't change) |
| The traced bots' starting cards can include special jokers | Starting cards hold no special jokers (bot results shift a little) |
| Starter "apart" and "touching off" settings | Not in the engine; r14 has the starter in the corner and touching on |
| "Good hand" setting | Fixed cards in a standalone turn |
| Epic at double the rare threshold | `epicAt` set in config (16) |
| Warning state kept in browser storage | A player profile input (see Left-over warning) |

## Open questions

1. Classic cribbage as the baseline: the next section to spec is a full classic game (deal, discard, cut, pegging, show), since the simulator needs it first.
2. A full Crib Maze round: where jokers go when dealt into a hand or the crib, cut as the starter or played in pegging. rules.md lists this as not designed.
