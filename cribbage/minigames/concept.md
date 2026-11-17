# Crib RPG: Concept

Status: concept, 2026-11-14. Working title. The match turn has been mocked and bot-tested (match rules r15); nothing else has been playtested or simulated, so most numbers here are starting guesses.

The player-facing rules are in [rules.md](rules.md). How we measure and tune the game is in [stats.md](stats.md).

## Summary

Crib RPG is cribbage made into a video game for iPhone. You still build a hand, throw to the crib and peg to 31, but your points move a token through a maze instead of a peg along a board. Scoring your hand becomes a match game played on a grid of cards. Prizes from the maze and from big matches add cards and powers to the game, so every game builds up differently.

One human plays against one or two bots. A game lasts about as long as classic cribbage.

## What we're making

A logical extension of cribbage, not a different game wearing cribbage's clothes. Everything a cribbage player already knows should still pay off: a good discard, careful pegging, spotting every fifteen in a hand. Each of those becomes something you play and watch happen, instead of something you add up and peg.

Three things change:

1. The pegboard becomes a maze. Points are still steps along a track, but the track forks, has gates and holds prizes.
2. Counting hands becomes a match game. Your hand and crib sit at the edge of a grid of cards, and you trace cribbage combos through them, like finding words in Boggle.
3. The deck grows during the game. Prizes add cards, powers and badges, and they reset when the game ends.

## Where the fun is

- Every peg moves you, right away. A fifteen isn't 2 points on a board; it's 2 steps that might carry you past a fork, or into a gate.
- Which card scores matters. A fifteen made with the 5♥ opens heart gates. Holding the right suit for the gate ahead is a new reason to keep or throw a card.
- Forks are a gamble: a shorter branch with a gate and a prize, or the long safe way round.
- The match board rewards the counting skill cribbage players already have. Every set is counted like a hand, so spotting a double run or a hidden fifteen pays, and you score only what you find.
- Edge cards power up as you use them, so a turn builds: a 5 in your hand multiplies every set it joins a little more, up to a cap. There's one score, steps.
- Every score plays out like counting a hand aloud ("fifteen 2, fifteen 4, a pair is 6"), so a big multi feels big.
- Each turn's best score wins a special joker, and special jokers are kept all game, so a good turn pays off later.
- Suits matter twice: a set's main suit decides which gates its steps can open, so a one-suit run is worth more than its steps.
- The shared deck is a gamble. A badge you put on the 5♥ helps whoever is dealt it next, maybe a bot.
- The race is visible. All tokens share one maze, like pegs on one board, so you always see who's ahead and which way they're going.

## A round

```
Round

  Title, Options, Start  once a game: players and bot levels, game length, timer, hints
  Cut for first deal ... once a game: the lowest card deals first
  Deal and discard ..... as in classic cribbage (2 or 3 players); untimed
  Cut the starter ...... a Jack gives the dealer 2 steps (his heels)
  Match turns .......... the scoring grid, one per player, in show order: bots'
                         results first, as a sequence, then yours
  Shop ................. after the scoring grid, before pegging
  Pegging .............. on the maze: classic play to 31, each point a step; grid
                         points open gates, hit switches and shift the maze;
                         grid power multiplies pegging
  Next round ........... the deal passes left; hands repeat until a player
                         exits the maze
```

Classic rule wording comes from Scorekeep's page, `~/projects/utilities/scorekeep/docs/rules/cribbage.md`. Scorekeep covers 2 players only, so the 3-player deal is defined in our rules.

## Phases

Every phase of a game, in the order a player meets them, and which of them make the first version (v1). This is the one list to iterate on: rules.md, ui.md and engine.md describe each phase, and point here for the order and the target (Bruce, 2026-11-17). A phase is a stage of the round (rules.md › How a game fits together) or one step of the match turn.

```
Phases of a game

  Once a game
    1  Title and options ..... players, bot levels, game length, timer, hints
    2  Cut for first deal .... the lowest card deals first

  Every round
    3  Deal and discard ...... 6 cards, sort them, throw 2 to the crib
    4  Cut the starter ....... a jack gives the dealer 2 (his heels)
    5  Match turns ........... one per player, in show order
         5a  Bots' turns ...... a quick sequence of results, hands face down
         5b  The show ......... your hand, then your crib if you dealt, counted
                                as in cribbage; a big count wins power jokers
         5c  Grid intro ....... the game's first turn only: what the grid is
                                for; Start deals the grid and starts the clock
         5d  The grid ......... trace sets, use power jokers, until the clock,
                                a cleared board or no sets left
         5e  Turn end ......... the best set wins a prize; the turn summary
    6  Shop .................. spend on jokers and discovered cards
    7  Pegging on the maze ... players take turns walking the sets they made
                               on the grid (their plays), choosing which to play;
                               junctions, doors, switches and jokers are the choices
    8  (merged into 7) ....... the maze walk is the pegging (2026-11-17)
    9  Next round ............ the deal passes left

  Game end ................... a token exits the maze (the beta: after 3 turns)
```

| # | Phase | Specs | In the beta now (0.21.1) | v1 target |
|---|---|---|---|---|
| 1 | Title and options | concept.md › A round | Settings panel only (Game tab: Restart game); no title screen | Yes |
| 2 | Cut for first deal | rules.md › Setup; engine.md › Classic | No: the first dealer comes from config, then the deal alternates | Yes |
| 3 | Deal and discard | rules.md › 1; ui.md › Scene: Deal | Yes: 2 players, drag to sort, pick 2 for the crib, the discard hint | Yes |
| 4 | Cut the starter | rules.md › 2 | Partly: the starter is dealt with the hand; no cut, no his heels | Yes, with his heels |
| 5a | Bots' turns | rules.md › 3 | No: the bot discards, but plays no grid turn | Yes: the scoring phase summarizes the bots' scores; bots don't play their grid turns out on screen |
| 5b | The show | rules.md › 3 › Setting up; engine.md › The opening count; ui.md › The opening count | Yes (r24), with the opening bonus (r26, from 6 in r27) | Yes |
| 5c | Grid intro | ui.md › The opening count | Yes, on a game's first turn only (0.20.1) | Yes; wording to iterate |
| 5d | The grid | rules.md › 3; engine.md › Match turn; ui.md › Scene: Match turn | Yes (r27) | Yes |
| 5e | Turn end | rules.md › 3 › Ending the turn; ui.md › Scene: Turn summary | Yes: prize tier, summary, next turn | Yes |
| 6 | Shop | rules.md › 4 | No; not designed | Yes |
| 7 | Pegging on the maze | rules.md › 5 (to rewrite); concept.md › The maze walk | No; `mocks/maze-board.html` v2 drifted (play to 31, a points pool) and is to be reworked | Yes: players take turns walking their grid sets as plays, chosen from a list of cards and steps, as in `mocks/maze-walk.html` |
| 8 | Maze walk | Merged into 7 (2026-11-17) | | Smart choices decide it: which play to make, where to turn, which jokers to play, which doors to close |
| 9 | Next round | rules.md › 6 | Yes, as the next of 3 turns: the deck carries over, the deal alternates | Yes |
| | Game end | rules.md › Winning | After 3 turns (r23), with your steps in the summary; no winner yet, since the bot plays no grid turn | Yes: the first token to exit the maze |

