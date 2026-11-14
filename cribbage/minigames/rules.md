# Crib Maze: Rules

Status: draft 2, 2026-11-14. Values marked "to tune" are starting guesses that the simulator and playtesting will change. Anything not designed yet is marked "Not designed yet". Design reasons and open questions are in [concept.md](concept.md).

## Overview

Crib Maze is cribbage on a maze. You build a hand, throw to the crib and peg to 31 as in cribbage, but every point you score moves your token through a maze instead of along a pegboard. Then, instead of counting your hand, you play it in a quick match game on a grid of cards. Prizes along the way add cards and powers to the game.

The first token to reach the goal wins.

- Players: 2 or 3 (you and one or two computer players)
- Deck: one shared deck, starting as a standard 52-card deck
- Length: short (61-step main route) or standard (121-step main route)

## Classic rules we use

Dealing, discarding, cutting the starter, his heels and pegging all follow classic cribbage. For the classic wording, see Scorekeep's How to play page: `~/projects/utilities/scorekeep/docs/rules/cribbage.md`. These rules only cover what's different, plus three-player play, which that page doesn't include.

## Setup

1. Make a maze for the chosen length. All tokens start on the start cell.
2. Shuffle the deck. Each player cuts, and the lowest card deals first.
3. Every player starts with empty power slots. How many: not designed yet.

## A round

### 1. Deal and discard

| Players | Deal | Discard to the crib |
|---|---|---|
| 2 | 6 cards each | 2 each |
| 3 | 5 cards each, plus 1 card face down to the crib | 1 each |

The crib belongs to the dealer and always has 4 cards.

### 2. Cut the starter

Cut and turn up the starter as in classic cribbage. If it's a Jack, the dealer scores his heels: 2 steps, moved at once.

### 3. Pegging

Peg as in classic cribbage. The player to the dealer's left plays first, and the count runs up to 31. With three players, play passes to the left; a player who can't play says "go" and sits out until the count starts again. The last player to play before the count starts again scores the go (or the 31).

Every point you peg is one step, moved right away, before the next card is played. See Moving through the maze.

After pegging, the cards go back to their owners' hands.

### 4. Match turns

In classic cribbage you'd count your hand now. In Crib Maze, each player takes a match turn instead. Turns go in classic show order: the players after the dealer first, then the dealer, who plays the hand and the crib in the same turn.

```
Match board (one player's turn)

  . . . . K      .  grid card, from the stock
  . . . . K      H  your hand, along the bottom
  . . . . K      K  the crib, along the side (dealer only)
  . . . . K      S  the starter, in the corner
  H H H H S
```

Setting up your turn:

1. Shuffle every card that isn't in a hand, the crib or the starter. This is the stock.
2. Deal a 4 x 4 grid face up from the stock. If any matches are already showing, redeal those cards.
3. Lay your 4 hand cards along the bottom edge and the starter in the corner. If you're the dealer, lay the 4 crib cards along the side.

On your turn, do two things as often as you like.

Make matches. Swap two neighbouring grid cards. A match is a row or column of 3 to 5 cards that makes one of these combos. It can include one edge card, at the end of the line.

| Match | Steps (to tune) |
|---|---|
| 3, 4 or 5 of the same rank | 6, 12 or 20 |
| Run of 3, 4 or 5 (any order) | 3, 4 or 5 |
| Fifteen, using 3 or more cards | 2 |
| Flush of 4 or 5 | 4 or 5 |

Matched grid cards clear. The cards above them fall toward your hand, and the stock fills the gaps from the top. If falling cards make a new match, that's a cascade, and it scores for you too.

Mark your hand. Your hand with the starter, and the crib with the starter, score like classic cribbage hands: fifteens, pairs, runs, flushes and his nobs. But they only score the patterns you find. Tap each card in a pattern to mark it. Each pattern can be marked once per turn, and marked cards stay put. A pattern you don't mark doesn't score.

Also during your turn:

- Edge cards are never used up. Each time one is part of a match or a marked pattern, it powers up. Each power level adds 1 step to every later score the card is part of (to tune). Power lasts until the end of your turn.
- One swap that makes two or more matches, at once or through cascades, wins a prize.
- If no swap can make a match, reshuffle the grid with the rest of the stock.
- Every step you score is moved right away.

Your turn ends when the timer runs out, when you've used your card budget, or when the stock is empty, whichever comes first. Timer and budget: to tune.

### 5. Next round

All cards, including any prize cards added to the deck, go back into the deck, and the deck is shuffled. The deal passes to the left.

## Moving through the maze

- One point is one step, and you must take every step.
- At a fork, choose a branch. The main route always stays open. A branch may be shorter or longer than the main route, and it may hold gates, prizes or traps.
- All tokens share the maze and may stand on the same cell.
- The game ends the instant a token reaches the goal. Scoring that hasn't happened yet doesn't count.

### Suit gates

A gate marked with a suit (♥ ♠ ♦ ♣) opens only for steps scored by a card of that suit. The card that completes a score is the one that scored it: a fifteen made by playing the 5♥ gives 2 heart steps.

If your steps reach a gate of the wrong suit, you bounce: the rest of your steps take you back the way you came. A special door stops you instead, and the rest of your steps are lost. Door types: not designed yet.

### Shifting walls

Some walls can move. When you peg a 31, you move your 2 steps and may also shift one movable wall. A shift can open a branch for you or close one in front of another player. You can't make a shift that would cut off every route to the goal.

### Fog

Each token sees a few cells around it (how many: to tune). Cells anyone has seen stay revealed.

### Prize cells

Reaching a prize cell wins its prize. Whether you must land on it exactly, and whether it refills: not designed yet.

## Prizes

Prizes last for the rest of the game.

| Kind | Example |
|---|---|
| Card | An extra standard card, like a third 5♥, added to the deck |
| Special card | A joker (any rank and suit), or a skeleton key (any suit at a gate) |
| Power | Kept in a power slot. For example, re-cut the starter once per round |
| Badge | Added to one card. For example, this card scores 1 extra step when it's part of a fifteen |

Some prizes go into the shared deck and some you keep. Which ones: not designed yet.

- Prizes in the deck help whoever is dealt them, including other players.
- Prizes you keep in power slots work only for you.
- A badge works for whoever holds its card, unless it's scoped. A scoped badge shows its owner's picture and works only for them.

## Winning

The first token to reach the goal wins at once. With three players, the other two are placed by how far they are from the goal along the shortest route.

## Glossary

| Term | Meaning |
|---|---|
| Step | One cell of movement. One point in classic cribbage |
| Main route | The path from start to goal that is always open. Its length sets the game length |
| Branch | A route that leaves the main route at a fork |
| Stock | The cards used to fill the match grid on a turn |
| Edge cards | Your hand, the crib and the starter, laid along the edges of the match grid |
| Marking | Tapping the cards of a pattern in your hand or crib to score it |
| Power level | How often an edge card has been used this turn; adds steps to its later scores |
| Power slot | A place where you keep a power for the rest of the game |
| Badge | A bonus attached to one card in the deck |
