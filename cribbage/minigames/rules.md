# Crib Maze: Rules

Status: draft 5, 2026-11-15. Match turns follow match rules r17. Values marked "to tune" are starting guesses that the simulator and playtesting will change. Anything not designed yet is marked "Not designed yet". Design reasons and open questions are in [concept.md](concept.md).

## Overview

Crib Maze is cribbage on a maze. You build a hand, throw to the crib and peg to 31 as in cribbage, but every point you score moves your token through a maze instead of along a pegboard. Then, instead of counting your hand, you play it in a quick match game: find cribbage combos on a grid of cards, using your hand and the crib along its edges. Prizes along the way add cards and powers to the game.

The first token to reach the goal wins.

- Players: 2 or 3 (you and one or two computer players)
- Deck: one shared deck, starting as a standard 52-card deck plus extra cards: the title card, a blank card, and 0 or more jokers, decided each round when the deck is shuffled
- Length: short (61-step main route) or standard (121-step main route)

## How a game fits together

```
Game ............................ until a token reaches the goal
  Round ......................... one deal; the deal then passes left
    Stage ....................... deal and discard, cut, pegging, match turns, shop
      Turn ...................... one player's go within a stage
```

| Term | Meaning |
|---|---|
| Game | From setup until a token reaches the goal. Special jokers won as prizes, power slots, cards a joker made, and prizes in the deck last the whole game |
| Round | One deal, with every stage played once. The deal then passes to the left. How many jokers are in the deck is decided at each round's shuffle, and special jokers made by a joker's reveal last only for the round |
| Stage | One part of a round. In order: deal and discard, cut the starter, pegging, match turns, the shop |
| Turn | One player's go within a stage: a card played in pegging, or a match turn |
| Play | One go on the maze: a pegging score or a scored set, walked as its steps. Players take turns making plays, as in pegging (concept.md, 2026-11-14; the maze walk rules are still to be written) |
| Minigame | A game played in a stage in place of a classic cribbage step. The match game is the first: it replaces counting your hand. More may follow |
| Match turn | One player's turn of the match game. Your steps from it are walked through the maze right after |

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

In classic cribbage you'd count your hand now. In Crib Maze, each player takes a match turn instead, in classic show order: the players after the dealer first, then the dealer, who plays the hand and the crib in the same turn.