The first version includes every phase (Bruce, 2026-11-17). The order of work (Bruce, 2026-11-17):

1. Playtest the grid (5b to 5e).
2. Prototype pegging on the maze and the maze walk together (7 and 8), as a browser mock first, like `mocks/maze-walk.html`, to work out the turns and choices quickly; the beta follows once it plays well.
3. Prototype the shop (6).
4. Prototype the cut and the bots' turns (2, 4 and 5a).

The two halves of a round play differently. The scoring phase (5) is solitaire: you play your grid, and the bots' scores are summarized. The maze phase (7 and 8) takes turns, player by player, and hinges on smart choices: where to turn, which jokers to apply, which doors to close. Record each change of scope in Decisions and change its row.

## The maze

The maze replaces the pegboard. A pegboard is a track where every point moves you one hole; the maze is that track with forks, gates and prizes.

The maze's mechanics will change: it becomes more of a board game, with circular paths (decided 2026-11-15). What follows is the first draft. Its place in the round stays the same, and a game still ends when a player exits the maze. Game length comes from the maze's size, its circular paths and its gates, not from a turn count.

```
Maze sketch (real mazes are generated)

  Start . . . . + . . . . . . . . + . . . . Goal      main route
                .                 .
                . . P . . ♥ . . . .                   a branch

  + fork   P prize cell   ♥ ♠ ♦ ♣ suit gate
```

- A game runs 5 to 13 hands. The maze's size, circular paths and gates are scaled to that (decided 2026-11-15; the 61 and 121 step routes were the first draft).
- Branches leave the main route at a fork and rejoin it later. A branch may be shorter or longer, and it may hold gates, prizes or traps.
- Suit gates open only for steps scored by a card of that suit. Steps that hit a gate of the wrong suit bounce you back. Special doors stop you instead.
- Fog hides the maze beyond a few cells of each token. Cells anyone has seen stay revealed.
- The maze is shared. All tokens race the same routes and may stand on the same cell.
- Every maze MUST always keep an open route from start to goal.
- The game ends the instant a token reaches the goal.

Door types, branch rules, traps and the maze generator get their own design phase (see Plan).

## Match turns

Each player takes one match turn, in classic show order. Since r24 it starts with a classic count of the hand and the crib, then the grid deals in. The full rules are in [rules.md](rules.md) section 4; this is the shape and the reasons.

```
Match board (one player's turn)

  Steps ............................ Deck
  . . . .   C       .  grid card, from the stock
  . . . .   C       H  your hand, along the bottom
  . . . .   C       C  the crib, down the side (dealer only)
  . . . .   C       S  the starter, in the corner
  H H H H   S
```

- The stock is every card not in a hand, the crib or the starter (39 cards with 2 players, 35 with 3), shuffled fresh for each turn.
- You trace sets of 2 to 5 touching cards, like words in Boggle. A set scores at once if every card is part of a cribbage combo, counted like a hand. A card left over costs steps, after a one-time warning, so guessing has a price.
- The hand and crib are counted once, as a classic show, before the grid deals in (r24). On the grid a set picks at most one hand or crib card, so they can't be counted again. The hand you built is what your sets grow from, and the cards beside it decide how well it does.
- Scored grid cards clear and the stock refills. Edge cards stay and power up.
- Special jokers (swapper, bomb) are the only way to change the board. They're scarce and kept all game.
- Edge power multiplies the steps of the sets an edge card is in (r15), so the hand you kept grows in value as the turn goes on. The multiplier is capped, so it can't run away.
- Steps move your token after the turn, in a short walk with choices (see The maze walk).
- The turn ends on a timer, a card budget, an empty stock, or when you choose.

Why it works this way, from the mocks:

- Automatic line matching (match-3 style) played itself: cascades used the stock in 2 or 3 swaps. Tracing sets puts every score in the player's hands.
- Free swaps meant you could always make something. Making swaps cost a special joker keeps the board a puzzle.
- When hand cards could score alone, or touched every other edge card, the hand was either everything or nothing. Real neighbours and the grid-card rule make position matter.

## The maze walk

Notes for a mini game not designed yet (2026-11-14). After a match turn, your scored sets become steps in the maze, and you walk them with choices where there are any.

