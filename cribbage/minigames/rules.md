# Crib Maze: Rules

Status: draft 4, 2026-11-14. Match turns follow match rules r8. Values marked "to tune" are starting guesses that the simulator and playtesting will change. Anything not designed yet is marked "Not designed yet". Design reasons and open questions are in [concept.md](concept.md).

## Overview

Crib Maze is cribbage on a maze. You build a hand, throw to the crib and peg to 31 as in cribbage, but every point you score moves your token through a maze instead of along a pegboard. Then, instead of counting your hand, you play it in a quick match game: find cribbage combos on a grid of cards, using your hand and the crib along its edges. Prizes along the way add cards and powers to the game.

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

These are match rules r8, the version in the [match turn mock](mocks/match-turn.html). Each rules version is listed in [mocks/README.md](mocks/README.md#match-turn-rules-versions).

```
Match board (one player's turn)

  Steps ............................ Deck
                                     (face down)
  . . . .   C       .  grid card, from the stock
  . . . .   C       H  your hand, along the bottom
  . . . .   C       C  the crib, down the side (dealer only)
  . . . .   C       S  the starter, in the corner
  H H H H   S

  Special cards: [swapper x2] [bomb x1] ........ End turn
```

Setting up your turn:

1. Shuffle every card that isn't in a hand, the crib or the starter. This is the stock, shown face down at the top.
2. Deal a 4 x 4 grid face up from the stock.
3. Lay your 4 hand cards along the bottom and the starter in the corner. If you're the dealer, lay the 4 crib cards down the side; if not, the side stays empty, so the crib is the dealer's advantage. A small gap separates the hand and crib from the grid. Word tags name the hand, the crib and the starter.

#### Scoring sets

Find a set and trace it, like tracing a word in Boggle: drag across the cards and let go, or tap them one by one and tap the last one again.

- A set is 2 to 5 touching cards. Cards touch their 8 neighbours, diagonals included. This holds for every card: hand and crib cards touch only the cards next to them, and the starter touches the last hand card, the bottom crib card and the grid card beside it.
- Every set MUST include at least one grid card. Your hand, the crib and the starter can't score on their own.
- A set scores as a classic cribbage hand: every fifteen (2 each), pair (2), pair royal (6), double pair royal (12), run (1 per card; double runs count each run), flush of 4 or 5, and his nobs (1).
- Every card in the set MUST be part of at least one combo. If a card is left over, or nothing scores, nothing happens. There's no penalty.
- A set worth one combo is a single (7-8: a fifteen). A set worth two or more is a multi (4-5-6: a fifteen and a run). Each fifteen counts as its own combo.
- The same set of cards can't score twice in a turn.
- Every step you score is moved right away.

| Set | Combos | Steps |
|---|---|---|
| 7-8 | Fifteen | 2 (single) |
| 8-6-A | Fifteen | 2 (single) |
| 4-5-6 | Fifteen, run of 3 | 5 (multi) |
| 7-8-8 | Two fifteens, pair | 6 (multi) |
| A-2-2-3-3 | Double double run of 3, two pairs | 16 (multi) |

When a set scores, its grid cards clear, the cards above them fall, and the stock fills the gaps from the top. Edge cards stay.

#### Edge power and pips

Your hand, crib and starter cards are edge cards. They're never used up.

- Each edge card has a power level, starting at 0 each turn.
- When a set scores, each edge card in it adds its power level to your pips. Then each of those edge cards goes up one level.
- Pips are a separate tally, not steps. They don't move you; you spend them between rounds on jokers and special cards (see The shop).
- Power lasts until the end of your turn; pips last the game. Values: to tune.

#### Special cards

Special cards are jokers you hold in a tray at the bottom of the screen, stacked by type. Tap one to arm it; tap it again to cancel.

| Card | What it does |
|---|---|
| Swapper (⇄) | Trace a straight line of 2 to 4 grid cards (a row, column or diagonal). The line reverses; 2 cards trade places |
| Bomb | Tap a grid card. It and its 4 neighbours (a plus shape) clear and refill from the stock, scoring nothing |

Special cards are kept all game: what you don't use carries over to your next turn. You start the game with 2 swappers and 1 bomb (to tune), and get more from prizes and the shop. Swapping is never free: it always costs a swapper.

#### Prizes

At the end of your turn, your best score wins one prize: a special card for your tray. A bigger best score wins a better tier (common, rare or epic; to tune). How match prizes relate to maze prizes: not designed yet.

#### The score breakdown

Every score plays out part by part, like counting a hand aloud: the set's name, each combo with its cards lit and a running total, any bonuses, edge power (to pips), the power-up, then the total. The banner names the set's suit, or "no suit" for a tie (see Suit gates). The timer pauses while it plays, and a tap skips to the end. It starts slow and speeds up with each part; how fast is a player setting, quicker as they learn. It plays in the [match turn mock](mocks/match-turn.html).

#### Ending the turn

When the stock is empty or you've used your card budget, nothing refills: gaps stay empty and you play out the cards that are left. Timer and budget: to tune (the mock uses 90 seconds and the whole stock).

If you clear the board (every grid card scored or bombed, nothing left), your turn ends and you earn a clear-board bonus. Its size and kind (steps, pips or a prize): to tune; the mock uses 10 steps.

If no set on the board can score, the game says so. Use a special card if you have one, or end your turn.

Your turn ends when the timer runs out, when you clear the board, or when you choose to end it.

Your steps don't move your token during the turn. Each scoring set becomes a bundle of steps that carries a suit (see Suit gates), and after the turn you walk them through the maze, making the choices at forks and gates. How that walk plays: not designed yet.

Computer players' match turns aren't played out on screen: you see each one's result (its steps, best set and prize).

#### The shop

Between rounds, you can spend pips on jokers and special cards. What's for sale and the prices: not designed yet.

### 5. Next round

All cards, including any prize cards added to the deck, go back into the deck, and the deck is shuffled. The deal passes to the left.

## Moving through the maze

- One point is one step, and you must take every step.
- At a fork, choose a branch. The main route always stays open. A branch may be shorter or longer than the main route, and it may hold gates, prizes or traps.
- All tokens share the maze and may stand on the same cell.
- The game ends the instant a token reaches the goal. Scoring that hasn't happened yet doesn't count.

### Suit gates

A gate marked with a suit (♥ ♠ ♦ ♣) opens only for steps of that suit.

- Pegging: the card that completes a score gives its suit. A fifteen made by playing the 5♥ gives 2 heart steps.
- Match turns: each set's steps carry the suit that appears most often among its cards, hand, crib and starter included. If two or more suits tie for most, the steps carry no suit: they walk open paths but can't pass a suit gate.

| Set | Suits | Its steps carry |
|---|---|---|
| 7♥ 8♥ | 2 hearts | ♥ |
| 4♣ 5♥ 6♥ | 2 hearts, 1 club | ♥ |
| 5♠ 5♦ 5♣ J♣ | 2 clubs, 1 spade, 1 diamond | ♣ |
| 9♦ 6♠ 9♠ 6♦ | 2 diamonds, 2 spades | no suit (a tie) |
| 7♠ 8♦ | 1 spade, 1 diamond | no suit (a tie) |

So a set built around one suit is worth more than its steps: a run of 3 hearts walks through a heart gate that a mixed run of 3 can't, and a 2-card set of two suits never passes a gate.

If your steps reach a gate of the wrong suit, you bounce: the rest of your steps take you back the way you came. A special door stops you instead, and the rest of your steps are lost.

### Doors

Some doors must be knocked down. A door has a strength, and the steps you spend on it break it down instead of moving you. A big score can still break through, but it doesn't carry you as far.

- Pegging steps and match steps both count against a door.
- Damage stays on a door between turns, whoever did it.
- Once a door is down, it's open for every player.

Door strengths and where doors go: not designed yet.

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
| Edge cards | Your hand, the crib and the starter, laid along the edges of the match grid. They're never used up |
| Set | 2 to 5 touching cards traced on the match board. It scores if every card is part of a cribbage combo |
| Single | A set worth exactly one combo |
| Multi | A set worth two or more combos |
| Power level | How often an edge card has scored this turn; adds pips to its later scores |
| Pips | A tally, separate from steps, earned from edge power and spent in the shop between rounds |
| Special card | A joker kept in the tray for one action: the swapper reverses a line, the bomb clears cards |
| Door | A barrier in the maze that takes steps to knock down |
| Power slot | A place where you keep a power for the rest of the game |
| Badge | A bonus attached to one card in the deck |
