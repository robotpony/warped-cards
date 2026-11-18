# Crib RPG: Engine Spec

Status: draft 7, 2026-11-17, spec 12 (event names and Records match the Swift build's records, for porting: see [PORTING.md](../../PORTING.md)). Covers the match turn and the game at match rules r28, and a full game of classic cribbage as the baseline (specced, not built yet). A Crib RPG round's deal, cut and pegging reuse the classic sections; the maze walk and the shop get their own sections as their designs settle. Phase 4 of [PLAN.md](../../PLAN.md).

## Summary

This spec says exactly what the engine does, in plain language, so it can be built (in Swift first) and built again in another language that plays the same games from the same seeds. The player-facing rules are in [rules.md](rules.md); this doc adds what the rules leave open: card identity, the order of every random draw, how actions are checked, the events they produce, and the config the engine reads. How the code is laid out is in [ARCHITECTURE.md](../../ARCHITECTURE.md).

When this spec and the match turn mock disagree, this spec wins and the mock gets fixed or noted. When this spec and rules.md disagree, rules.md wins and this spec gets fixed. Differences from the mock are listed at the end.

## Ground rules

- The engine is a function: given a state, an action and the dice, it returns the new state and a list of events. It never reads a clock, a file or a random source of its own.
- Every random draw comes from a named dice stream, in the order this spec gives. Two engines that draw in the same order from the same seed MUST produce the same game.
- Every number and table the rules use comes from config (see Config). Nothing tunable is written into the code.
- Ordering MUST NOT depend on hash order. Wherever this spec says "in order", it means the order given here.
- Names shown to players (combo names, prize names) are not engine data. Events carry kinds and numbers; the app turns them into words.
- The phases of a game, in order, and which the first version includes, are listed in [concept.md › Phases](concept.md#phases). This spec covers the phases the engine runs: the deal, the show (The opening count), the grid (Match turn) and the game; classic pegging is specced for the baseline.

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
- Each position also has an index, its place in that order: g00 to g33 are 0 to 15 (row × 4 + column), h0 to h3 are 16 to 19, c0 to c3 are 20 to 23, the starter is 24. Actions carry indexes; events carry names.

### Match turn state

| Field | Holds |
|---|---|
| player, dealer | Whose turn, and whether they hold the crib |
| hand, crib, starter | Edge cards; the crib is empty for a non-dealer |
| grid | 4 × 4 cells, each a card or empty |
| stock | Cards in order; the top is the next card drawn |
| drawn | Cards drawn from the stock this turn (for the card budget) |
| power | Power level per edge card ID, all 0 at the start |
| steps | This turn's steps (can go below 0). There are no pips (r15) |
| tray | Special jokers the player holds, by kind, plus items. Players see it as "power jokers" (rules.md); the engine keeps the name `tray` |
| scoredSets | Each scored set, as its sorted card IDs |
| best | The turn's best score so far (points and card IDs) |
| warned | Whether this player has seen the left-over warning (see Left-over warning) |
| stockOut, dead, over | Flags: nothing left to draw; no set can score; turn ended |
| reaches | Reaches in effect, from reach jokers and timed keys: each an id, cards and seconds |
| keyCards | Cards added to the pick limit by keys that last the game (r28), this turn's and earlier turns' |
| made, extraLog | Cards made this turn, and each extra card's outcome |

## Setting up a match turn

There are two ways in. A full game sets up each match turn from the round (to be specced with the deal). Until then, the engine MUST support a standalone turn, as the mock plays it, for the simulator, the tests and the first beta app.

### Standalone turn

Inputs: the seed, config, whether the player is the dealer, the player's tray, the key cards carried in from earlier turns (r28, 0 without), optionally the game's deck (r23), and optionally fixed cards (a hand and starter) for tests and scenarios.

1. Take the game's deck in ID order, or the standard 52 without one. Shuffle it (stream `deal`, purpose `shuffle`).
2. If fixed cards are given, take them out of the deck in the order given. A fixed card the deck doesn't hold (burned, or from the other player's own deck) is used as given. Otherwise deal the hand (the top 4) and then the starter (the next card).
3. Deal the crib: the fixed crib if given, else the next 4. A non-dealer's crib cards are still removed, so the stock is the same size either way, but the crib stays empty on their board.
4. Remove the other player's hand: the held cards if given, else the next 4.
5. Decide the jokers: a count from `jokers.perRound` (stream `deal`, purpose `joker_count`), then each joker's kind from `jokers.kinds` weights (purpose `joker_kind`, one draw per joker). Add them, then the configured extras (`title`, `blank`), to the end of the deck, giving IDs in that order.
6. Shuffle the remaining deck, extras included (stream `deal`, purpose `shuffle`). This is the stock.
7. Fill the grid from the top of the stock, row by row (g00 first). These draws count toward the card budget.
8. Emit `turnStart`. With `opening` in config, count the opening (below): the hand, then the crib for the dealer. Then resolve any extra cards on the grid (see Extra cards), then run the after-action checks.

#### The opening count (r24)

Before the grid plays, the hand is counted as a classic show: its 4 cards (h0 to h3) and the starter, with the counting options `opening.hand`. For the dealer, the crib is counted the same way next (c0 to c3 and the starter, options `opening.crib`). Each count emits `opening`.

- Counted list: the 4 cards in position order, then the starter (index 4). His nobs: the jack of the starter's suit among the 4, as indexes [4, its index] in the counting options.
- Made cards' multipliers apply, as on the grid: multiply 100 by each made card's percent in turn, rounding half up (`(made × m + 50) / 100`, integers), counting the starter's only when a combo uses it, then cap at `jokers.madeCapPercent` if it's above 0. Points are `(combo points × made + 50) / 100`.
- Edge power doesn't apply, nothing powers up, nothing is left over or costs steps, the count doesn't mark a scored set and it is never the turn's best set.
- Points add to the turn's steps and to `openingSteps` in the totals. A count of 0 still emits `opening`.
- The opening bonus (r26): with `opening.bonus`, a count whose points are above `bonus.from` wins `(points − from) / per` power jokers, dividing whole numbers and rounding down (with `from` 6, r27: 11 to 15 is 1, 16 to 20 is 2, 21 to 25 is 3, 26 to 29 is 4; a made card's multiplier can take it higher). Each count is ranked on its own, hand and crib apart, on its points after the made multiplier. Each joker's kind is picked by `prize.special` weights (stream `opening`, purpose `bonus`, one draw per joker), and it goes into the tray at once, so it can be used this turn. The kinds are the `opening` event's `bonus`, in the order drawn, and their number adds to `openingJokers` in the totals.
- Without a bonus, the opening uses no dice. In the app, it plays before the grid deals in (ui.md › Scene: Match turn).
- If a counted card isn't a playing card, the count is 0 (an extra card can't be dealt into a hand yet).

The turn's deck size starts at the deck's card count. New made cards take IDs from 200, after the highest made card already in the deck, so a made card keeps its ID for the whole game.

Later: in a full game, the round's shuffle decides the jokers (rules r14).

### The deal (2 players)

Before a turn, the player is dealt 6 and throws 2 to the crib (rules.md › Deal and discard).

1. Take the game's deck in ID order (the standard 52 without one) and shuffle it (stream `round`, purpose `shuffle`). The player's 6 are cards 0 to 5, the bot's 6 are 6 to 11, and the starter is card 12.
   With own decks (`deck.shared` false), the player's 6 are cards 0 to 5 and the starter is card 6. The bot's 6 come from its own deck, less those 7 cards by ID, shuffled (stream `round`, purpose `bot_shuffle`).
2. The player picks 2 to throw, untimed. The bot keeps its best classic hand: for each of the 15 ways to keep 4 (throw pairs in index order of the 6 as dealt: {0,1}, {0,2} ... {4,5}), the total classic count over the 46 standard cards not in its 6 as starters (hand flushes and his nobs count; no crib estimate). Highest total wins, first found on a tie. Compare totals, not means, so every language agrees.
3. Start the turn with the player's kept 4 as the fixed hand, in the order the player sorted them (r24: the `discard` action's `kept`, laid h0 to h3; without it, the order dealt), the starter, the crib as fixed cards (the dealer's throw first) and the bot's kept 4 as held cards. From a game's deck, the setup MUST carry the cards themselves, not their notation, since made cards share notation with standard ones.

### The game (r23)

A game is `game.turns` match turns (3 for now). The deck lasts the game: deck building (concept.md › Decisions, 2026-11-15).

- **Deck.** Starts as the standard 52. When a turn ends, every card made in it joins the deck, and every card burned in it leaves. The deck holds its cards in ID order and keeps a list of burned cards.
- **Own decks.** With `deck.shared` false, the player and the bot each have a deck. Bots don't play grid turns yet, so every change goes into the player's deck, and the bot's stays standard.
- **Seeds.** Turn 1 uses the game's seed, so a one-turn game plays as a standalone turn from the same seed. Turn n after that uses FNV-1a 64 of the text `<seed>/turn<n>`.
- **Dealer.** The player deals turn 1 when the game says so; the deal then alternates.
- **Power jokers.** The tray starts from `specials.start`. A turn starts with the tray the last one ended with, plus the special joker its prize won.
- **Keys for the game** (r28). Key cards start at 0. A turn starts with the key cards the last one ended with.

Each finished turn keeps a result: turn, dealer, steps, best, prize tier and special, the cards made and burned, and the deck size after.

### The game around the maze

With the maze (the game's `mazeGame` setting, Records › Lines; [maze.md](maze.md) › The game around the maze), the game replaces `game.turns` with hands until a token reaches the goal, at most `game.maxHands`. It takes 1 to 3 players: seat 0 is the player, the rest are bots. Off, the game is as above.

- **Hands.** A hand is the deal and discard, the show, every player's grid turn (bots first, then the player's), then the maze. The game ends when a token reaches the goal, or when hand `game.maxHands`'s maze ends.
- **Bots' grid turns.** After the discard, each bot plays a whole grid turn of its own, off screen, before the player's turn starts. It plays from the deal seen from its seat: its 4 kept cards (laid in card ID order) are the hand, the starter is the same, it holds the crib when it deals, and the player's 4 are held out of the stock. Its grid deals from the deck as it stood when the hand started (its own deck, with `deck.shared` false). It starts with its own power jokers and its own key cards.
  - The turn's dice start again from the bot's seed, FNV-1a 64 of the text `<hand seed>/seat<n>` (the hand seed in decimal). Its rolls go in the step's rolls as usual. When it ends, the game's dice start again from the hand's seed, so the player's turn plays exactly as it would without the bot.
  - The bot plays with `MatchBot` at its seat's level (`players` › level; an unknown level plays as `medium`). Its own choices draw from stream `bot.<seat>` of its own dice, started from the same seed, which records don't hold (a replay plays the bot again). A reach or timed key it plays ends after `bots.reachActions` of its actions, as `reachOver`.
  - A bot's turn emits only `botTurn` (its result), not its match events.
- **Hand end.** When the player's turn ends, the deck changes apply in order: the player's (as above), then each bot's in seat order. A bot's made cards join with new IDs, one more than the highest made card the deck holds (200 if none), in the order made; a card it made and burned in the same turn doesn't join. Its burned cards leave. Its prize joins its own power jokers, and its key cards carry to its next turn.
- **Plays.** Then each seat's plays for the maze are made from its grid turn's events, in order: each `opening` count and each `score` with 1 step or more. A play is `{id, steps, suit, cards, from}`: steps are the event's points, suit is the `score` event's suit or, for a count, the suit most common among its 5 cards (none on a tie), cards are the event's cards, and from is `hand`, `crib` or `set`. Plays are numbered from 1 through the game, seat 0's first, and listed biggest first; plays of the same size keep the order they were made. Each seat emits `handPlays` (seat, plays, kept: its 4 kept cards).
- **3 players.** The engine holds 3 seats, but the 3-player deal (5 cards each and one to the crib, rules.md › Deal and discard) isn't built yet; until it is, only seats 0 and 1 are dealt grid turns.

The deal's hint (concept.md › Discard principles) is app behaviour, not an action; the beta records it beside the steps, as a note.

### The game as steps

A whole game also runs one action at a time, so it can be recorded and replayed (ARCHITECTURE.md › GameRecord). A game is a sequence of hands. Each hand is the deal (or fixed cards) and then a match turn; pegging and the maze will join each hand as they're specced.

| Game action | Fields | Allowed when |
|---|---|---|
| `startHand` | options: deal (true or false), fixedHand (4 cards in notation) and fixedStarter, cardBudget and timerSeconds (for this hand, in place of rules.json's), warned; all but deal and warned may be left out | Before the first hand, or after a hand that didn't end the game |
| `discard` | thrown: the player's 2 cards, as `{id, card}`; kept (r24, or none): the other 4, in the order they lie along the hand row | During the deal; both thrown cards from the player's 6; kept, when given, is exactly the other 4, each once |
| a match turn action | as in Actions below | During the hand's match turn |

1. The game starts with the game's seed and emits `gameStart` (hands, shared, firstDealer, deckSize).
2. `startHand` starts every dice stream again from the hand's seed (The game › Seeds) and emits `handStart` (hand, seed, dealer, deckSize, options). With the deal on and no fixed cards, it deals (The deal, drawing from these dice) and emits `deal` (player, bot, starter). Otherwise the match turn starts at once, with the fixed cards or off the top of the deck.
3. `discard` throws the player's 2; the bot throws by its best classic keep. It emits `discard` (kept, in the hand row's order, thrown, botKept, botThrown), then starts the match turn with the hand's options. A bot playing the player's seat (the simulator, the golden records) sends kept in card ID order.
4. When the match turn ends, the hand ends: `handEnd` (the turn's result). After the last hand, `gameEnd` (hands, steps).

In a game around the maze, step 3 also plays each bot's grid turn (`botTurn`) before the player's turn starts, and step 4 makes the plays (`handPlays`) before `handEnd` (The game around the maze).

A hand's options are the app's settings when it starts, so they ride on the action, not in the config. Because every hand starts its dice from its own seed, a hand plays exactly as the same turn does when the deal and the turn are run on their own.

## Actions

Each action names the player and carries the clock time (`clockMs`) from the session. In a record, an action is written `{"<name>": {<fields>}}` (Records › Encoding). Positions in actions are indexes (Positions), for example `{"trace":{"positions":[0,1,6,9]}}`. A `source` is left out for the tray and is a position index for a joker on the board. An action that isn't allowed in the current state is an error, not an event: the app and bots MUST only send legal actions. A trace that the rules reject is legal; it produces a rejection event.

| Action | Fields | Allowed when |
|---|---|---|
| `trace` | positions, in the order traced | Turn not over |
| `swap` | line of grid positions; source: `tray` or the board position of a swapper | Turn not over; the player has the swapper |
| `bomb` | target grid position; source: `tray` or the board position of a bomb | Turn not over; the player has the bomb; the target holds a card |
| `reach` | source: `tray` or the board position of a reach joker | Turn not over; the player has the reach joker (r19) |
| `reachOver` | id of a reach in effect | Turn not over; that reach is in effect. Sent by the session when the reach's seconds are up |
| `key` | source: `tray` or the board position of a key joker | Turn not over; the player has the key joker (r28) |
| `burn` | target grid position; source: `tray` or the board position of a burn joker | Turn not over; the player has the burn joker; the target holds a playing card; the deck is above `deck.minSize` (r23) |
| `endTurn` | none | Turn not over |
| `timeUp` | none | Turn not over and the timer is on; sent by the session |

Arming and disarming a special joker is UI state, not an action. The app MAY log it separately for playtests.

### Trace

Checks run in this order. The first that fails decides the result.

| Step | Check | If it fails |
|---|---|---|
| 1 | 2 to the pick limit (`maxSet`) picked positions, no repeats, each holding a card, none of them a special joker. With `starterJoins`, the starter isn't a picked position: tracing it is allowed and doesn't count | `traceRejected`, reason `size` or `special`; costs nothing |
| 2 | At least one grid position | `traceRejected`, reason `no_grid_card`; costs nothing |
| 2b | With `maxEdgeCards` (r24), at most that many positions from the hand and crib together (the starter isn't counted) | `traceRejected`, reason `edge_cards`; costs nothing |
| 3 | The positions are connected through touching (in any order; the traced order doesn't matter) | `traceRejected`, reason `not_touching`; costs nothing |
| 4 | This set of picked card IDs hasn't scored this turn | `traceRejected`, reason `already_scored`; costs nothing |

Then count the set (see Counting a set). Each card in no combo is left over.

#### The starter joins every set (r16)

With `starterJoins`, and the starter holding a playing card, every set is counted with the starter: the picked positions in traced order, then the starter last. Combo card indexes point into that list.

- If a combo uses the starter, it's in the set: its power level counts in the multiplier, it powers up, its suit counts, and `score` names it last in positions and cards.
- If no combo uses it, it's ignored: it isn't left over, adds no power, doesn't power up, and `score` leaves it out.
- His nobs needs only the jack of the starter's suit, from the hand or crib, in the set.
- A `leftoverPenalty` costs only the picked cards.

#### Hand flushes and an optional starter (r18)

With `starterJoins` and `handFlush`, two more rules apply:

1. Flushes count like a classic hand (`handFlush4` in the counting options): when the counted list is 4 picked cards and the starter, and the 4 picked cards are one suit, they score a 4-card flush whatever the starter's suit. The flush's card indexes leave the starter out. A starter of the same suit makes a 5-card flush. `flushMin` stays 4, so 3 picked cards never flush on their own.
2. The starter is optional. The engine MUST also count the picked positions alone, and use that count when it has combos and more points. A tie keeps the starter. With rule 1, the count without the starter can't score more today; the rule guards future combos that, like a flush, look at the whole set.

#### Pick limit

The pick limit is how many cards a set may pick: `maxSet`, plus the key cards (Key), plus the cards of each reach in effect (Reach), and never more than `maxPick` (r28; missing means no cap). Later, some combos and prizes may raise it too. The engine MUST keep the reaches and key cards in turn state so the app can show the limit. `maxSet` plus the most cards a reach can add MUST be 6 or less, and `maxPick` MUST be from `maxSet` to 6 (checked on load).

| Combos | Left over | Warned before? | Result |
|---|---|---|---|
| 1 or more | none | either | Score |
| 1 or more | some | no | `leftoverWarning`; set warned; nothing else happens |
| 1 or more | some | yes | Score, with the left-over cost taken off |
| none | all | no | `leftoverWarning`; set warned; nothing else happens |
| none | all | yes | `leftoverPenalty`: steps go down by cost × cards; nothing clears; the set isn't marked scored |

A score, in order:

1. Multiplier: add up the current power levels of the edge cards in the set. The multiplier, in percent, is 100 + `edgePower.percentPerLevel` × levels, no more than `edgePower.capPercent` (0 means no cap). With `edgePower.combine` set to `each`, every edge card's own multiplier is multiplied together instead, then capped. Then (r20) each joker-made card in the set multiplies it by its own `percent`, rounded half up after each, with the made cards' product no more than `madeCapPercent`. The `score` event's multiplier is the total.
2. Points: combo points × multiplier, rounded half up (in integers: (combo × percent + 50) div 100), minus `leftOverCost` × left-over cards. This MAY be 0 or less; the set still scores and clears.
3. Steps: add the points. Then each edge card in the set goes up `edgePower.step` levels.
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

### Reach (r19)

1. Use up the reach joker, as for a swap.
2. Roll how many cards it adds from `specials.reach.cards`, then for how many seconds from `specials.reach.seconds` (stream `special`, purposes `reach_cards` and `reach_seconds`).
3. Add it to the reaches in effect, with the next reach ID (from 1). The pick limit is `maxSet` plus the cards of every reach in effect, so reaches stack.
4. Emit `reach`. A reach joker used from the board clears and refills its cell, as for a swap. Then check the board (Checks), since a higher limit can open up a set.

The engine has no clock. The session counts each reach's seconds, pausing as the turn's timer does, and sends `reachOver` when they run out. `reachOver` removes that reach, emits `reachOver` with the new pick limit, and checks the board again, since a lower limit can leave no sets. The simulator, which has no clock either, ends a reach after as many bot actions as a person would make in its seconds: one per `timing.json` › `profiles.human.trace` milliseconds, rounded up.

### Burn (r23)

1. Use up the burn joker, as for a swap. A burn joker on the board can't burn itself.
2. Add the target's card to the turn's burned cards, and lower the deck size by 1.
3. Emit `burn` with the target, its card, the new deck size and the source. Clear the target (and a board source's cell), refill, resolve extra cards, run the after-action checks. A burn scores nothing.

The deck size is the game deck's count, plus cards made this turn, less cards burned. A burn MUST NOT take it below `deck.minSize` (25 without one: a turn needs 2 hands, a crib, the starter and a full grid). When the turn ends, burned cards leave the game's deck (see The game).

### Key (r28)

1. Use up the key joker, as for a swap.
2. Roll how long it lasts from `specials.key.lasts`: `game` or `timed` (stream `special`, purpose `key_lasts`).
3. For `game`: add `specials.key.cards` to the key cards. They last the rest of the game (The game).
4. For `timed`: roll its seconds from `specials.key.seconds` (stream `special`, purpose `key_seconds`) and add it to the reaches in effect with `specials.key.cards` cards and the next reach ID, exactly as a reach. It ends with `reachOver`, like any reach.
5. Emit `key`: for `game` with no id or seconds, for `timed` with both. A key joker used from the board clears and refills its cell, as for a swap. Then check the board (Checks).

A key MAY be used when the pick limit is already at `maxPick`: it is used up and adds key cards, but the limit doesn't move.

### End turn and time up

Both end the turn (see Ending the turn), with reason `player` or `timer`.

## Refilling the grid

For each column from left to right that lost a card:

1. The cards left in the column fall to the bottom, keeping their order.
2. The empty cells above them fill from the stock, starting with the lowest empty cell and working up.
3. A draw takes the top card of the stock and counts toward the card budget. When the stock is empty, or `cardBudget` is above 0 and `drawn` has reached it, nothing is drawn and the cell stays empty.

The refill emits one `boardChanged` event: the cells cleared, each card that fell (from, to) and each card drawn (cell, card).

## Extra cards

After setup and after every refill, look for an extra card on the grid. Scan in position order; resolve the first one found; repeat until none are left. A resolved extra card can bring another (a refill can draw one), so this is a loop.

For each extra card:

1. Roll its kind's table in `jokers.tables` (stream `reveal`, purpose `outcome:<kind>`).
2. Make the prize, from the outcome's `makes` or `special`:
   - A card: build the pool of 52 rank and suit pairs in ID order, filtered by the outcome (any card; a scoring card, which is a rank in `scoringRanks`; or a 5). Pick one (stream `reveal`, purpose `made_card`). It gets the next made-card ID. With `madeMultiplier` (r20), it also gets a multiplier, a percent picked from that table (stream `reveal`, purpose `made_multiplier`), which it keeps for the game. Card references in events carry it as `percent`.
   - A special joker: pick one from `specials.known`, in order (stream `reveal`, purpose `special_kind`).
   - Steps or an item: nothing to draw.
3. Place it, by the outcome's `goes`:
   - `board`: the made card takes the extra card's cell.
   - `stock`: the special joker goes into the stock at a position from 0 to the cards still drawable (inclusive), drawn from stream `board`, purpose `stock_insert`, so it stays within reach of the card budget. If nothing is drawable, it goes to the tray instead. The extra card's cell refills.
   - `tray`: the special joker or item goes to the tray. The cell refills.
   - `steps`: add the outcome's amount to this turn's steps. The cell refills.
4. Emit `extraDrawn` (the card, its outcome, the prize, where it went), then the `boardChanged` from any refill.

A refill here draws one card for one cell, at the extra card's position, with no falling.

## After-action checks

Run after setup and after every action that changed the board, in this order:

1. If nothing more can be drawn and `stockOut` isn't set yet: set it, emit `stockOut` (reason `stock_empty` or `budget_used`).
2. If every grid cell is empty: end the turn with reason `board_cleared`.
3. Otherwise check whether any set can score: any connected set of 2 to the pick limit (see Pick limit) positions, holding no special joker, with at least one grid card, not yet scored, whose points (after the left-over cost) are above 0. If none and `dead` wasn't set, emit `noSetsLeft`. Set `dead` to the result.

## Ending the turn

1. If the reason is `board_cleared`, add the clear-board bonus (`clearBonus`: steps or none) and emit `boardCleared`.
2. If a best score exists, award the prize: rare at `prize.rareAt` points or more, epic at `prize.epicAt` or more, common below. The prize is a special joker for the tray, picked by `prize.special` weights (stream `prize`, purpose `prize_special`). Emit `prizeWon`.
3. Emit `turnEnd` with the reason (`board_cleared`, `timer`, `player`) and the turn's totals.

Bots end their turn with reason `player` when they stop (see Bots).

## Counting a set

Counting is shared with classic cribbage (CribbageKit). It takes a list of cards and options, and returns every combo with the cards it uses, in this order:

| Order | Combo | How it's found | Points (config `scoring`) |
|---|---|---|---|
| 1 | Fifteens | Every subset of 2 or more cards whose values add to 15, each one a combo. Subsets in increasing bitmask order of card index | `fifteen` each |
| 2 | Pairs | Group by rank, ranks ascending. A group of 2 or more is one combo, scoring every pair in it: n cards give n(n−1)/2 pairs (made cards can give 5 or more) | `pair` × pairs |
| 3 | Runs | Each maximal stretch of 3 or more consecutive distinct ranks, ascending. Multiplier = product of each rank's count. One combo per stretch, using every card of those ranks | `runPerCard` × length × multiplier |
| 4 | Flush | All cards one suit, and at least `flushMin` cards. Classic hands also allow a 4-card flush of the first 4 cards (the hand) when the 5th (the starter) is another suit (option `handFlush4`) | `flushPerCard` × cards |
| 5 | His nobs | A jack from the hand or crib, of the starter's suit, in the same set as the starter (option: the two indexes) | `nobs` |

- Each combo reports its kind, its multiplier or size, its points and its card indexes, in ascending order.
- A card is used if any combo includes it. Unused cards are the left-over cards.
- A set is a single with exactly one combo, a multi with two or more.
- Ace is low only: runs don't wrap (Q-K-A is not a run).
- Classic hand and crib counts use the same function: the crib needs all 5 cards for a flush, a hand needs its 4 (`handFlush4`). Classic wording stays with SCOREKEEP's rules doc; this spec only fixes the algorithm.

In the match turn, `flushMin` is 4, so any 4 or 5 cards of one suit traced together are a flush, and his nobs needs the starter and the jack in the set.

## Events

Every event is written `{"<name>": {<fields>}}` (see Records › Encoding). The names and field names below are exactly what records hold. A card is a card reference, `{"id": 17, "card": "5H"}`, plus `"percent"` for a made card with a multiplier (r20). Event positions are names: `g12`, `h0`, `c3`, `s`. A field marked "or none" is left out when it has no value.

| Event | Fields |
|---|---|
| `turnStart` | rulesVersion, dealer (true or false), hand (cards), crib (cards; empty for a non-dealer), starter (card), grid (16 cards in position order, `null` for an empty cell), stockSize, timer (seconds), cardBudget, jokers (kinds, in the order dealt), tray (count by kind), keyCards (r28, or none when 0) |
| `opening` | what (`hand` or `crib`), positions (the 4, then `s`), cards (the same order), combos (as in `score`; card indexes into cards), comboPoints, madePercent, points (r24), bonus: the power jokers won for the tray, in the order drawn, or an empty list (r26) |
| `traceRejected` | positions, reason (`size`, `special`, `no_grid_card`, `edge_cards`, `not_touching`, `already_scored`) |
| `leftoverWarning` | positions, leftOver (count) |
| `leftoverPenalty` | positions, leftOver, cost |
| `score` | positions, cards, combos, comboPoints, multiplierPercent, multipliedPoints, leftOver, cost, points, multi (true for a multi, false for a single), suit (`S`, `H`, `D`, `C`, or none on a tie), powerAfter (level by edge position name) |
| `boardChanged` | cleared (positions), fell (each `{card, from, to}`), drawn (each `{card, cell}`) |
| `extraDrawn` | card, outcome, tier, prize, goes, cell |
| `swap` | line (positions, ordered as Swap says), before (cards), after (cards), source (a position, or `tray`) |
| `bomb` | target, shape, cleared (cards), source |
| `stockOut` | reason (`stock_empty`, `budget_used`), cardsLeftOnGrid |
| `reach` | id, cards, seconds, pickLimit, source |
| `reachOver` | id, pickLimit |
| `key` | id (or none), cards, lasts (`game` or `timed`), seconds (or none), pickLimit, source (r28) |
| `burn` | target, card, deckSize, source |
| `noSetsLeft` | stockLeft, tray |
| `boardCleared` | kind, amount |
| `prizeWon` | tier, bestPoints, bestCards, special |
| `turnEnd` | reason (`board_cleared`, `timer`, `player`), totals (below) |

A combo in `score` is `{kind, points, cards}` plus `size` or `multiplier` where the kind has one; `kind` is `fifteen`, `pair`, `run`, `flush` or `nobs`, and `cards` are indexes into the set's counted cards (Counting a set).

`turnEnd` › totals, all whole numbers (counts or steps) unless noted: steps, stepsFromEdgePower, best (or none), scores, singles, multis, rejected, warnings, swaps, bombs, reaches, drawn, burns, made, penaltyTotal, leftOverTotal, stepsBySuit (steps by suit letter), stepsWithEdge, stepsWithoutEdge, extraSteps, clearBonus, reachCards, reachSeconds, reachScores, reachSteps, reachBest (or none), bigScores, bigSteps, madeScores, stepsFromMade, openingSteps, openingJokers (r26), keys, keysForGame (r28). A timed key counts in reachScores, reachSteps and reachBest, as a reach does, but not in reaches, reachCards or reachSeconds.

Values (reasons, purposes, kinds, tiers) stay snake_case text; names and fields are camelCase. These names follow `stats.md` › Event log by meaning, not by case.

The game around the match turn adds its own events (The game as steps): `gameStart` (hands, shared, firstDealer, deckSize), `handStart` (hand, seed as decimal text, dealer, deckSize, options), `deal` (player, bot: cards; starter: card), `discard` (kept, thrown, botKept, botThrown), `handEnd` (result: turn, dealer, steps, best or none, tier or none, prize or none, made, burned, deckSize) and `gameEnd` (hands, steps). A game around the maze adds `botTurn` (seat, steps, best or none, tier or none, prize or none, made, burned, tray: the bot's power jokers after its prize) and `handPlays` (seat, plays, kept). A match turn's events sit beside them in the same list, unwrapped.

## Records

A record is one game as JSON Lines: one JSON object per line, UTF-8, each line ending in a single newline. It holds everything needed to play the game again and check it. Records are written by the Swift build today; another build MUST read them, and SHOULD write them byte for byte the same (ignoring `at`), so replays and fixtures can be shared. Why records exist and how they're used: `ARCHITECTURE.md` › GameRecord.

### Lines

Every line has a `kind`. Kinds a reader doesn't know MUST be skipped, so newer writers stay readable.

| Kind | Fields | Notes |
|---|---|---|
| `header` | format (1), game (`crib-maze`), rules (`match-r28`), specVersion (12), app, build, commit, platform, install, started, seed, config, players | First line, once. `specVersion` is the spec version the writer implements (`spec.json`), a whole number; records written before spec 2 leave it out. A replay whose engine names a different spec version or rules version says so, and still checks the steps. `app` to `install` describe the build and are left out when unknown. `seed` is decimal text, since JSON numbers lose precision past 2^53. `config` is the config files as the game ran them, each file's object under its name (`rules`, `jokers`, `bots`, `hints`; the simulator's `timing` and the classic game's `classic` aren't part of a Crib RPG game), plus `firstDealer`. `players` is a list of `{seat, kind, level}`: kind `human` or `bot`, level for bots only. A game around the maze writes `mazeGame: true` beside `firstDealer`; other games leave it out |
| `step` | seq, hand, clockMs, player, action, rolls, events, at | One per action, plus the opening step (seq 1, no action, no player). `hand` is the hand after the step, left out before the first. `player` is left out for the session's own actions (`timeUp`, `reachOver`, including a timed key's) |
| `note` | after, at, name, data | App behaviour outside the rules (the deal's hint, `deal_hint`). `after` is the seq it follows. Replays skip notes |
| `end` | at, clockMs, result | When the game finishes. `result` is `{hands, steps}`, hands as in `handEnd` |

A roll is `{stream, purpose, n, value}`: a draw of `value` below `n` (Dice). `at` is wall time, ISO 8601 with milliseconds and the local offset (`2026-11-15T23:39:34.356-07:00`); it's the only field allowed to differ between two runs of the same game. A last line cut short (the app stopped mid-write) is dropped and the rest is kept. A record without an end line is a game that was left.

### Encoding

These rules come from the Swift build's encoder. They're the format now, so other builds MUST follow them, not their own language's defaults.

1. Keys in every object are sorted by Unicode code point, byte order of UTF-8, upper case before lower case (`"A" < "Z" < "_x" < "a" < "aB" < "ab"`, and `"g12" < "g2"`). So `kind` is not first on a line.
2. No spaces or indents. Strings escape `"`, `\` and control characters (`\n`, `\u0001`); `/` and non-ASCII (`×`, `é`) are written as is.
3. Numbers are integers, written plainly. The one non-integer in config (`bots.json` › `starts`) is written as the shortest decimal that round-trips (`0.3`, `1`).
4. A tagged value (an action, an event) is an object with one key, its name, holding an object of its fields: `{"trace":{"positions":[0,1,6]}}`. A name with no fields holds an empty object: `{"endTurn":{}}`.
5. A field with no value is left out, not written as `null`. Inside a list, an empty slot is `null` (the grid in `turnStart`).
6. Maps (tray, powerAfter, stepsBySuit) are objects, so their keys sort too.

A step line: `{"action":{"trace":{"positions":[0,1,6,9]}},"at":"…","clockMs":12000,"events":[{"score":{…}},{"boardChanged":{…}}],"hand":1,"kind":"step","player":0,"rolls":[],"seq":7}`.

The checked-in records (Fixtures) are the reference. Where this section and a record disagree, the record wins until this section is fixed.

## Dice

Each game has a 64-bit seed. Each stream is its own generator:

1. The stream's seed is the game seed XOR the 64-bit FNV-1a hash of the stream's name (UTF-8).
2. SplitMix64, started from the stream's seed, fills the four 64-bit words of a xoshiro256** generator.
3. A draw of an integer below n (n ≥ 1) uses Lemire's method with rejection, so every value is equally likely: take a 64-bit output x and form the 128-bit product m = x × n. Let low be m's lower 64 bits. If low < n, let t = (2^64 − n) mod n, and while low < t, draw a new x and recompute m and low. The value is m's upper 64 bits.
4. A weighted pick from integer weights draws below the total weight and walks the entries in the order given, taking the first whose running total passes the draw.
5. A shuffle is Fisher-Yates from the end: for i from the last index down to 1, draw j below i + 1 and swap i and j.

A game's dice can start every stream again from a new seed, as each hand does (The game as steps). Every draw is reported as a roll: stream, purpose, range (n), value. A shuffle reports one roll per swap step. The reference is `mocks/dice.js`; `fixtures/dice.json` holds its values for every port to match.

| Stream | Purposes, in the order they happen |
|---|---|
| `round` | The deal before a turn: `shuffle` (the 52) |
| `deal` | Match turn: `shuffle` (the 52), `joker_count`, `joker_kind` per joker, `shuffle` (the stock). Classic: `shuffle` and `cut_for_deal` per cut at the start, then `shuffle` and `cut` each hand |
| `reveal` | Per extra card: `outcome:<kind>`, then `made_card` (and `made_multiplier`, r20) or `special_kind` if the outcome needs one |
| `board` | `stock_insert` |
| `special` | Per reach joker: `reach_cards`, then `reach_seconds` (r19). Per key joker: `key_lasts`, then `key_seconds` for a timed one (r28) |
| `opening` | Per opening count with a bonus: `bonus` per power joker won (r26) |
| `prize` | `prize_special` |
| `bot.<seat>` | A bot's own choices (see Bots). A bot's own grid turn draws its match turn on the game's streams, started again from its seed (The game around the maze) |

## Clock and timer

- The session stamps every action with `clockMs`, the game time in milliseconds since the game started. Game time stops whenever the turn timer pauses (below), so it measures play, not presentation; it runs through the deal. The engine stores it on the step and never reads a clock.
- The timer is the session's job: it counts player time, pauses while a score breakdown or a joker reveal plays, and sends `timeUp` when it reaches `timerSeconds`. A timer of 0 is off.
- In the simulator, the session advances a modelled clock by each action's duration from `timing.json`, using the same pauses.

## Bots

A bot sees the player's view (no hidden cards: the stock order is hidden) and returns one action. Its randomness comes from its own stream, `bot.<seat>`.

Each bot turn repeats until the turn is over:

1. Find the best set (below). If one scores above 0, trace it.
2. Otherwise, if no reach is in effect and the pick limit is below `maxPick`: if it has a key joker (on the board first, then the tray), use it (r28); else if it has a reach joker (on the board first, then the tray), use it (r19).
3. Otherwise, if it has a swapper (on the board first, then the tray), find the best swap: try every pair of touching grid cells that both hold a card, leaving out a board swapper's own cell (each cell, then its neighbours to the right, below, below-right and below-left), swap them in a copy, and find the best set. Take the swap that opens the highest score; on a tie, the first pair tried. If one opens a score above 0, swap.
4. Otherwise, if it has a bomb (on the board first, then the tray) and the grid isn't empty, bomb the cell whose blast clears the most cards (the first in position order on a tie).
5. Otherwise, end the turn.

Bots count as already warned about cards left over.

Finding the best set, by level (`bots.json`):

- Search `all` (perfect): every combination of 2 to `maxSet` positions, in position order, that passes the trace checks. Highest points wins; on a tie, the larger set; then the first found.
- Search `traced` (the lower levels): list the positions holding playing cards, in position order, leaving out special jokers; n is the length of that list. Shuffle it (stream `bot.<seat>`, purpose `starts`, so n − 1 rolls). Take the first `round(n × starts)` (at least 1) as starting cards, in shuffled order, and walk paths from each: each next card touches the last, up to `depth` cards and never past `maxSet`, never repeating a card. Every path of 2 or more is checked. Highest points wins; on a tie, the first found.

The traced search MUST run in this order, so every port draws the same rolls and breaks ties the same way:

- A walk is depth first. At each step it tries the next cards in the shuffled order, not position order, and checks each path as it reaches it.
- With the pick limit above `maxSet` (a reach in effect, or key cards), a walk may go one card deeper for each card above `maxSet`, up to the pick limit; `all` searches every set up to the pick limit.
- Each search shuffles afresh. In step 2, every candidate swap, in pair order, gets its own traced search on its copy of the board, with its own `starts` shuffle. A swap search therefore draws one shuffle per pair tried.
- Search `all` draws nothing from `bot.<seat>`.

Note, 2026-11-14: the three points above were settled from the Swift bots, which match the mock. Bot results in `mocks/README.md` › Match turn v9 still stand.

## Classic cribbage

A full game of classic cribbage, for 2 or 3 players. It is the simulator's baseline (how a classic game scores and how long it runs), and a Crib RPG round reuses its deal, cut and play. The player-facing wording is Scorekeep's How to play page (`~/projects/utilities/scorekeep/docs/rules/cribbage.md`); the 3-player deal is Crib RPG's ([rules.md](rules.md) › Deal and discard). This section fixes the algorithm and doesn't change either. Numbers come from `classic.json`.

### Game state

| Field | Holds |
|---|---|
| players, seats | 2 or 3; seats are numbered 0 up, and play passes from a seat to the next (seat + 1, wrapping) |
| dealer | The dealing seat this hand |
| scores | Points per seat |
| stage | `discard`, `cut`, `play`, `show` or `over` |
| hands | Each seat's cards; 6 or 5 after the deal, 4 after the discard |
| crib, starter | The dealer's crib (4 cards once everyone has discarded), and the starter once cut |
| stock | The cards left after the deal, in order |
| play | The count, the cards played since the count last started (in order), each seat's played cards, whose turn it is, the last seat to play, and which seats have said go |
| hand | How many hands have been played |

### Starting a game

1. Build the standard 52 in ID order and shuffle it (stream `deal`, purpose `shuffle`).
2. Cut for deal: each seat in order cuts once, drawing an index below the cards left (purpose `cut_for_deal`); that card comes out of the deck. Emit `cutForDeal` with each seat's card.
3. The lowest rank deals (ace is low; suit doesn't count). If two or more tie for lowest, only they cut again, in seat order, from the cards left, until one is lowest.
4. Emit `gameStart` (rulesVersion, players, target, dealer), then start the first hand.

### A hand

1. Shuffle all 52 (stream `deal`, purpose `shuffle`).
2. Deal from the top, one card at a time, starting with the seat after the dealer and going round, until each seat has `cards`. Then deal `toCrib` cards to the crib. The rest is the stock. Emit `deal` (dealer; each seat's view shows only its own cards).
3. Discard: each seat sends `discard` with exactly `discard` of its cards, in any order. Emit `discarded` for each (the cards are hidden from other seats). When all have discarded, the crib is the dealt crib card, if any, then the discards in seat order.
4. Cut: the seat before the dealer (the dealer's right) sends `cut`. Draw k below (stock size − 2 × `cutMin` + 1), purpose `cut`; the starter is the stock card at index `cutMin` + k. Emit `starter`. If it's a jack, the dealer pegs his heels (`peg.heels`).
5. The play (below).
6. The show (below).
7. The deal passes to the next seat, win or lose. Emit `handEnd` with the scores, and start the next hand.

Every point is pegged the moment it's scored, as a `pegged` event (seat, kind, points, new total). If a total reaches `target`, the game ends right there: emit `gameEnd` (winner, scores, hands played) and set the stage to `over`. Nothing after it is scored, mid-play or mid-show.

### The play

The count starts at 0 and the seat after the dealer plays first. On a seat's turn:

- If any of its cards keeps the count at `maxCount` or under, it MUST send `play` with one of them.
- If none can, the engine emits `go` for that seat, and the turn passes on. A seat that has said go sits out until the count starts again.

After each card, add its value (rank, with 11, 12 and 13 counting 10), emit `played` (seat, card, count) and score, in this order:

| Order | Kind | When | Points |
|---|---|---|---|
| 1 | `fifteen` | The count is 15 | `peg.fifteen` |
| 2 | `thirty_one` | The count is `maxCount` | `peg.thirtyOne` |
| 3 | `pair` | The last k cards since the count started share a rank, k ≥ 2 (take the largest k) | `peg.pair` × k(k−1)/2 |
| 4 | `run` | The last n cards since the count started are n distinct, consecutive ranks in any order, n ≥ 3 (take the largest n) | `peg.runPerCard` × n |
| 5 | `last_card` | Every card from every hand is down, and the count isn't `maxCount` | `peg.lastCard` |

Then the count starts again when:

- The count is `maxCount`: start again at once (no go point).
- No seat can play and cards remain: the last seat to play pegs `go` (`peg.go`). Emit `countReset`, then start again.

After a start again, the seat after the last one to play leads, skipping seats with no cards. Ace is low here too, so Q-K-A is no run. When every card is down, the play ends and the cards go back to their owners for the show.

The Swift build plays this (`CribbageKit` › `PegPlay`) for the maze's duels, and checks it against `pegging.json`; the rest of a classic game isn't built in Swift yet.

### The show

Count in order, starting with the seat after the dealer and going round to the dealer, then the dealer's crib:

- A hand: its 4 cards then the starter, counted with `show.hand` options. His nobs: a hand jack of the starter's suit.
- The crib: its 4 cards then the starter, with `show.crib` options (a flush needs all 5). His nobs counts here too.

Each count uses Counting a set with `classic.json`'s `scoring`, emits `show` (seat, hand or crib, cards, combos, points), and pegs its total as one `pegged` event (kind `show` or `crib`). A jack cut as the starter is his heels, pegged at the cut, never his nobs.

The engine counts every hand in full, so there is no muggins. Skunks aren't scored (as on Scorekeep).

### Actions

| Action | Fields | Allowed when |
|---|---|---|
| `discard` | cards (exactly `discard` of the seat's own) | Stage `discard`; this seat hasn't discarded |
| `cut` | none | Stage `cut`; the seat before the dealer |
| `play` | card | Stage `play`; this seat's turn; the card keeps the count at `maxCount` or under |

Gos, starting the count again, the show and the next deal need no action: the engine runs them as soon as they're due. The session paces them on screen.

### Events

| Event | Fields |
|---|---|
| `gameStart` | rulesVersion, players, target, dealer |
| `cutForDeal` | cuts (seat, card), in order, recuts included; dealer |
| `deal` | hand number, dealer, each seat's cards (own view only), crib card if any |
| `discarded` | seat, cards (own view only) |
| `starter` | card, cut index, heels or not |
| `played` | seat, card, count |
| `go` | seat |
| `countReset` | reason (`thirty_one` or `go`) |
| `show` | seat, `hand` or `crib`, cards, combos (as in Counting a set), points |
| `pegged` | seat, kind (`heels`, `fifteen`, `thirty_one`, `pair`, `run`, `go`, `last_card`, `show`, `crib`), points, total |
| `handEnd` | hand number, scores, points this hand by kind and seat |
| `gameEnd` | winner, scores, hands played |

### Bots

A classic bot sees its own cards, the starter once cut, the play so far and the scores. It never sees other hands, the crib or the stock. Levels are in `bots.json` › `classic`. Its randomness comes from `bot.<seat>`.

"In order" for a hand means sorted by card ID. Discards are tried as index combinations of that sorted hand, in lexicographic order ({0,1}, {0,2} ... {4,5}).

Discard, by `discard`:

- `random`: one discard chosen evenly (purpose `discard`).
- `hand`: keep the cards whose count without a starter (4 cards, `flushMin` 4, no nobs) is highest. On a tie, the first in order.
- `average`: for each discard, take every card the bot can't see (not in its hand) as a possible starter. Add up the kept hand's count with that starter (`show.hand` options, nobs included), and the discards' count with that starter (3 cards, `show.crib` options), added if the bot deals and subtracted if not. Highest sum wins; on a tie, the first in order. Sums, not averages, so every language agrees.

Play, by `peg`:

- `random`: one legal card chosen evenly (purpose `play`).
- `greedy`: the legal card that scores the most now. On a tie, the higher value (keeping low cards for late in a count), then the lower card ID.
- `careful`: for each legal card, its points now, minus the most the next seat could score with one card in reply, over every card the bot can't see. Highest wins; ties as `greedy`.

## Config

All files live in [`cribbage/minigames/config/`](config/) and carry a `version`. Values below are rules r28, as tuned on 2026-11-15, with the opening count added on 2026-11-16, prizes retuned and the opening bonus added and lowered on 2026-11-17, and the key joker added on 2026-11-17 (concept.md › Decisions). The engine MUST check config on load: weights are positive integers, ranges hold (`min` ≤ `max`), every kind a table names exists, and `epicAt` ≥ `rareAt`.

### rules.json

```json
{
  "version": 1,
  "rulesVersion": "match-r28",
  "scoring": { "fifteen": 2, "pair": 2, "runPerCard": 1, "flushPerCard": 1, "nobs": 1 },
  "match": {
    "maxSet": 4, "flushMin": 4, "timerSeconds": 180, "cardBudget": 0,
    "leftOverCost": 2, "starterJoins": true, "handFlush": true,
    "opening": {
      "hand": { "flushMin": 5, "handFlush4": true },
      "crib": { "flushMin": 5, "handFlush4": false },
      "bonus": { "from": 6, "per": 5 }
    },
    "maxEdgeCards": 1,
    "maxPick": 6,
    "clearBonus": { "kind": "steps", "amount": 10 },
    "edgePower": { "start": 0, "step": 1, "percentPerLevel": 10, "combine": "add", "capPercent": 0 },
    "prize": { "rareAt": 28, "epicAt": 34, "special": [["swapper", 45], ["bomb", 30], ["reach", 25], ["burn", 20], ["key", 10]] }
  },
  "game": { "turns": 3, "maxHands": 15 },
  "deck": { "shared": true, "minSize": 40 },
  "specials": {
    "known": ["swapper", "bomb", "reach", "burn", "key"],
    "start": { "swapper": 2, "bomb": 1, "reach": 1, "burn": 1 },
    "bombShape": "plus",
    "reach": { "cards": [[1, 85], [2, 15]], "seconds": [[10, 15], [20, 60], [30, 20], [45, 5]] },
    "key": { "cards": 1, "lasts": [["game", 25], ["timed", 75]], "seconds": [[10, 15], [20, 60], [30, 20], [45, 5]] }
  }
}
```

`starterJoins` (r16) makes the starter count with every set; missing means false, as in r15. `handFlush` (r18) adds hand flushes and the optional starter; missing means false, as in r17. `opening` (r24) counts the hand and crib before the grid plays, with classic show options (a hand flush needs its 4, a crib flush all 5); missing means no opening count, as in r23. `opening.bonus` (r26) gives a power joker for every `per` points a count scores past `from`; missing means none, as in r25, and when given `from` MUST be 0 or more and `per` 1 or more. `maxEdgeCards` (r24) is how many hand and crib cards one set may pick together; missing means no limit, and when given it MUST be 1 or more. `game.turns` (r23) is how many match turns a game has; missing means 1. `game.maxHands` is the most hands a game around the maze deals (The game around the maze); missing means 15, and when given it MUST be 1 or more. `deck.shared` picks one shared deck or one each; `deck.minSize` is the smallest a burn can leave the deck, and MUST be 25 or more. `maxPick` (r28) caps the pick limit, however many reaches and keys raise it; missing means no cap, and it MUST be given when `key` is a known special. `specials.key` (r28) is the key joker: the cards it adds, how often it lasts the game against a while (`lasts`, weights for `game` and `timed`, nothing else), and a timed key's seconds as for a reach. The key isn't in `start`, so a player gets one from a prize, an opening bonus or a reveal. A `cardBudget` of 0 means the whole stock. `timerSeconds` of 0 means no timer. Multipliers are whole percents (150 is ×1.5), so every language computes the same steps.

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
    "steps":   { "goes": "steps", "tier": "glint", "amount": 5 }
  },
  "tables": {
    "amber": [["card", 90], ["scoring", 9], ["item", 1]],
    "teal":  [["card", 80], ["scoring", 15], ["power", 5]],
    "title": [["five", 34], ["named", 33], ["steps", 33]],
    "blank": [["five", 34], ["named", 33], ["steps", 33]]
  },
  "madeMultiplier": [[105, 40], [110, 25], [125, 18], [150, 10], [200, 5], [300, 2]],
  "madeCapPercent": 300
}
```

Weights are lists of pairs, not objects, so their order is fixed in every language.

### bots.json

```json
{
  "version": 1,
  "match": [
    { "id": "perfect", "search": "all" },
    { "id": "strong",  "search": "traced", "depth": 4, "starts": 1.0 },
    { "id": "medium",  "search": "traced", "depth": 4, "starts": 0.3 },
    { "id": "weak",    "search": "traced", "depth": 3, "starts": 0.25 }
  ],
  "reachActions": 5,
  "classic": [
    { "id": "expert", "discard": "average", "peg": "careful" },
    { "id": "greedy", "discard": "hand",    "peg": "greedy" },
    { "id": "random", "discard": "random",  "peg": "random" }
  ]
}
```

`match` holds the match turn levels (see Bots), `classic` the classic game's (see Classic cribbage › Bots). `reachActions` is how many actions a reach or timed key lasts on a bot's own grid turn, since a bot has no clock (The game around the maze); missing means 5, and when given it MUST be 1 or more.

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

### classic.json

The classic game's numbers. Its scoring is its own copy, so tuning Crib RPG's `rules.json` never changes the baseline.

```json
{
  "version": 1,
  "rulesVersion": "classic-1",
  "target": 121,
  "deal": [
    { "players": 2, "cards": 6, "discard": 2, "toCrib": 0 },
    { "players": 3, "cards": 5, "discard": 1, "toCrib": 1 }
  ],
  "cutMin": 4,
  "scoring": { "fifteen": 2, "pair": 2, "runPerCard": 1, "flushPerCard": 1, "nobs": 1 },
  "show": {
    "hand": { "flushMin": 5, "handFlush4": true },
    "crib": { "flushMin": 5, "handFlush4": false }
  },
  "peg": {
    "maxCount": 31, "fifteen": 2, "thirtyOne": 2, "pair": 2, "runPerCard": 1,
    "go": 1, "lastCard": 1, "heels": 2
  }
}
```

The engine MUST check on load that each deal row fills the crib to exactly 4 (`toCrib` + players × `discard`), and that `target` is above 0. `peg.pair` is per pair, so a pair royal is 3 pairs (6).

### fx.json

Every client's cue motions and waits (from spec 3). The engine doesn't read it; what each value means, and how a spring maps to numbers, is in [ui.md](ui.md) › Motion. Sounds and haptics join it in Phase E (`ARCHITECTURE.md` › Presentation and effects).

```json
{
  "version": 1,
  "motions": {
    "board": {
      "select":     { "type": "easeOut", "ms": 120 },
      "pop":        { "type": "spring", "ms": 300, "bounce": 0.4 },
      "change":     { "type": "easeOut", "ms": 300 },
      "pick":       { "type": "spring", "ms": 250, "bounce": 0.15 },
      "helpText":   { "type": "easeOut", "ms": 200 },
      "stepsCount": { "type": "easeOut", "ms": 400 },
      "numberRoll": { "type": "spring", "ms": 500, "bounce": 0.15 },
      "stepsBump":  { "type": "spring", "ms": 260, "bounce": 0 },
      "stepsUnbump": { "type": "easeOut", "ms": 200 }
    },
    "hint": {
      "show":  { "type": "easeOut", "ms": 300 },
      "blink": { "type": "easeInOut", "ms": 500, "repeat": true }
    },
    "deal": {
      "card":    { "type": "spring", "ms": 300, "bounce": 0.2 },
      "throw":   { "type": "spring", "ms": 450, "bounce": 0.15 },
      "starter": { "type": "spring", "ms": 400, "bounce": 0.3 }
    },
    "breakdown": {
      "fade":      { "type": "easeOut", "ms": 300 },
      "setLeave":  { "type": "easeOut", "ms": 250 },
      "rowFly":    { "type": "spring", "ms": 500, "bounce": 0.18 },
      "banner":    { "type": "spring", "ms": 250, "bounce": 0 },
      "tally":     { "type": "easeOut", "ms": 200 },
      "tallyLine": { "type": "easeOut", "ms": 220 },
      "light":     { "type": "spring", "ms": 250, "bounce": 0 },
      "unlight":   { "type": "easeOut", "ms": 150 },
      "powerUp":   { "type": "spring", "ms": 300, "bounce": 0 },
      "totalFly":  { "type": "easeIn", "ms": 500 }
    },
    "clock": {
      "look":  { "type": "easeOut", "ms": 300 },
      "wedge": { "type": "linear", "ms": 1000 },
      "pulse": { "type": "easeInOut", "ms": 600, "repeat": true }
    }
  },
  "waits": {
    "breakdown": {
      "speeds": [
        { "name": "Slow", "ms": 1200 },
        { "name": "Medium", "ms": 900 },
        { "name": "Quick", "ms": 600 },
        { "name": "Practised", "ms": 400 }
      ],
      "beforeRow": 150,
      "rowBeat": 20,
      "beforeBanner": 650,
      "beforeTally": 900,
      "comboLitPercent": 88,
      "afterTotal": 500,
      "rowStagger": 50,
      "flyHome": 500
    },
    "board": {
      "pop": 340,
      "bombPop": 380,
      "settle": 320
    },
    "float": {
      "life": 1000,
      "keys": [180, 450, 270],
      "startScale": 0.6,
      "peakScale": 1.15,
      "startY": 12,
      "midRise": 18,
      "rise": 36
    },
    "toast": 2400,
    "deal": {
      "gap": 90,
      "throwToStarter": 550,
      "starterToTurn": 900
    },
    "clock": {
      "secondsFrom": 10,
      "warningPercent": 10,
      "urgencyPercent": [50, 25, 10],
      "halfBreath": [2000, 1400, 900, 550],
      "breathDepth": [0.05, 0.07, 0.10, 0.13]
    },
    "slowMotion": 5
  },
  "fill": {
    "card": { "type": "spring", "ms": 380, "bounce": 0.2 },
    "patterns": [
      { "name": "rain",    "order": "columns",  "gap": 70, "from": "above" },
      { "name": "deal",    "order": "rows",     "gap": 35, "from": "deck" },
      { "name": "spiral",  "order": "spiral",   "gap": 35, "from": "grow" },
      { "name": "wave",    "order": "diagonal", "gap": 70, "from": "grow" },
      { "name": "scatter", "order": "random",   "gap": 30, "from": "spin" }
    ]
  }
}
```

`fill` (spec 9) is the grid's first deal-in: its card motion, and the patterns one is picked from each turn (ui.md › The grid fills).

## Left-over warning

The warning shows once per player, ever, not once per turn. The engine treats `warned` as an input: the session passes it in when the turn starts (from the player's saved profile) and reads it back after. The event `leftoverWarning` tells the session to save it.

## Fixtures

Shared test cases live in [`cribbage/minigames/fixtures/`](fixtures/) as JSON. The JS tests (`node --test cribbage/minigames/`) and the Swift tests both read them.

| File | Cases |
|---|---|
| `counting.json` | A list of cards, options, and the expected combos (kind, size or multiplier, points, card indexes), total and left-over cards |
| `classic-hands.json` | Classic hands and cribs with known counts: 29, 28, 24, 0, his nobs (in a hand and a crib), a jack starter (no nobs), the hand and crib flush rules |
| `pegging.json` | Whole plays for 2 and 3 players: the hands, the cards in the order played, and every score (fifteens, pairs, a pair royal, runs played out of order, gos, 31s, the last card) |
| `dice.json` | For a few seeds and stream names: the first raw outputs, draws below n, weighted picks and a shuffle of 52, so every port matches the generator exactly |
| `records/*.jsonl` | Whole recorded games (Records), made by `cribmaze-sim record`. Replaying each from its seed MUST give the same rolls and events, and writing it again MUST give the same bytes, ignoring `at` |

Totals and combo counts in `counting.json`, `classic-hands.json` and `pegging.json` are worked out by hand; each case's note shows the sum. `make-counting.js` fills in the card indexes from the mock counter and stops if it disagrees with a hand-worked number. `make-dice.js` writes `dice.json` from the reference dice; rerun it only when Dice changes, and say so in the commit.

## Differences from the mock

The mock is a design tool, so it cuts corners the engine can't. These are engine decisions, not rule changes.

| Mock | Engine |
|---|---|
| `Math.random`, no seed | Seeded named streams; every draw recorded |
| Logs outcomes (cards scored) | Records actions, rolls and events, so turns replay |
| Crashed on 5 or more of a kind (fixed in the mock too) | Scores every pair in the group |
| The traced bots' starting cards and paths can include special jokers | The shuffled list holds playing cards only, so special jokers are never starting cards or on a path (bot results shift a little) |
| Starter "apart" and "touching off" settings | Not in the engine; r14 has the starter in the corner and touching on |
| "Good hand" setting | Fixed cards in a standalone turn |
| Epic at double the rare threshold | `epicAt` set in config (34) |
| Warning state kept in browser storage | A player profile input (see Left-over warning) |

## Open questions

1. A full Crib RPG round: where jokers go when dealt into a hand or the crib, cut as the starter or played in pegging. rules.md lists this as not designed.