- Each scoring set is a bundle of steps with a suit (the set's most common suit). Pegging steps already carry the suit of the card that scored them.
- You choose which bundle to spend next (decided 2026-11-14), so a heart bundle can be saved for the heart gate. The mechanics need thinking.
- It should feel like a party board game: each bundle is like a dice roll you already hold, and the fun is choosing where it takes you. Choices at forks, cells that do something when you land on or pass them (prizes, gates, doors), and maybe special jokers played on the board.
- Doors absorb steps. A big bundle can knock down a door; the steps spent on it don't move you.
- If there are no choices to make, the walk plays itself, quickly.
- Players take turns on the maze, unlike the scoring phase, where the bots' scores are only summarized (Bruce, 2026-11-17). Each turn is a set of choices: where to turn, which jokers to apply, which doors to close on the others.
- Open: can you hold steps back for a later round? Must you land exactly on a cell to trigger it? How long can the walk take before it drags?

## Transitions and effects

Each part of a round is its own mini game, so moving between them, and starting and ending each one, needs its own moment. The match turn's begin and end effects are mocked (match turn mock v8, 2026-11-14); transitions between mini games wait until the other mini games are designed.

```
A round, as the player sees it

  Deal and discard
    > transition: the crib slides to the dealer, the starter is cut
  Match turn
    begin ... cards fall into place
    end ..... board cleared, or not
    > transition: the shop
  Shop
    > transition: the grid's points carry over to the maze
  Pegging on the maze, with the grid's points spent on gates, switches and shifts
    > transition: the deal passes left
```

Transitions:

- Every change of mini game gets a short transition that carries something across, so the player sees what links them: the step total flying from the match board to the maze, for example.
- Transitions are skippable and speed up as the player learns, like the score breakdown.

Begin, end and bonus effects:

- Match turn begins: the grid deals in from the deck, cards falling into place column by column, then the hand, crib and starter slide to the edges.
- Match turn ends: it looks and feels different if you cleared the board (every grid card scored, nothing left) than if time, the budget or the stock ran out. Clearing the board is a big moment and earns a clear-board bonus (size to tune); running out is a quiet wrap-up.
- Bonus effects mark the high points: a big multi, the turn's best score, a prize, a door knocked down, a gate opened.
- The score breakdown is the bonus effect for every score.

## Deck building and prizes

Prizes come from prize cells in the maze and from the match board (a special joker for each turn's best score). Between rounds, the shop sells jokers and any card the player has discovered in any game (what it costs is open, since pips were removed in r15). Everything lasts for one game.

| Prize | Example |
|---|---|
| Card | An extra standard card, like a third 5♥ |
| Special joker | A wild joker (any rank and suit); a skeleton key (any suit at a gate) |
| Power | Kept in a power slot: re-cut the starter, peek at a crib card |
| Addition | A badge on one card: +1 step whenever it's part of a fifteen |

There's one shared deck, so prizes work on two layers:

- Deck layer: cards and badges added to the shared deck help whoever is dealt them. A scoped badge shows its owner's picture and works only for them.
- Player layer: powers and saved cards you keep for yourself, in power slots.

Which prizes go to which layer, and how they balance, is open.

## Hints

Hints nudge a player who seems stuck. The app has the hooks (`apps/apple/Shared/Hints.swift`): each hint is a case with a rule for when it shows, and the place it points at blinks. The first one blinks the power jokers when no sets are left.

Next is the discard, which is untimed (decided 2026-11-15). Ideas under discussion:

- When: only after the player hesitates (say 8 seconds), or on request, never by default.
- What: highlight the 2 cards a strong player would throw, and say why in one line ("keeps a double run; a 5 is good in your own crib").
- How it's worked out: score every way to keep 4 of the 6 (15 ways) over every possible starter (46), plus a crib estimate, as classic discard advice does. That's the classic value, not the grid value: the grid also uses grid cards and edge power, so check how well one predicts the other first (stats.md › Other stats, "Does the hand still matter?").
- Levels: off, subtle (blink after a pause), coaching (explain each choice). A setting, on Options; subtle is the default (decided 2026-11-15).

Classic advice against grid play (2026-11-15, `cribmaze-sim discard`, non-dealer, medium bot, 300 paired samples a keep; grid gaps under about 6 steps are noise). The classic value is the hand's mean count over the 46 starters; the grid value is mean steps a turn.

| Deal | Classic's best keep | Grid's view | What it shows |
|---|---|---|---|
| 5♥ 5♣ J♦ Q♠ 3♣ 9♥ | 5 5 J Q (12.7) | Ties with 5 5 J 3 (338 vs 343). 5 5 3 9 is classic's 10th but the grid's 6th | Keep the 5s: they make fifteens with every grid ten |
| 4♥ 5♣ 6♦ 6♠ K♣ 9♦ | 4 5 6 6 (15.4) | Agrees (351, clear first). 6 6 K 9 drops from 8th to 13th | Runs need their middle cards; the grid can't supply them reliably |
| 2♥ 4♥ 8♥ Q♥ 5♣ K♠ | 4♥ Q♥ 5♣ K♠ (6.7) | Agrees on first, but the heart flush (classic 2nd, 6.3) is the grid's 12th (220 vs 261) | A hand flush is a one-off 4 points; flexible cards score again and again |
| A♣ 2♦ 3♥ 7♠ 8♠ 9♦ | A 2 3 9 (8.1) | The top 6 keeps are all within noise (276 to 281) | When classic values are close, the grid doesn't care |

So classic advice is a good guide, except that it overrates hand flushes and underrates 5s.

#### Discard principles

Hints show a principle and the cards it's about, never the cards to throw (decided 2026-11-15): we don't know the game's balance well enough to coach, and classic cribbage knowledge may not carry over. Each principle has to earn its place with data. The code is `engine/swift/Sources/CribMaze/Principles.swift`; the measured worth is in `config/hints.json`, and a hint shows the applying principle worth the most, if it's worth at least `minWorth` (5 steps).

| Principle | Hint | Applies to | Worth on the grid | Best keep follows it |
|---|---|---|---|---|
| Two ways | "These cards score two ways, in a run and a fifteen. Both pay every time." | 28% of deals | +41 steps | 82% |
| Keep 5s | "Keep your 5s: every ten-card on the grid makes 15 with them." | 42% | +31 | 91% |
| Connectors | "Hand cards power up each time they score. Keep the ones that combine most." | 81% | +24 | 83% |
| Run middles | "A run needs its middle cards. The grid won't fill them for you." | 36% | +20 | 88% |
| Don't chase the flush | "A flush scores once. Cards that combine score again and again." | 12% | −3 (not shown to pay) | 86% |

Worth is the mean grid steps a turn of the keeps that follow the principle, less the keeps that don't, per deal (2026-11-15, match rules r20, `cribmaze-sim principles`, 240 random deals, 16 grid samples a keep, medium bot, non-dealer). The flush principle isn't shown until playtests or a bigger run prove it. Next: playtest the hints on the deal screen and compare people's keeps with and without them.

## Bots

Bots are full players. They win prizes, fill power slots, shop and add to the deck exactly as the human does. Their match turns aren't played out on screen; the player sees each result. Each bot decides its discard, pegging, forks, which sets to trace, when to use special jokers, and prize use.

Bot skill runs on a gradient from imperfect to perfect, like a depth-limited search. On the match board a perfect bot checks every set; lower levels trace paths from fewer starting cards and to a shallower depth, as a person does. We tune the levels so a medium bot scores about what a person does, from playtest runs. Other limits may come later. For the whole game we also plan random legal moves (for testing) and planning (looks ahead). In the simulator the human seat is just another bot.

## Later ideas

These are parked, not dropped:

- Endless mode: the maze keeps growing and the score is how far you get. It needs a way to end.
- Claiming missed sets: other players score sets you didn't find, like muggins. The engine logs the best sets left on the board so this can be added later.
- Sets longer than 5 cards (long runs and big fifteens from small cards). Scoring already handles them; the match turn caps sets at 5 until scores are tuned.
- More special jokers beyond the swapper and bomb.
- Other mini-games from the first round of ideas, in [ideation.md](ideation.md).

## Learnings

What the mocks and bot runs have taught us so far. Details and numbers are in [mocks/README.md](mocks/README.md).

1. The match board makes far more points than a cribbage hand. A greedy bot scores 70 to 110 steps per match turn (r6), against a classic count of about 8 to 10 for the same hand and crib. A person will score less than the bot, but probably still several times a classic hand.
2. Capping set size helps less than expected. Even 3-card sets score 5 to 9 times the classic count, because the grid offers so many chances.
3. Each touching rule we tightened (every set needs a grid card, real neighbours for hand and crib, the starter in the corner) cut scores by 10% to 25% and made the hand matter more.
4. Prizes for "a score of 8 or more" come on almost every score once sets are counted like hands, so they don't feel special yet.
5. The maze can absorb big scores (2026-11-14). Doors that take steps to knock down let a player score very well on the match board without running away in the maze. The match board can stay generous and fun, and the maze sets the pace. This changes the target: we don't need match scores near a classic hand, only a maze that turns them into the right distance. Pegging steps count against doors too, and damage stays, so doors are shared obstacles.
6. Players need to see why they scored. The score breakdown counts each set aloud, part by part, starting slow and speeding up as they learn.
7. Bot skill is mostly search depth. Limiting how many cards a bot traces changes its score far more than limiting where it starts (r7: perfect 123 steps per turn, depth 4 about 77, depth 3 about 55).
8. Playing out the board makes clearing it common for bots (r8). With no timer, a perfect bot cleared the board in 9 of 10 turns, medium in 10 of 10 and weak in 7 of 10, partly by bombing cards left alone. Turns grew by about half (perfect 183 steps, medium 132, weak 79, the 10-step bonus included). A clear-board bonus only feels big if clearing is hard, so the timer or a tighter rule must make it so.
9. Many sets carry no suit. Ties left 40% of a perfect bot's steps without a suit, 23% of a medium bot's and 52% of a weak bot's (r8). Suit gates will bite hard unless players chase one-suit sets on purpose.

## Working title

The game is Crib RPG (Bruce, 2026-11-16), also known as Noddy Yookerspiel (the Mac beta) or Crib Jokers. It was Crib Maze until then, and code names keep that: the `CribMaze` target and package, `CribMazeGame`, and the record ID `crib-maze`, since records and ports depend on them. Crib RPG still needs a name search before it is used publicly. The options weighed before (none checked against existing games or App Store names):

| Name | Why it might work |
|---|---|
| Crib Maze | Plain and clear: says what it is (the working title until 2026-11-16) |
| Cribyrinth | A pun on labyrinth; memorable, a little silly |
| Warped Crib | Fits the warped family of projects; hints that the rules bend |
| Fifteen Two | The first words of every cribbage count; players will know it at once |
| Pegway | Pegs plus pathway; short, works as an app name |
| Heels and Hallways | His heels plus the maze; playful, longer |
| Thirty-One Ways | The pegging count plus routes through the maze |
| Crooked Crib | A crib board that doesn't go straight |

Before the choice, we leaned toward Fifteen Two or Pegway for an app name, with Crib Maze as the descriptive subtitle.

## Decisions

| Date | Decision |
|---|---|
| 2026-11-13 | iPhone app first; maybe iPad and Mac later (the first build is a Mac beta for testing, decided 2026-11-14; iPhone is still the players' app) |
| 2026-11-13 | Rules in Markdown first; engine and simulator in Python; Swift app built later from the specs (superseded 2026-11-14: engine and simulator in Swift) |
| 2026-11-13 | 2 or 3 players: one human, the rest bots. Bots play by the same rules as the human |
| 2026-11-13 | Fixed structure: maze replaces the pegboard, match turns replace counting |
| 2026-11-13 | Pegging is classic; each point is a step, moved as it's scored |
| 2026-11-13 | Maze has branches, prizes, suit gates, shifting walls and fog; one maze shared by all tokens |
| 2026-11-13 | One shared deck; prizes on a deck layer and a player layer |
| 2026-11-13 | Everything built lasts one game |
| 2026-11-13 | Badges help whoever holds the card, unless scoped to a player |
| 2026-11-13 | Wrong-suit gates bounce you back; special doors stop you instead |
| 2026-11-13 | Match turns: hand along the bottom, crib along the side, grid from the stock |
| 2026-11-14 | Edge cards are never used up; they power up, and power lasts the turn |
| 2026-11-14 | Hand and crib score as classic patterns only when the player marks them (superseded the same day: there is no marking; sets are traced and every set needs a grid card) |
| 2026-11-14 | Match turns run until the stock is used; a timer and card budget cap them, set by simulation. The player may also end the turn |
| 2026-11-14 | Claiming missed patterns is parked for later |
| 2026-11-14 | The app may send game logs as opt-in data (superseded the same day: only the beta app records games; release builds don't send logs for now) |
| 2026-11-14 | Stats exist mainly to compare scoring curves between bots, and to measure timing |
| 2026-11-14 | First mocks are clickable HTML in an iPhone frame, covering pegging on the maze, a match turn and a prize pick |
| 2026-11-14 | Cards: standard layout (rank in two corners, one large centred suit), rank and suit in the suit's colour, near-white faces only (no dark faces). Built on Scorekeep's card kit; its short form (one rank, one suit) is for documentation. Mock: [design/cards](../../design/cards/index.html) |
| 2026-11-14 | Card size will adapt to the screen in the app (tuned later); mocks use 64 pt |
| 2026-11-14 | Four-colour suits at 4.5:1 or better: spades #000000, hearts #E00000, diamonds #0070E0, clubs #00843D |
| 2026-11-14 | One back for now (Scorekeep's crosshatch); more backs get their own design phase |
| 2026-11-14 | Match turn plays like Boggle: trace touching cards; a valid cribbage combo scores automatically, anything else does nothing. Replaces automatic line matching (see [mocks](mocks/README.md)); rules.md section 4 gets rewritten once the mock settles |
| 2026-11-14 | Match board: hand, crib and starter can't score on their own; every set needs a grid card. Edge row and column sit apart from the grid with an empty corner; the starter sits beside the step counter (corner and starter superseded by the r6 row below) |
| 2026-11-14 | Match board sets count like cribbage hands: every fifteen, pair, run, flush and his nobs inside the set scores (8-6-A is a fifteen). Every card must be part of a combo. Scoring levers to follow (see [mocks](mocks/README.md)) |
| 2026-11-14 | Match board touching: every card, hand and crib included, touches only its real neighbours. The starter sits in the corner where the hand row and crib column meet (match rules r6). Word tags name the hand, crib and starter |
| 2026-11-14 | Every score plays as an overlay, part by part: set name, each combo with its points and a running total, bonuses, edge power, total. Steps start slow and speed up; the base speed becomes a player setting that quickens as they learn (now part of the [match turn mock](mocks/match-turn.html)) |
| 2026-11-14 | Every set is a single (one combo) or a multi (two or more); both are labelled in scoring and stats. Sets stay at 5 cards for now |
| 2026-11-14 | Maze doors take steps to knock down, so the maze absorbs big match scores. Match scores can run high; the maze sets the pace |
| 2026-11-14 | Rules doc draft 3: match turns rewritten for match rules r6 |
| 2026-11-14 | Licence: MIT |
| 2026-11-14 | Edge power pays into a separate tally ("pips", name confirmed the same day), not steps. Pips buy jokers and special jokers between rounds (match rules r7) (superseded the same day by r15: no pips; edge power multiplies steps) |
| 2026-11-14 | One prize per match turn, for the turn's best score (r7) |
| 2026-11-14 | Special jokers are kept all game; more can be bought between rounds with pips (pips superseded by r15; the shop's currency is open) |
| 2026-11-14 | A non-dealer's crib column stays empty: the crib is the dealer's advantage |
| 2026-11-14 | The timer pauses while a score breakdown plays (r7) |
| 2026-11-14 | Bot match turns show only their result |
| 2026-11-14 | Match-turn steps carry the set's most common suit at suit gates (ties: see below) |
| 2026-11-14 | Door damage stays between turns; a broken door is open for everyone; pegging steps count against doors |
| 2026-11-14 | Steps move the token after the match turn, in a maze walk with choices (a mini game, not designed yet) |
| 2026-11-14 | Prize cards and badges in the shared deck can turn up in any player's match grid |
| 2026-11-14 | Bot skill is a gradient from imperfect to perfect, like a depth-limited search; other limits may follow |
| 2026-11-14 | The bonus tally is called pips (superseded by r15: no pips) |
| 2026-11-14 | In the maze walk, the player chooses which set's steps to spend next; it plays like a party board game, with choices (mechanics to come) |
| 2026-11-14 | Each mini game gets transitions between it and the next, and begin, end and bonus effects; the match turn begins with cards falling into place and ends differently when the board is cleared. Future mocks |
| 2026-11-14 | Suit ties: when two or more suits tie for most common in a set, its steps carry no suit and can't pass suit gates. Rewards one-suit sets |
| 2026-11-14 | Clearing the board earns a bonus as well as its own ending (size to tune) |
| 2026-11-14 | When the stock or card budget runs out, the player plays out the grid that's left; nothing refills. Clearing every grid card ends the turn with the clear-board bonus. The turn no longer ends on an empty stock or a used budget (match rules r8) |
| 2026-11-14 | When no set on the board can score, the game says so and points to special jokers or End turn |
| 2026-11-14 | Every set shows its suit (or "no suit") in the score breakdown, the feed and the turn summary |
| 2026-11-14 | The score breakdown is merged into the match turn mock; the separate mock is retired |
| 2026-11-14 | Special jokers and pips carry over between match turns all game (specced in rules.md; the mock resets the tray each turn, and a multi-turn mock waits until it's needed) (pips superseded by r15) |
| 2026-11-14 | Clear-board difficulty waits for human playtests: bots clear the board in most turns, but a person under the timer may not |
| 2026-11-14 | Tied sets keep "no suit" for now; measure how often ties happen in playtests before changing the rule |
| 2026-11-14 | A set with a card left over doesn't score. The first one brings a one-time warning that explains valid sets; after that, each card left over costs 2 steps (to tune), and the turn's steps never go below 0 (match rules r9) |
| 2026-11-14 | Cards left over score against you: a set scores its combos minus 2 steps per card left over, after a one-time warning, and a turn's steps can go below 0 (match rules r10, replacing the r9 rule that left-over sets score nothing) |
| 2026-11-14 | While tracing, every selected card looks selected; cards in a combo light up more (bigger, brighter), so a dim card is one that would be left over |
| 2026-11-14 | Swiping picks a card only near its centre, so diagonals are easier; how near is a setting (70% by default) |
| 2026-11-14 | The deck holds 2 jokers plus the title card and a blank card. Drawing one pauses play and explains it: a joker becomes a special joker for the tray; the title and blank cards roll for an outcome (a card for the board, a special joker, another prize). Prizes to come (match rules r11) |
| 2026-11-14 | Jokers get their own mock until they feel right. Two joker types, amber and teal, each with a small table of chances to become one of its kind: amber 90% a card, 9% a scoring card, 1% an item; teal 80% a card, 15% a scoring card, 5% a special joker for the deck (all to tune) |
| 2026-11-14 | Joker chance is felt, not read: players never see the tables, the odds or the list of outcomes. They see randomness (shuffle, wheel or die), the prize, and the prize landing where it goes (board, deck or tray). Reveals grow with rarity. Jokers are named with a hint the first time only. Reveals are skippable. No record of found prizes. The fun is discovering the balance as a player, and making it as the game maker |
| 2026-11-14 | Joker reveals join the match turn (match rules r12). The amber and teal jokers replace the placeholder joker, and the title and blank cards use the same hidden-table reveal with placeholder prizes. A joker that becomes another extra card chains into its next reveal. The reveal code is shared by both mocks (`mocks/reveal.js`) |
| 2026-11-14 | "Joker" is a concept: a card outside the standard 52 that does something. Each joker is one kind. The swapper and bomb are special jokers (they were "special cards"); the amber and teal jokers turn into prizes; the any-rank prize is a wild joker |
| 2026-11-14 | The shop sells jokers, and any card the player has discovered in any game they've played (won, or seen in a reveal). The game reveals itself over hundreds of full games. There's still no collection screen; what a player has discovered shows up as shop stock |
| 2026-11-14 | A special joker from the teal joker is shuffled into the current turn's stock, not saved for the next round (match rules r13). Drawn onto the board, it waits there until the player taps it to use it, and it can't be part of a set (r14) |
| 2026-11-14 | How many jokers a round has is decided when the deck is shuffled: 0 to n (n to tune). Jokers never expire, and each player uses each joker once a round, since each player plays their own match turn (match rules r14) |
| 2026-11-14 | What a joker makes lasts by kind: cards it makes (a card, a scoring card, a 5) are new cards kept in the deck for the rest of the game; special jokers made by a reveal last only for that round. Each special joker type gets its own rules, balanced from stats later (r14) |
| 2026-11-14 | The game's structure has names: a game is made of rounds, a round of stages (deal and discard, cut, pegging, match turns, shop), a stage of turns. A minigame replaces a classic cribbage step; the match game is the first (rules.md › How a game fits together) |
| 2026-11-14 | Special actions come from special jokers: smaller cards in a tray at the bottom, stacked by type, in limited supply. First two: the swapper joker (reverses a line of grid cards; swapping is no longer a free action) and the bomb joker (blows up cards) |
| 2026-11-14 | The first app is a Mac beta for playing, testing and tuning; iOS follows from the same code. Gameplay is a Swift package with no UI, and game tracking (GameRecord) is a separate component linked only into the beta ([ARCHITECTURE.md](../../ARCHITECTURE.md)) |
| 2026-11-14 | One score (match rules r15, from Bruce's playtest): pips are gone. Edge power multiplies the steps of the sets an edge card is in: add the levels of a set's edge cards, ×1.5 a level (1 + 0.5 each), capped at ×2, rounded; cards left over aren't multiplied. Uncapped, bots ran away (medium bot 1,049 steps a turn against 151 with no edge power; perfect 3,963 against 188); with the ×2 cap, 243 and 353. The shop's currency is open |
| 2026-11-14 | Engine and simulator are Swift, replacing Python; engine specs are written to port, and numbers and tables the code needs live in JSON config files |
| 2026-11-14 | Only the beta app records games; release builds don't record or send logs for now |
| 2026-11-14 | Swift stack agreed: Apple frameworks only, Swift Testing, macOS 26 and iOS 26, two app targets (beta and release), SwiftUI and Metal shader effects. Beta is local builds on the Mac; TestFlight comes with iOS ([LIBRARIES.md](../../LIBRARIES.md)) |
| 2026-11-14 | The maze plays like Labyrinth: you move through it until you reach the goal. A short game is 61 steps and a long one 121; you get there by stepping that many times, or by winning items that jump you steps ahead |
| 2026-11-14 | Mazes are generated from the game's seed, the same seed that drives the shuffle, so changing the seed shows another maze. The maze walk mock works this way from the start |
| 2026-11-14 | Pegging moves your token on the maze as each point is scored (confirms 2026-11-13), so pegging matters on the board |
| 2026-11-14 | Maze visual goals: every cell reads as part of a grid (at least subtly); start and goal are clear; doors are clearly doors; walls are clear. The art stays simple but must be clear ([mocks/README.md](mocks/README.md) › Maze walk) |
| 2026-11-14 | The steps you walk are called plays: each pegging score or scored set is one play. On the maze, players take turns making plays, as in pegging: the seat after the dealer goes first, a player with no plays left says go, and the others keep playing |
| 2026-11-14 | Bouncing off a gate of the wrong suit costs one step; the rest of the play walks back the way it came. This also means every play ends, even between two gates of other suits |
| 2026-11-14 | Shifting walls are removed for now (supersedes 2026-11-13). The maze stays fixed, so with a scrolling view the route from start to goal is always a known number of steps |
| 2026-11-14 | The scale problem (match turns score far more steps than the route is long) is deferred; the maze walk mock keeps its settings for trying fixes later ([maze-inspiration.md](maze-inspiration.md) › Ideas) |
| 2026-11-14 | The look is vector arcade: neon lines on near-black (look C of [mocks/maze-retro.html](mocks/maze-retro.html)), for cards, jokers and the maze. The asset set lives in `design/neon/`, tracked in its gallery pages; mocks and the app switch over once each part is confirmed |
| 2026-11-14 | Cards keep their original faces (`design/cards/cards.js`) over the neon colours. Neon cards were far too hard to read; neon stays for the table, board, tray, maze and effects |
| 2026-11-15 | The starter counts with every set, as in a cribbage hand, so it's pivotal again (match rules r16). It isn't traced and doesn't count toward a set's cards; it scores, multiplies and powers up only when it's in a combo, and is never left over. It sits on a lighter bed. Medium bot, 2,000 dealer turns: 252 steps a turn under r15, 363 under r16, and every turn ends with an epic prize, so the prize thresholds and edge power need retuning |
| 2026-11-15 | Crib Maze Beta is the match turn mock; `match-turn.html` is frozen at r16 and gets no more changes. New match turn work goes into the beta only |
| 2026-11-15 | A set still needs 2 picked cards: one card plus the starter isn't a set |
| 2026-11-15 | Tuned for r16: edge power capped at ×1.5 (was ×2), prizes rare from 25 steps and epic from 31 (were 8 and 16). Medium bot, 1,000 dealer turns: 284 steps a turn (r15 was 251, r16 at ×2 was 361), prizes 59% common, 27% rare, 14% epic (was 100% epic). Non-dealer medium: 235 steps, 69/19/12. Weak dealer: 183 steps, all common. Strong dealer: 358 steps, 98% epic. With no edge power at all, 197 steps. The starter is in 84% of scored sets |
| 2026-11-15 | The match turn timer defaults to 180 seconds (was 90) |
| 2026-11-15 | No End turn button: a turn ends on the timer, a cleared board, or a board with no sets left (after 25 seconds while power jokers could still help). The power jokers panel fills the width, with empty slots for kinds not found yet. The turn's log and the help line leave the game view |
| 2026-11-15 | A set picks 2 to 4 cards (was 5), plus the starter (match rules r17). The medium bot was already searching 4 deep, so its numbers didn't move (284 steps a dealer turn); strong fell from 358 to 257, below medium. Bots re-spaced: strong searches 4 deep from every start, medium 4 deep from 30%. Dealer, 500 turns: strong 284 steps (prizes 57/29/14), medium 271 (63/25/12), weak 183 (all common), perfect 263. Prize thresholds unchanged. Depth 3 can't reach a rare prize |
| 2026-11-15 | Flushes count like a classic hand (match rules r18): 4 picked cards of one suit score 4 whatever the starter, 5 with a matching starter, and there are no 3-card flushes. The starter is optional, so it never costs a set points. Before, the joining starter made off-suit 4-card flushes impossible. 1,000 turns, seed 1, dealer: flushes rise from 2.8% to 8.9% of medium-bot scores (9.3% strong); mean steps a turn go from 274.4 to 276.7 (medium) and 286.2 to 287.7 (strong); prizes barely move (medium rare 27.5%, epic 13.5%). The weak bot sees 4-card flushes only (7.7% of its scores) and still wins only common prizes |
| 2026-11-15 | New power joker, the reach (match rules r19): it raises the hand size (the cards a set can pick) for a while, rolled from config (+1 card 85%, +2 15%; 20 s 60%, 10, 30 or 45 s otherwise). Reaches stack. Everyone starts with 1, and it joins the prize table at weight 25 (swapper 45, bomb 30). 1,000 turns, seed 1, dealer, with bots using it only when stuck: barely any change (medium 278.4 steps a turn, was 276.7; epic 13.9%, was 13.5%). With bots using it at once, it dominates: medium 348.3 steps, epic 97.2%, best set mean 46.0 (was 26.2); weak bots reach 24.5% epic. It needs a cost or a limit before release (to decide) |
| 2026-11-15 | The Mac beta is called Noddy Yookerspiel. The player app keeps the name Crib Maze, and the Xcode scheme and bundle ID stay `CribMazeBeta` and `ca.robotpony.cribmaze.beta` |
| 2026-11-15 | The flow of a game: Title, Options, Start, then each round deals, the player picks the crib, the starter is cut, the scoring grid is played, then pegging on the maze, with the grid's results. The scoring grid now comes before pegging (it came after, like the show); the grid never uses up hand cards, so nothing needs undoing. The pegboard replacement is the pegging maze |
| 2026-11-15 | Computer players' grid turns show first, in show order (non-dealer first), as a quick sequence of results with hands face down until after pegging, so pegging keeps its guesswork and the player knows what to beat |
| 2026-11-15 | Grid power carries into pegging: a hand card's power level multiplies what it pegs (simulate before tuning). Grid sets are walked on the maze as plays, taken in turns as in the maze walk mock v4 |
| 2026-11-15 | A joker dealt into a hand, the crib or as the starter is wild, as in joker cribbage, and carries one power that is enabled and recharged each time a set with it scores: reach (hand size +1 for a while), a multiplier, added time, or a random item or joker. Details to design |
| 2026-11-15 | Picking the crib is untimed. It's the first place for hints (see Hints) |
| 2026-11-15 | A wild joker's power comes from its kind (amber and teal each have their own), except the wildcard joker, which rolls one of any power. A charged power waits for a tap, like a power joker. Hints default to subtle |
| 2026-11-15 | Players call the tray "power jokers": the on-screen tag and the rules say so. The engine and config keep the name `tray` |
| 2026-11-15 | Releases: Crib Maze for Mac, signed with Developer ID and notarized, posted as free pre-release demos on GitHub releases ([RELEASING.md](../../RELEASING.md)) |
| 2026-11-15 | A card counter shows how many cards a set can pick (the pick limit, `maxSet` for now). Some combos, jokers and prizes will raise it for a while; not designed yet |
| 2026-11-15 | A score's breakdown plays over a row of its cards, flown up from the board with the starter on the right, so it always sits in the same place instead of away from the set. It waits for a tap at the end, and each line shows its cards. The mock still plays over the board |
| 2026-11-15 | Match rules r20. Joker-made cards carry a multiplier (×1.05 40%, ×1.1 25%, ×1.25 18%, ×1.5 10%, ×2 5%, ×3 2%; their product capped at ×3), on top of edge power. Edge power grows 10% a level (was 50%) under the same ×1.5 cap: at 50% one level hit the cap, so later power-ups did nothing (Bruce's playtest). 1,000 turns, seed 1, dealer, medium bot: 269.6 steps a turn (r19 278.4); prizes common 52.5%, rare 29.8%, epic 17.7% (r19 58.6, 27.5, 13.9); edge power 25% of steps. A wider made table (mean ×1.38) gave 31% epic; edge steps of 10 to 25% with caps of ×2 to ×2.5 gave 40 to 91% epic |
| 2026-11-15 | No edge power cap (r21). A cap comes back only as a mechanic the player can see in the footer and change with jokers. Without it, the medium bot scores 540 steps a turn (was 270 with the ×1.5 cap) and wins epic prizes in 65% of turns (was 18%); weak 302, strong 647 (1,000 turns each, seed 1, dealer). The prize thresholds need retuning |
| 2026-11-15 | A joker inventory (`mocks/joker-inventory.html`) catalogues jokers, chips that sit on jokers, and other pieces, built and ideas alike, to ideate from |
| 2026-11-15 | The game is about deck building: a joker that changes a card changes the shared deck for the rest of the game (made, painted, nudged, cloned, burned or merged cards, and badges on cards). Power jokers and chips are the player layer. The deck must be visible, between turns and on the deal screen |
| 2026-11-15 | The joker inventory is the working set: every piece in it is assumed to work, and the deck stays shared with owner badges, until playtests show otherwise |
| 2026-11-15 | Prizes retuned for r22: rare from 40 steps, epic from 70 (were 25 and 31). Medium bot, 1,000 turns, seed 1: dealer 59% common, 25% rare, 15% epic (back near r16's 59/27/14); non-dealer 76/16/8; weak dealer 84/12/4; strong dealer 56/25/19 |
| 2026-11-15 | Shared deck or each player's own: undecided, so it's a setting (`deck.shared`, on by default; Advanced › Deck building in the beta) |
| 2026-11-15 | Deck edits, first cut (match rules r23). A game is 3 turns (`game.turns`, to tune), the deal alternating. The deck lasts the game: made cards join it, and a new burn joker takes a grid card out of it for the game, down to 40 cards. Everyone starts with 1 burn; it joins the prize table at weight 20. Power jokers and each turn's prize carry over. Bots don't burn yet. `cribmaze-sim game`, medium bot, 300 games, seed 1: turns score 672, 709 and 1,048 steps (2,429 a game); with a fresh deck each turn, 672, 506 and 743 (1,921). So the lasting deck lifts turns 2 and 3 by about 40%, mostly through made cards' multipliers (181 steps of turn 3). Carrying power jokers over changes almost nothing (bots use them only when stuck). The deck ends the game at 57 cards, 5 of them made. Epic prizes rise from 21% in turn 1 to 31% in turn 3. Prizes and made multipliers need retuning for a game, not a turn |
| 2026-11-15 | The shape of a game (Bruce): title sequence to the menu, start a game, cut for first dealer, then hands repeat (deal, scoring grid, shop, pegging on the maze) until a player exits the maze. The shop comes after the scoring grid, before pegging. The 3-turn game (`game.turns`, r23) is a stand-in until the maze is built |
| 2026-11-15 | A game runs 5 to 13 hands. Maze size, circular paths and gates are scaled for a typical game in that range. Grid points are spent opening gates, hitting switches and shifting the maze; pegging moves the tokens, so both matter. How the split works: to design (the grid points and pegging split is superseded 2026-11-17: the maze is the pegging, walked with your grid sets) |
| 2026-11-15 | The 3-turn game doesn't stay as a test mode: the maze replaces it shortly, and the game becomes hands until a player exits the maze. Made and burned cards last the whole game, across every hand. GameRecord comes next on the engine track, before more deck edits. The first human playtest follows a plan (`playtests/plan.md`), and the first GitHub release waits on it. The playtest waits for the maze, to test the whole sequence of a game |
| 2026-11-15 | The maze will change, to be more of a board game with circular paths; its place in the round stays the same. Game length comes from the maze's size, its circular paths and clearing its gates. Gates take points or suits to open, or special jokers, which can be played during pegging on the maze |
| 2026-11-16 | Cards keep the original cream art from `design/cards/cards.js`, with four-colour suits. The neon cards are dropped: they were too hard to read (Bruce) |
| 2026-11-16 | One typeface for every build, Saira Semi Condensed, so the Mac and Linux builds look the same. The Mac tries it in Crib Maze first; the beta follows once Bruce has seen it |
| 2026-11-16 | The Mac release app is renamed Crib RPG (was Crib Maze), also known as Noddy Yookerspiel or Crib Jokers (Bruce). Its bundle ID and target stay `cribmaze`, so settings carry over |
| 2026-11-16 | The game is renamed Crib RPG in the specs and the app, not only the Mac app (Bruce). Code names, the record ID `crib-maze` and history (changelogs, dated decisions) keep Crib Maze |
| 2026-11-16 | App icon: four cream cards in a 2 × 2 grid, one suit each, on joker purple with a gold star where they meet; no text. One set of layers in `design/icon/` exported for macOS, iOS, Linux and web, with a simpler favicon |
| 2026-11-16 | Saira Semi Condensed is kept, in every build and the beta too; the beta drops the system font and draws suits and ★ from `shapes.json` (Bruce) |
| 2026-11-16 | Match rules r24, from Bruce's playtest. The hand, and the crib for the dealer, are counted first as a classic show, over the empty board, before the grid deals in. The count uses classic rules; only a made card's multiplier applies, with no edge power, no power up, and it is never the best set. On the grid a set picks at most one hand or crib card (`maxEdgeCards` 1), so the hand can't be counted again. Supersedes "every set needs a grid card" (2026-11-14) as the reason the hand can't simply be counted, and 2026-11-13's "match turns replace counting". The order you sort your hand in during the deal is the hand row's order. `cribmaze-sim game`, medium bot, 300 games, seed 1: r23 2,540 steps a game; the opening count alone 2,575 (about 12 a turn); the one-card limit alone 713; both 749 (turns 227, 228 and 294). Epic prizes fall from 22 to 34% a turn to 0 to 4%, so prizes and edge power need retuning for r24 |
| 2026-11-17 | Match rules r25: prizes retuned for r24, rare from a best set of 28 steps and epic from 34 (were 40 and 70), aiming for r23's mix (Bruce). Bruce also confirmed the one-card limit counts the hand and crib together, not one from each. `cribmaze-sim run`, 1,000 turns, seed 1: medium dealer 64% common, 22% rare, 14% epic; medium non-dealer 74/17/9 (r23 76/16/8); weak dealer 96/3/2; strong dealer 59/25/17. `cribmaze-sim game`, medium, 300 games: turns 60/27/13, 57/21/22 and 33/28/39 (r23 50/29/22, 58/20/23, 35/31/34). Steps are unchanged, at 749 a game. Edge power, now 25% of steps (was 52%), is still to retune
| 2026-11-17 | Edge power stays as it is for r25 and r26: playtest at these levels, and add other tools to raise scores rather than retuning it (Bruce) |
| 2026-11-17 | Match rules r26, the opening bonus (Bruce): the hand and crib counts are ranked, and a higher count wins more power jokers, 1 for every 5 points past 10 (`opening.bonus` from 10, per 5). Each count is ranked on its own (Bruce chose this over adding hand and crib), on its points after a made card's multiplier. The jokers are special jokers for the tray (Bruce chose these over amber or teal jokers in the stock), picked by the prize weights from their own dice stream, so the end-of-turn prize doesn't shift. `cribmaze-sim run`, 1,000 turns, seed 1, bots keeping the classic best hand: dealers win 2.1 power jokers a hundred turns, non-dealers 1.3, the same at every bot level, since bots keep alike. Steps barely move (medium dealer 224.8 a turn; game 749 steps). A classic count of 15 or more is rare, so the bonus is a treat, not a lever; lower `from` to make it common
| 2026-11-17 | Match rules r27: the opening bonus starts at 6, not 10 (Bruce), so 11 wins 1 power joker, 16 wins 2, 21 wins 3 and 26 wins 4. `cribmaze-sim run`, medium, 1,000 turns, seed 1: dealers win 9.7 power jokers a hundred turns (was 2.1), non-dealers 5.5 (was 1.3). Steps don't move (game 749.5), since bots rarely need the extra jokers |
| 2026-11-17 | The grid intro (Bruce): after the hand and crib are counted, and before the grid deals in, a card explains the grid ("collect more steps for your step counter by matching crib hands") and waits for Start, so the timer starts only once you've read it. Shown on the game's first turn only (Bruce, 0.20.1) |
| 2026-11-17 | Phases (Bruce): one list of every phase of a game, in order, with what the beta has and what v1 targets, kept in concept.md › Phases. It is the target set for the first version, to iterate on; rules.md, ui.md and engine.md point to it |
| 2026-11-17 | Fill patterns (Bruce): the grid's first deal-in comes in one of five patterns, all five tried: rain, deal, spiral, wave and scatter (ui.md › The grid fills). Refills keep falling from above. The pick is presentation only, from the turn's seed |
| 2026-11-17 | The first version includes every phase in Phases, the shop, pegging and the maze walk too (Bruce). The grid is playtested first; the other phases are prototyped after |
| 2026-11-17 | The multiplier coin (Bruce, pick C from `mocks/card-chips.html`, moved to the bottom left over the card's edge, with a coin edge): a card's multiplier no longer covers the word tags. The made card's ★ moves inside, under the rank |
| 2026-11-17 | Prototype order after the grid playtest (Bruce): pegging on the maze and the maze walk together, then the shop, then the cut and the bots' turns. The scoring phase summarizes the bots' scores; the maze phase takes turns, and hinges on smart choices: where to turn, which jokers to apply, which doors to close (concept.md › Phases) |
| 2026-11-17 | The maze prototype (pegging on the maze and the maze walk) starts as a browser mock, not in the beta, to work out the turns and choices quickly (Bruce) |
| 2026-11-17 | The maze prototype is `mocks/maze-board.html` v2, built on maze-walk's grid maze and the neon maze art. "Circular paths" means loops through the grid, not a round board; v1's round board of turning rings was removed. Switches stand in for shifts: a pair of passages, one open and one shut, that any player can flip. Bot-only runs at the defaults (121-step route, grid steps ÷ 40) last 3 to 15 hands with 1 bot (median 7) and 4 to 10 with 2 (Bruce) |
| 2026-11-17 | The maze is the pegging, and the grid is the scoring phase (Bruce). You move by choosing from the hands you formed on the grid, shown as a list of plays (cards and steps), as in `mocks/maze-walk.html`. This reverses classic cribbage's order on purpose, so all the scoring sits in the grid. Supersedes 2026-11-15's split (grid points work the maze, pegging moves the tokens). Phases 7 and 8 merge. Whether classic play to 31 stays anywhere: open |
| 2026-11-17 | Junctions alternate, as on a party board game (Bruce): the first player through goes the way it points, the next goes the other way. Timing matters, since doors cost cards or combos to get through. Secondary: switch cards, bombs and in-maze switches |
| 2026-11-17 | Bots are balanced by default. Bot runs can be set to push on given features (doors, switches, junction timing, jokers), so each feature gets tested (Bruce) |

## Open questions

1. Which prizes go into the shared deck, and which does a player keep? Can you choose to keep a card instead of shuffling it in?
2. How many power slots, and how do you get more?
3. Can tokens get in each other's way at a gate or a fork?
4. Match turn timer and card budget: starting values come from the simulator. With play-out (r8), does a 180-second timer (raised from 90 on 2026-11-15) leave a person room to clear the board?
5. Edge power has no cap since r21. Does a cap come back as a mechanic the player can see and change with jokers, and how big do scores get over 5 to 13 hands?
6. Gates, switches and shifts: what each costs in grid points or suits, which special jokers open which gates, and how a hand's grid points are split between them.
7. Pegging moves the tokens and grid points work the maze (2026-11-15). Is a hand's pegging enough movement to finish in 5 to 13 hands, and does grid power multiplying pegging keep the two in step?
8. The maze walk: how choosing bundle order plays, holding steps back, and how long it can take.
9. The shop: what you pay with now that pips are gone (steps, prizes or something new), what's for sale, prices, and whether bots shop the same way.
10. Clear-board bonus: steps or a prize, and how big?
11. Jokers and extra cards: what items and the title and blank card prizes are, how many jokers a round can have (n), each special joker type's rules, and what happens when one is dealt into a hand or the crib, cut as the starter or played in pegging.

## Plan

Two tracks run side by side: design, so we can think about how the game plays and feels, and engine, so we can measure it.

| Phase | Track | What | Status |
|---|---|---|---|
| 1 | Design | Rules draft ([rules.md](rules.md)) | Draft done; match rules r23, kept in step with decisions |
| 2 | Engine | Stats and simulator ideation ([stats.md](stats.md)) | Done |
| 3 | Design | First mocks: cards, the match turn (frozen at r16), breakdown, effects, jokers, joker reveals. The beta is the match turn mock from 0.8.0 on | Done |
| 4 | Engine | Engine spec: match turn, the game, classic baseline, config, fixtures ([engine.md](engine.md)) | Done; kept in step |
| 5 | Engine | Swift engine, bots and simulator. The match turn and its bots are done; GameRecord (next), the game as hands, classic pegging and stats reports are open ([ARCHITECTURE.md](../../ARCHITECTURE.md) phases C and D) | In progress |
| 6 | Design | The maze, more of a board game: circular paths, gates, switches, shifts and prize cells, sized for 5 to 13 hands; pegging on the maze; the shop; the prize pick; transitions | Next on the design track |
| 6b | Design | Game flow and deck building: title, menu, cut for first dealer, deal, deck edits, wild jokers | In progress |
| 7 | Both | Tune with simulation and playtests against [stats.md](stats.md) › Targets | After 5 and 6 |
| 8 | Design | Face-card art: full graphics for J, Q and K (letters until then) | Not scheduled |
| 9 | Design | Card backs: design more backs (crosshatch until then) | Not scheduled |
| 10 | App | Mac beta (Noddy Yookerspiel), the first GitHub release after the first playtest, then iOS ([ARCHITECTURE.md](../../ARCHITECTURE.md) phases E to I) | Beta in progress; iOS after 7 |