These are match rules r17, the version in the [match turn mock](mocks/match-turn.html). Each rules version is listed in [mocks/README.md](mocks/README.md#match-turn-rules-versions).

```
Match board (one player's turn)

  Steps 12 ............................ Stock (face down)

  . . . .   C        .  grid card, from the stock
  . . . .   C        H  your hand
  . . . .   C        C  the crib (dealer only)
  . . . .   C        S  the starter
  H H H H   S

  Power jokers: [swapper x2] [bomb x1] [ ] [ ]
```

A turn at a glance:

1. Trace a set of 2 to 4 touching cards. It scores at once, counted like a cribbage hand.
2. Scored grid cards clear and the stock refills the grid. Your hand, crib and starter stay and power up.
3. Use your power jokers to change the board.
4. When the stock runs out, play out the cards that are left.
5. The turn ends on the timer, a cleared board, or a board with no sets left. Your best score wins a prize.

#### Setting up

1. Shuffle every card that isn't in a hand, the crib or the starter. This is the stock.
2. Deal a 4 x 4 grid face up from the stock.
3. Lay your hand along the bottom and the starter in the corner. The dealer lays the crib down the side; for anyone else the side stays empty, so the crib is the dealer's advantage.

#### Tracing a set

Drag across touching cards and let go, or tap them one by one and tap the last one again. Drag back to undo the last card.

- Cards touch their 8 neighbours, diagonals included. Hand, crib and starter cards follow the same rule.
- A set picks 2 to 4 cards, plus the starter, which joins for free. The card counter beside the help line shows how many you've picked. Later, some combos, jokers and prizes will raise the limit for a while.
- Every set MUST include at least one grid card. Your hand, crib and starter can't score on their own.
- The same set of cards can't score twice in a turn.

#### The starter joins every set

As in a cribbage hand, the starter counts with every set you score. You don't need to trace it, and it doesn't count toward your cards (tracing it does no harm).

- If the starter is part of a combo, it's in the set: it lights up, its power multiplies the set, it powers up, and its suit counts.
- If it isn't, it's ignored. It's never left over.
- His nobs needs only the jack of the starter's suit, from your hand or the crib, in the set.

```
What touches the starter (S)

  . . . .   C
  . . . .   C
  . . . .   C
  . . . g   c        g  the grid corner
  H H H h   S        c  the bottom crib card
                     h  the last hand card
```

While you trace, every selected card looks selected, and cards that are part of a combo light up more. A card that stays dimmer is one that would be left over.

#### What scores

A set is counted like a cribbage hand. Every combo inside it scores.

| Combo | Steps |
|---|---|
| Fifteen: any cards adding to 15 (face cards are 10) | 2 each |
| Pair | 2 |
| Pair royal (3 of a kind) | 6 |
| Double pair royal (4 of a kind) | 12 |
| 5 or more of a kind (cards a joker made) | 2 for every pair in it: 5 of a kind is 20 |
| Run of 3 or more | 1 per card; in a double run, each run counts |
| Flush: 4 or 5 cards of one suit | 1 per card |
| His nobs: the jack of the starter's suit, from your hand or the crib | 1 |

| Set | Combos | Steps |
|---|---|---|
| 7-8 | Fifteen | 2 (a single) |
| 8-6-A | Fifteen | 2 (a single) |
| 4-5-6 | Fifteen, run of 3 | 5 (a multi) |
| 7-8-8 | Two fifteens, pair | 6 (a multi) |
| A-2-2-3-3 | Double double run of 3, two pairs | 16 (a multi) |

A set worth one combo is a single; two or more is a multi. Each fifteen counts as its own combo.

#### Cards left over

A card that isn't part of any combo is left over. Each one costs 2 steps (to tune).

| Set | Combos | Left over | Steps |
|---|---|---|---|
| 7-8 | Fifteen, 2 | none | 2 |
| 7-8-K | Fifteen, 2 | K, −2 | 0 |
| K-9 | none | K and 9, −4 | −4, and nothing clears |

- The first time you trace a set with a card left over, a warning explains this rule instead, and nothing happens.
- Your steps for the turn can go below 0.
- A set the game rejects for another reason costs nothing: fewer than 2 cards, no grid card, or a set already scored.

#### After a score

The set's grid cards clear, the cards above them fall, and the stock fills the gaps from the top.

Your hand, crib and starter are edge cards. They stay, and they power up. Power multiplies the sets they're in, so there's one score: steps.

- Each edge card starts the turn at power 0.
- A set with powered edge cards multiplies its combos. Add up the power levels of its edge cards; the multiplier is 1 plus 0.5 for each level (level 1 is ×1.5), up to ×1.5 (to tune). Round to the nearest step. Cards left over aren't multiplied.
- After a set scores, each edge card in it goes up one level. The starter is in a set only when it's part of a combo.
- Power lasts the turn. Values: to tune (the mock has settings for the step per level, adding or multiplying levels, and the cap).

| Set | Edge power | Combos | Multiplier | Steps |
|---|---|---|---|---|
| 7-8, grid only | none | Fifteen, 2 | ×1 | 2 |
| 5 from your hand, 10 from the grid | the 5 at level 1 | Fifteen, 2 | ×1.5 | 3 |
| 5 and 5 from your hand, 5 from the grid | levels 1 + 1 = 2 | Pair royal and fifteen, 8 | ×2, capped at ×1.5 | 12 |
| 7-8 from the grid, K from your hand | the K at level 1 | Fifteen, 2; K left over, −2 | ×1.5 on the 2 | 1 |

Each set's steps carry its most common suit, for suit gates in the maze. A tie carries no suit (see Suit gates).

#### The score breakdown

Every score plays out part by part, like counting a hand aloud: the set's name and suit, each combo with its cards lit and a running total, cards left over, edge power, the power-up, then the total. The timer pauses while it plays, and a tap skips to the end. It starts slow and speeds up; its speed is a player setting.

#### Special jokers

Special jokers are jokers that carry an action. The ones you hold are your power jokers, kept below the board; others turn up on the board. Tap one to arm it; tap it again to cancel.

| Card | What it does |
|---|---|
| Swapper (⇄) | Trace a straight line of 2 to 4 grid cards. The line reverses; 2 cards trade places |
| Bomb | Tap a grid card. It and its 4 neighbours (a plus shape) clear and refill, scoring nothing |

You start the game with 2 swappers and 1 bomb (to tune). You get more from prizes, jokers and the shop.

- Special jokers you start with, win as prizes or buy last the whole game; what you don't use carries over to your next turn.
- Special jokers made by a joker's reveal last only for that round.
- Each type of special joker will get its own rules (uses, limits), balanced from stats later.

#### Jokers and extra cards

The deck's extra cards are the jokers, the title card and the blank card. How many jokers a round has is decided when the deck is shuffled: 0 to n (n to tune; the mock uses 0 to 2), each one amber (a star) or teal (a moon). Jokers never expire. Each player can use each joker once a round, because each player plays their own match turn.

When an extra card lands on the board, play and the timer pause and it turns into a prize:

1. The card lifts off the board and the screen dims.
2. Something random happens: a shuffle, a wheel or a die of that card's face.
3. The prize is revealed. The rarer the prize, the bigger the reveal: a plain card flips quietly, a scoring card glints, and the rarest prizes swell, glow and throw rays.
4. The prize flies to where it goes: the card's spot on the board, the stock, your power jokers or your step count.

The first time you meet each kind, it's named with a one-line hint. A tap skips the rest of the reveal. Computer players' reveals aren't shown.

Players never see the chances or the list of possible prizes. Each kind rolls once on its own table, which is the game maker's tuning tool (to tune; tables in `mocks/jokers.js`, tried out in the [joker mock](mocks/jokers.html)):

| Card | Prizes |
|---|---|
| Amber joker | 90% a card, 9% a scoring card, 1% an item for your power jokers |
| Teal joker | 80% a card, 15% a scoring card, 5% a special joker shuffled into this turn's stock |
| Title card, blank card | A third each: a new 5, a special joker for your power jokers, or 5 steps (placeholders) |

- A card is a new card of any rank and suit, made by the joker and placed in its spot. A scoring card is a new 5 or 10-value card (10, J, Q, K). Cards a joker makes are marked ★ and stay in the deck for the rest of the game.
- The teal joker's special joker is picked from every known special joker (the swapper and bomb so far) and shuffled into this turn's stock. Drawn onto the board, it waits there until you tap it to use it. It can't be part of a set. If the stock is empty, it goes straight to your power jokers.
- When the prize doesn't go to the board, the stock fills the card's spot. If the stock is empty, the spot stays empty.

Not designed yet: items; the title and blank card prizes; how many jokers a round can have (n); each special joker type's own rules; and what happens when an extra card is dealt into a hand or the crib, cut as the starter or played in pegging.

#### Ending the turn

| When | What happens |
|---|---|
| The stock is empty or your card budget is used | Nothing refills. Gaps stay empty and you play out the cards left |
| No set on the board can score | The game says so. Use a special joker, or end your turn |
| You clear the board (every grid card gone) | The turn ends with a clear-board bonus (to tune; the mock gives 10 steps) |
| The timer runs out | The turn ends |
| No sets are left on the board | With no power jokers, the turn ends. With some, you have 25 seconds to use one (to tune), shown on the clock; a joker that opens up a set stops the count |

At the end, your best score wins one prize: a special joker for your power jokers. A bigger best score wins a better tier: common below 25 steps, rare from 25, epic from 31 (to tune). How match prizes relate to maze prizes: not designed yet. Timer and budget: to tune (180 seconds and the whole stock for now).

Your token doesn't move during the turn. Each scoring set becomes a bundle of steps with a suit, and after the turn you walk them through the maze (not designed yet).

Computer players' match turns aren't played out on screen: you see each result (steps, best set and prize).

### 5. The shop

Between rounds, you can shop. What you pay with isn't designed yet (pips, the old currency, were removed in match rules r15). The shop sells jokers, and any card you've discovered in any game you've played, such as a special joker you've won or seen in a reveal. The game reveals itself over hundreds of games. What's for sale and the prices: not designed yet.

### 6. Next round

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

If your steps reach a gate of the wrong suit, you bounce: walking into the gate costs one step, and the rest of your steps take you back the way you came. A special door stops you instead, and the rest of your steps are lost.

### Doors

Some doors must be knocked down. A door has a strength, and the steps you spend on it break it down instead of moving you. A big score can still break through, but it doesn't carry you as far.

- Pegging steps and match steps both count against a door.
- Damage stays on a door between turns, whoever did it.
- Once a door is down, it's open for every player.

Door strengths and where doors go: not designed yet.

### Fog

Each token sees a few cells around it (how many: to tune). Cells anyone has seen stay revealed.

### Prize cells

Reaching a prize cell wins its prize. Whether you must land on it exactly, and whether it refills: not designed yet.

## Prizes

Prizes last for the rest of the game.

| Kind | Example |
|---|---|
| Card | An extra standard card, like a third 5♥, added to the deck |
| Special joker | A wild joker (any rank and suit), or a skeleton key (any suit at a gate) |
| Power | Kept in a power slot. For example, re-cut the starter once per round |
| Badge | Added to one card. For example, this card scores 1 extra step when it's part of a fifteen |

Some prizes go into the shared deck and some you keep. Which ones: not designed yet.

- Prizes in the deck help whoever is dealt them, including other players.
- Prizes you keep in power slots work only for you.
- A badge works for whoever holds its card, unless it's scoped. A scoped badge shows its owner's picture and works only for them.

## Winning

The first token to reach the goal wins at once. With three players, the other two are placed by how far they are from the goal along the shortest route.

## Glossary

Game, round, stage, turn, minigame and match turn are defined in How a game fits together.

| Term | Meaning |
|---|---|
| Step | One cell of movement. One point in classic cribbage |
| Main route | The path from start to goal that is always open. Its length sets the game length |
| Branch | A route that leaves the main route at a fork |
| Stock | The cards used to fill the match grid on a turn: every card not in a hand, the crib or the starter, extra cards included |
| Edge cards | Your hand, the crib and the starter, laid along the edges of the match grid. They're never used up |
| Set | 2 to 4 touching cards traced on the match board, plus the starter. It scores if every card is part of a cribbage combo |
| Single | A set worth exactly one combo |
| Multi | A set worth two or more combos |
| Power level | How often an edge card has scored this turn; multiplies the sets it's in later |
| Joker | A card outside the standard 52 that does something. Each joker is one kind: the amber and teal jokers turn into a prize when drawn; special jokers carry an action |
| Special joker | A joker that carries one action: the swapper reverses a line, the bomb clears cards |
| Power jokers | The special jokers you hold, below the board, kept all game. Tap one to arm it |
| Extra cards | The 4 cards beyond the standard 52: the amber and teal jokers, the title card and the blank card |
| Reveal | The short show when an extra card turns into a prize. It hides the chances; rarer prizes get bigger reveals |
| Door | A barrier in the maze that takes steps to knock down |
| Power slot | A place where you keep a power for the rest of the game |
| Badge | A bonus attached to one card in the deck |
