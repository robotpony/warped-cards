# Crib Maze: Concept

Status: concept, 2026-11-14. Working title. The match turn has been mocked and bot-tested (match rules r6); nothing else has been playtested or simulated, so most numbers here are starting guesses.

The player-facing rules are in [rules.md](rules.md). How we measure and tune the game is in [stats.md](stats.md).

## Summary

Crib Maze is cribbage made into a video game for iPhone. You still build a hand, throw to the crib and peg to 31, but your points move a token through a maze instead of a peg along a board. Scoring your hand becomes a match game played on a grid of cards. Prizes from the maze and from big matches add cards and powers to the game, so every game builds up differently.

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
- A 31 can shift a wall: open a shortcut for yourself, or close the one a bot was heading for.
- Forks are a gamble: a shorter branch with a gate and a prize, or the long safe way round.
- The match board rewards the counting skill cribbage players already have. Every set is counted like a hand, so spotting a double run or a hidden fifteen pays, and you score only what you find.
- Edge cards power up as you use them, so a turn builds: a 5 in your hand earns more pips every time it joins a fifteen, and pips buy jokers between rounds.
- Every score plays out like counting a hand aloud ("fifteen 2, fifteen 4, a pair is 6"), so a big multi feels big.
- Each turn's best score wins a special card, and special cards are kept all game, so a good turn pays off later.
- Suits matter twice: a set's main suit decides which gates its steps can open, so a one-suit run is worth more than its steps.
- The shared deck is a gamble. A badge you put on the 5♥ helps whoever is dealt it next, maybe a bot.
- The race is visible. All tokens share one maze, like pegs on one board, so you always see who's ahead and which way they're going.

## A round

```
Round

  Deal and discard ..... as in classic cribbage (2 or 3 players)
  Cut the starter ...... a Jack gives the dealer 2 steps (his heels)
  Pegging .............. classic play to 31; each point is a step, moved at once
  Match turns .......... one per player, in show order; points are steps
  Next round ........... the deal passes left
```

Classic rule wording comes from Scorekeep's page, `~/projects/utilities/scorekeep/docs/rules/cribbage.md`. Scorekeep covers 2 players only, so the 3-player deal is defined in our rules.

## The maze

The maze replaces the pegboard. A pegboard is a track where every point moves you one hole; the maze is that track with forks, gates and prizes.

```
Maze sketch (real mazes are generated)

  Start . . . . + . . . . . . . . + . . . . Goal      main route
                .                 .
                . . P . . ♥ . . . .                   a branch

  + fork   P prize cell   ♥ ♠ ♦ ♣ suit gate
```

- The main route is 61 steps (short game) or 121 (standard), so games run about as long as classic cribbage.
- Branches leave the main route at a fork and rejoin it later. A branch may be shorter or longer, and it may hold gates, prizes or traps.
- Suit gates open only for steps scored by a card of that suit. Steps that hit a gate of the wrong suit bounce you back. Special doors stop you instead.
- Some walls can shift. Pegging a 31 lets you shift one, and powers may too.
- Fog hides the maze beyond a few cells of each token. Cells anyone has seen stay revealed.
- The maze is shared. All tokens race the same routes and may stand on the same cell.
- Every maze MUST always keep an open route from start to goal.
- The game ends the instant a token reaches the goal.

Door types, branch rules, traps and the maze generator get their own design phase (see Plan).

## Match turns

Match turns replace counting hands and the crib. Each player takes one turn, in classic show order. The full rules are in [rules.md](rules.md) section 4; this is the shape and the reasons.

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
- You trace sets of 2 to 5 touching cards, like words in Boggle. A set scores at once if every card is part of a cribbage combo, counted like a hand; otherwise nothing happens.
- Every set needs a grid card, so the hand and crib can't simply be counted. The hand you built is what your sets grow from, and the cards beside it decide how well it does.
- Scored grid cards clear and the stock refills. Edge cards stay and power up.
- Special cards (swapper, bomb) are the only way to change the board. They're scarce and kept all game.
- Edge power pays pips, a separate tally spent between rounds, so the hand you built feeds your deck building rather than your step count.
- Steps move your token after the turn, in a short walk with choices (see The maze walk).
- The turn ends on a timer, a card budget, an empty stock, or when you choose.

Why it works this way, from the mocks:

- Automatic line matching (match-3 style) played itself: cascades used the stock in 2 or 3 swaps. Tracing sets puts every score in the player's hands.
- Free swaps meant you could always make something. Making swaps cost a special card keeps the board a puzzle.
- When hand cards could score alone, or touched every other edge card, the hand was either everything or nothing. Real neighbours and the grid-card rule make position matter.

## The maze walk

Notes for a mini game not designed yet (2026-11-14). After a match turn, your scored sets become steps in the maze, and you walk them with choices where there are any.

