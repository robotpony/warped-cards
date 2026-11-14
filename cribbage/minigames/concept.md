# Crib Maze: Concept

Status: concept, 2026-11-14. Working title. Nothing has been playtested or simulated yet, so every number here is a starting guess.

The player-facing rules are in [rules.md](rules.md). How we measure and tune the game is in [stats.md](stats.md).

## Summary

Crib Maze is cribbage made into a video game for iPhone. You still build a hand, throw to the crib and peg to 31, but your points move a token through a maze instead of a peg along a board. Scoring your hand becomes a match game played on a grid of cards. Prizes from the maze and from big matches add cards and powers to the game, so every game builds up differently.

One human plays against one or two bots. A game lasts about as long as classic cribbage.

## What we're making

A logical extension of cribbage, not a different game wearing cribbage's clothes. Everything a cribbage player already knows should still pay off: a good discard, careful pegging, spotting every fifteen in a hand. Each of those becomes something you play and watch happen, instead of something you add up and peg.

Three things change:

1. The pegboard becomes a maze. Points are still steps along a track, but the track forks, has gates and holds prizes.
2. Counting hands becomes a match game. Your hand and crib sit at the edge of a grid of cards, and you make matches toward them.
3. The deck grows during the game. Prizes add cards, powers and badges, and they reset when the game ends.

## Where the fun is

- Every peg moves you, right away. A fifteen isn't 2 points on a board; it's 2 steps that might carry you past a fork, or into a gate.
- Which card scores matters. A fifteen made with the 5♥ opens heart gates. Holding the right suit for the gate ahead is a new reason to keep or throw a card.
- A 31 can shift a wall: open a shortcut for yourself, or close the one a bot was heading for.
- Forks are a gamble: a shorter branch with a gate and a prize, or the long safe way round.
- The match board rewards both sides of cribbage skill. Making matches is quick pattern play; marking the patterns in your own hand rewards the counting skill cribbage players already have. You score what you find.
- Edge cards power up as you use them, so a turn builds: a 5 in your hand gets stronger every time it joins a fifteen.
- Cascades and multi-matches win prizes, which gives every match turn a chance at a big moment.
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

Match turns replace counting hands and the crib. Each player takes one turn, in classic show order.

```
Match board (one player's turn)

  . . . . K      .  grid card, from the stock
  . . . . K      H  your hand, along the bottom
  . . . . K      K  the crib, along the side (dealer only)
  . . . . K      S  the starter, in the corner
  H H H H S
```

- The stock is every card not in a hand, the crib or the starter (39 cards with 2 players, 35 with 3). It's shuffled fresh for each turn, so every player gets the same amount to work with.
- A 4 x 4 grid is dealt from the stock. Your hand and the crib are edge cards: they don't move and are never used up.
- Swap two neighbouring grid cards to make a match: a row or column of 3 to 5 cards, which may end in one edge card, forming a cribbage combo (same rank, run, fifteen or flush).
- Matched grid cards clear, the cards above fall, and the stock refills the grid. New matches from falling cards are cascades and score too.
- Each time an edge card is used, it powers up and adds steps to later scores. Power lasts for the turn only, like a cribbage hand.
- Your hand and crib, each with the starter, also score as classic hands, but only for the patterns you mark yourself by tapping each card in a set, as in Boggle.
- One swap that makes two or more matches wins a prize.
- The turn ends on a timer, a card budget or an empty stock, whichever comes first. The simulator sets the timer and budget.

The hand you built still matters: it's what you match toward and what you mark. Pairs, 5s and runs still pay off.

## Deck building and prizes

Prizes come from prize cells in the maze and from multi-matches on the match board. They last for one game.

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

Bots are full players. They win prizes, fill power slots and add to the deck exactly as the human does. Each bot decides its discard, pegging, forks, match swaps, marking and prize use.

We plan three levels: random legal moves (for testing), greedy (best result now) and planning (looks ahead). In the simulator the human seat is just another bot.

## Later ideas

These are parked, not dropped:

- Endless mode: the maze keeps growing and the score is how far you get. It needs a way to end.
- Claiming missed patterns: other players score patterns you didn't mark, like muggins. The engine logs missed patterns from the start so this can be added later.
- Other mini-games from the first round of ideas, in [ideation.md](ideation.md).

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
| 2026-11-14 | Hand and crib score as classic patterns only when the player marks them |
| 2026-11-14 | Match turns run until the stock is used; a timer and card budget cap them, set by simulation |
| 2026-11-14 | Claiming missed patterns is parked for later |
| 2026-11-14 | The app may send game logs as opt-in data |
| 2026-11-14 | Stats exist mainly to compare scoring curves between bots, and to measure timing |
| 2026-11-14 | First mocks are clickable HTML in an iPhone frame, covering pegging on the maze, a match turn and a prize pick |
| 2026-11-14 | Cards: standard layout (rank in two corners, one large centred suit), rank and suit in the suit's colour, near-white faces only (no dark faces). Built on Scorekeep's card kit; its short form (one rank, one suit) is for documentation. Mock: [design/cards](../../design/cards/index.html) |
| 2026-11-14 | Card width 64 pt on iPhone; the 5-card match board fits at 340 pt |
| 2026-11-14 | Four-colour suits at 4.5:1 or better: spades #000000, hearts #E00000, diamonds #0070E0, clubs #00843D |
| 2026-11-14 | One back for now (Scorekeep's crosshatch); more backs get their own design phase |

## Open questions

1. Which prizes go into the shared deck, and which does a player keep? Can you choose to keep a card instead of shuffling it in?
2. How many power slots, and how do you get more?
3. Can tokens get in each other's way at a gate or a fork, or only through wall shifts?
4. Match turn timer and card budget: starting values come from the simulator.
5. Is +1 step per power level right, or too swingy? A question for the simulator.

## Plan

Two tracks run side by side: design, so we can think about how the game plays and feels, and engine, so we can measure it.

| Phase | Track | What | Status |
|---|---|---|---|
| 1 | Design | Rules draft ([rules.md](rules.md)) | Draft done; kept in step with decisions |
| 2 | Engine | Stats and simulator ideation ([stats.md](stats.md)) | Ideation done |
| 3 | Design | First mocks, clickable HTML in an iPhone frame. Cards first (v2 done), then pegging on the maze, a match turn, a prize pick | In progress |
| 4 | Engine | Engine spec: data model, event log, bot interface, sim clock | After 3 is planned |
| 5 | Engine | Python engine, bots, simulator and stats reports; classic cribbage as the baseline | After 4 |
| 6 | Design | Maze design: door types, branches, traps, wall shifts, fog, generator | Alongside 5 |
| 7 | Both | Tune with simulation until the numbers hold up | After 5 |
| 8 | Design | Face-card art: full graphics for J, Q and K (letters until then) | Not scheduled |
| 9 | Design | Card backs: design more backs (crosshatch until then) | Not scheduled |
| 10 | App | Swift app, built from the specs | After 7 |