- Each scoring set is a bundle of steps with a suit (the set's most common suit). Pegging steps already carry the suit of the card that scored them.
- You choose which bundle to spend next (decided 2026-11-14), so a heart bundle can be saved for the heart gate. The mechanics need thinking.
- It should feel like a party board game: each bundle is like a dice roll you already hold, and the fun is choosing where it takes you. Choices at forks, cells that do something when you land on or pass them (prizes, gates, doors), and maybe special cards played on the board.
- Doors absorb steps. A big bundle can knock down a door; the steps spent on it don't move you.
- If there are no choices to make, the walk plays itself, quickly.
- Open: can you hold steps back for a later round? Must you land exactly on a cell to trigger it? How long can the walk take before it drags?

## Transitions and effects

Each part of a round is its own mini game, so moving between them, and starting and ending each one, needs its own moment. These are concepts to mock later; nothing here is designed yet (2026-11-14).

```
A round, as the player sees it

  Deal and discard
    > transition: the crib slides to the dealer, the starter is cut
  Pegging on the maze
    > transition: the maze pulls back, the match board deals in
  Match turn
    begin ... cards fall into place
    end ..... board cleared, or not
    > transition: the step total carries over to the maze
  Maze walk
    > transition: the shop, then the deal passes left
```

Transitions:

- Every change of mini game gets a short transition that carries something across, so the player sees what links them: the step and pips totals flying from the match board to the maze, for example.
- Transitions are skippable and speed up as the player learns, like the score breakdown.

Begin, end and bonus effects:

- Match turn begins: the grid deals in from the deck, cards falling into place column by column, then the hand, crib and starter slide to the edges.
- Match turn ends: it looks and feels different if you cleared the board (every grid card scored, nothing left) than if time, the budget or the stock ran out. Clearing the board is a big moment and earns a clear-board bonus (size to tune); running out is a quiet wrap-up.
- Bonus effects mark the high points: a big multi, the turn's best score, a prize, a door knocked down, a gate opened.
- The score breakdown is the bonus effect for every score.

## Deck building and prizes

Prizes come from prize cells in the maze and from the match board (a special card for each turn's best score). Between rounds, pips buy more jokers and special cards in the shop. Everything lasts for one game.

| Prize | Example |
|---|---|
| Card | An extra standard card, like a third 5♥ |
| Special card | A joker (any rank and suit); a skeleton key (any suit at a gate) |
| Power | Kept in a power slot: re-cut the starter, shift a wall, peek at a crib card |
| Addition | A badge on one card: +1 step whenever it's part of a fifteen |

There's one shared deck, so prizes work on two layers:

- Deck layer: cards and badges added to the shared deck help whoever is dealt them. A scoped badge shows its owner's picture and works only for them.
- Player layer: powers and saved cards you keep for yourself, in power slots.

Which prizes go to which layer, and how they balance, is open.

## Bots

Bots are full players. They win prizes, fill power slots, earn pips and add to the deck exactly as the human does. Their match turns aren't played out on screen; the player sees each result. Each bot decides its discard, pegging, forks, which sets to trace, when to use special cards, and prize use.

Bot skill runs on a gradient from imperfect to perfect, like a depth-limited search. On the match board a perfect bot checks every set; lower levels trace paths from fewer starting cards and to a shallower depth, as a person does. We tune the levels so a medium bot scores about what a person does, from playtest runs. Other limits may come later. For the whole game we also plan random legal moves (for testing) and planning (looks ahead). In the simulator the human seat is just another bot.

## Later ideas

These are parked, not dropped:

- Endless mode: the maze keeps growing and the score is how far you get. It needs a way to end.
- Claiming missed sets: other players score sets you didn't find, like muggins. The engine logs the best sets left on the board so this can be added later.
- Sets longer than 5 cards (long runs and big fifteens from small cards). Scoring already handles them; the match turn caps sets at 5 until scores are tuned.
- More special cards beyond the swapper and bomb.
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

## Working title

"Crib Maze" is a placeholder. Options to react to (none checked yet against existing games or App Store names):

| Name | Why it might work |
|---|---|
| Crib Maze | Plain and clear: says what it is |
| Cribyrinth | A pun on labyrinth; memorable, a little silly |
| Warped Crib | Fits the warped family of projects; hints that the rules bend |
| Fifteen Two | The first words of every cribbage count; players will know it at once |
| Pegway | Pegs plus pathway; short, works as an app name |
| Heels and Hallways | His heels plus the maze; playful, longer |
| Thirty-One Ways | The pegging count plus routes through the maze |
| Crooked Crib | A crib board that doesn't go straight |

We lean toward Fifteen Two or Pegway for an app name, and Crib Maze as the descriptive subtitle ("Fifteen Two: a cribbage maze"). Any choice needs a name search before it's used publicly.

## Decisions

| Date | Decision |
|---|---|
| 2026-11-13 | iPhone app first; maybe iPad and Mac later |
| 2026-11-13 | Rules in Markdown first; engine and simulator in Python; Swift app built later from the specs |
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
| 2026-11-14 | The app may send game logs as opt-in data |
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
| 2026-11-14 | Every score plays as an overlay, part by part: set name, each combo with its points and a running total, bonuses, edge power, total. Steps start slow and speed up; the base speed becomes a player setting that quickens as they learn ([score breakdown mock](mocks/score-breakdown.html)) |
| 2026-11-14 | Every set is a single (one combo) or a multi (two or more); both are labelled in scoring and stats. Sets stay at 5 cards for now |
| 2026-11-14 | Maze doors take steps to knock down, so the maze absorbs big match scores. Match scores can run high; the maze sets the pace |
| 2026-11-14 | Rules doc draft 3: match turns rewritten for match rules r6 |
| 2026-11-14 | Licence: MIT |
| 2026-11-14 | Edge power pays into a separate tally ("pips", name confirmed the same day), not steps. Pips buy jokers and special cards between rounds (match rules r7) |
| 2026-11-14 | One prize per match turn, for the turn's best score (r7) |
| 2026-11-14 | Special cards are kept all game; more can be bought between rounds with pips |
| 2026-11-14 | A non-dealer's crib column stays empty: the crib is the dealer's advantage |
| 2026-11-14 | The timer pauses while a score breakdown plays (r7) |
| 2026-11-14 | Bot match turns show only their result |
| 2026-11-14 | Match-turn steps carry the set's most common suit at suit gates (ties: see below) |
| 2026-11-14 | Door damage stays between turns; a broken door is open for everyone; pegging steps count against doors |
| 2026-11-14 | Steps move the token after the match turn, in a maze walk with choices (a mini game, not designed yet) |
| 2026-11-14 | Prize cards and badges in the shared deck can turn up in any player's match grid |
| 2026-11-14 | Bot skill is a gradient from imperfect to perfect, like a depth-limited search; other limits may follow |
| 2026-11-14 | The bonus tally is called pips |
| 2026-11-14 | In the maze walk, the player chooses which set's steps to spend next; it plays like a party board game, with choices (mechanics to come) |
| 2026-11-14 | Each mini game gets transitions between it and the next, and begin, end and bonus effects; the match turn begins with cards falling into place and ends differently when the board is cleared. Future mocks |
| 2026-11-14 | Suit ties: when two or more suits tie for most common in a set, its steps carry no suit and can't pass suit gates. Rewards one-suit sets |
| 2026-11-14 | Clearing the board earns a bonus as well as its own ending (size to tune) |
| 2026-11-14 | Special actions come from special cards: smaller cards in a tray at the bottom, stacked by type, in limited supply. First two: the swapper joker (reverses a line of grid cards; swapping is no longer a free action) and the bomb joker (blows up cards) |

## Open questions

1. Which prizes go into the shared deck, and which does a player keep? Can you choose to keep a card instead of shuffling it in?
2. How many power slots, and how do you get more?
3. Can tokens get in each other's way at a gate or a fork, or only through wall shifts?
4. Match turn timer and card budget: starting values come from the simulator.
5. Is +1 pip per power level right? A question for the simulator, once the shop has prices.
6. Doors: how strong and how many? This decides how much of a match score becomes distance.
7. With match scores far above pegging, does pegging still matter? Doors treat both the same, so pegging may need its own edge.
8. The maze walk: how choosing bundle order plays, holding steps back, and how long it can take.
9. The shop: what's for sale, prices, and whether bots shop the same way.
10. Clear-board bonus: steps, pips or a prize, and how big?

## Plan

Two tracks run side by side: design, so we can think about how the game plays and feels, and engine, so we can measure it.

| Phase | Track | What | Status |
|---|---|---|---|
| 1 | Design | Rules draft ([rules.md](rules.md)) | Draft done; kept in step with decisions |
| 2 | Engine | Stats and simulator ideation ([stats.md](stats.md)) | Ideation done |
| 3 | Design | First mocks, clickable HTML in an iPhone frame. Cards (v2 done), match turn (v3, rules r6), score breakdown (v1), then a prize pick, and pegging on the maze once we've gathered maze inspiration | In progress |
| 4 | Engine | Engine spec: data model, event log, bot interface, sim clock | After 3 is planned |
| 5 | Engine | Python engine, bots, simulator and stats reports; classic cribbage as the baseline | After 4 |
| 6 | Design | Maze design: door types, branches, traps, wall shifts, fog, generator | Alongside 5 |
| 7 | Both | Tune with simulation until the numbers hold up | After 5 |
| 8 | Design | Face-card art: full graphics for J, Q and K (letters until then) | Not scheduled |
| 9 | Design | Card backs: design more backs (crosshatch until then) | Not scheduled |
| 10 | App | Swift app, built from the specs | After 7 |
