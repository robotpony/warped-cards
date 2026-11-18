# Crib RPG: Rules

Status: draft 7, 2026-11-17. Match turns follow match rules r28. Values marked "to tune" are starting guesses that the simulator and playtesting will change. Anything not designed yet is marked "Not designed yet". Design reasons and open questions are in [concept.md](concept.md).

## Overview

Crib RPG (its beta app is Noddy Yookerspiel) is cribbage on a maze. You build a hand and throw to the crib as in cribbage, and count them as in cribbage. Then you play your hand in a quick match game, the scoring grid: find cribbage combos on a grid of cards, using your hand and the crib along its edges. Then pegging happens on a maze: every set you made on the grid becomes a play, and players take turns walking their plays through the maze, one step a point, instead of pegging along a board. Prizes along the way add cards and powers to the game.

The first token to reach the goal wins.

- Players: 2 or 3 (you and one or two computer players)
- Deck: one shared deck, starting as a standard 52-card deck plus extra cards: the title card, a blank card, and 0 or more jokers, decided each round when the deck is shuffled
- Length: about 6 to 12 rounds, like cribbage (the maze's size is tuned for it)

## How a game fits together

```
Game ............................ until a token reaches the goal
  Round ......................... one deal; the deal then passes left
    Stage ....................... deal and discard, cut, match turns, shop, pegging
      Turn ...................... one player's go within a stage
```

| Term | Meaning |
|---|---|
| Game | From setup until a token reaches the goal. Special jokers won as prizes, power slots, cards a joker made, and prizes in the deck last the whole game |
| Round | One deal, with every stage played once. The deal then passes to the left. How many jokers are in the deck is decided at each round's shuffle, and special jokers made by a joker's reveal last only for the round |
| Stage | One part of a round. In order: deal and discard, cut the starter, match turns on the scoring grid, the shop, pegging on the maze |
| Phase | A stage, or one step of the match turn. Every phase, in order, with what the first version includes: [concept.md › Phases](concept.md#phases) |
| Turn | One player's go within a stage: a match turn, or one play on the maze |
| Play | One set scored on the grid (or a hand or crib count), used on the maze: walked as its steps, or spent to close a door or flip a switch. Players take turns using them |
| Minigame | A game played in a stage beside or in place of a classic cribbage step. The match game is the first: it follows counting your hand. More may follow |
| Match turn | One player's turn of the match game, on the scoring grid. Its sets become that player's plays for pegging on the maze |

## Classic rules we use

Dealing, discarding, cutting the starter and his heels follow classic cribbage. Pegging doesn't: it's the maze (see 5). For the classic wording, see Scorekeep's How to play page: `~/projects/utilities/scorekeep/docs/rules/cribbage.md`. These rules only cover what's different, plus three-player play, which that page doesn't include.

## Setup

1. Make a maze sized so a typical game runs 5 to 13 hands. All tokens start on the start cell.
2. Shuffle the deck. Each player cuts, and the lowest card deals first.
3. Every player starts with empty power slots. How many: not designed yet.

## A round

### 1. Deal and discard

| Players | Deal | Discard to the crib |
|---|---|---|
| 2 | 6 cards each | 2 each |
| 3 | 5 cards each, plus 1 card face down to the crib | 1 each |

The crib belongs to the dealer and always has 4 cards.

Picking your crib cards is untimed. Drag your cards to sort them: the 4 you keep lie along the bottom of the scoring grid in that order, and only the last one touches the starter. If you pause, a hint may name one principle and blink the cards it's about, such as "Keep your 5s: every ten-card on the grid makes 15 with them." It never tells you what to throw. Tap Hint to see it sooner; turn hints off in the settings.

### 2. Cut the starter

Cut and turn up the starter as in classic cribbage. If it's a Jack, the dealer scores his heels: 2 steps, moved at once.

### 3. Match turns: the scoring grid

In classic cribbage you'd count your hand after pegging. In Crib RPG, each player counts their hand and then takes a match turn on the scoring grid, before pegging, in classic show order: the players after the dealer first, then the dealer, who plays the hand and the crib in the same turn.

The computer players' turns come first, summarized as a quick sequence of results (steps, best set and prize), with their hands kept face down until after pegging; you never watch them play their grids. Then you play yours, knowing what you have to beat. If you're the dealer, you go last, as in the show.

These are match rules r28, the version in the beta app, Noddy Yookerspiel. The web [match turn mock](mocks/match-turn.html) is frozen at r16. Each rules version is listed in [mocks/README.md](mocks/README.md#match-turn-rules-versions).

```
Match board (one player's turn)

  Steps 12 ............................ Stock (face down)

  . . . .   C        .  grid card, from the stock
  . . . .   C        H  your hand
  . . . .   C        C  the crib (dealer only)
  . . . .   C        S  the starter
  H H H H   S

  Power jokers: [swapper x2] [bomb x1] [reach x1] [ ]
```

A turn at a glance:

1. Your hand is counted with the starter, as in a classic show. If you dealt, so is your crib. Then the grid deals in.
2. Trace a set of 2 to 4 touching cards. It scores at once, counted like a cribbage hand.
3. Scored grid cards clear and the stock refills the grid. Your hand, crib and starter stay and power up.
4. Use your power jokers to change the board.
5. When the stock runs out, play out the cards that are left.
6. The turn ends on the timer, a cleared board, or a board with no sets left. Your best score wins a prize.

#### Setting up

The match turn's own phases (the show, the grid intro, the grid, the turn end) are listed with the rest of the game's in [concept.md › Phases](concept.md#phases).

1. Shuffle every card that isn't in a hand, the crib or the starter. This is the stock.
2. Lay your hand along the bottom, in the order you sorted it, and the starter in the corner. The dealer lays the crib down the side; for anyone else the side stays empty, so the crib is the dealer's advantage.
3. The show: count your hand with the starter, as in a classic show: fifteens, pairs, runs, a flush of your 4 cards (5 if the starter matches) and his nobs. If you dealt, count the crib the same way; a crib flush needs all 5 cards. Each count moves you that many steps. A card a joker made still multiplies its count, but edge power doesn't, nothing powers up, and the count is never your best set. A big count wins power jokers: 1 for every 5 points past 6, so 11 wins 1, 16 wins 2, 21 wins 3 and 26 wins 4 (to tune; r27). The hand and crib are ranked apart, and the jokers are picked like a prize, straight into your power jokers for this turn.
4. On a game's first turn, a card then says what the grid is for. Tap Start to go on.
5. Deal a 4 x 4 grid face up from the stock. The timer starts.

#### Tracing a set

Drag across touching cards and let go, or tap them one by one and tap the last one again. Drag back to undo the last card.

- Cards touch their 8 neighbours, diagonals included. Hand, crib and starter cards follow the same rule.
- Your hand size is how many cards a set can pick: 2 to 4, plus the starter, which joins for free. The hand size counter in the bar along the bottom shows how many you've picked. A reach joker raises your hand size for a while; later, some combos and prizes may too.
- A set MAY pick at most one card from your hand and crib together (the starter doesn't count). So every set includes grid cards: your hand and crib were counted at the start and can't score on their own again.
- The same set of cards can't score twice in a turn.

#### The starter joins every set

As in a cribbage hand, the starter counts with every set you score. You don't need to trace it, and it doesn't count toward your cards (tracing it does no harm).

- If the starter is part of a combo, it's in the set: it lights up, its power multiplies the set, it powers up, and its suit counts.
- If it isn't, it's ignored. It's never left over.
- The starter never costs a set points. A flush works as in a cribbage hand: 4 picked cards of one suit score, whatever the starter's suit.
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
| Flush: the 4 cards you picked all one suit score 4, or 5 when the starter matches too. 3 picked cards and a matching starter score 4. There are no 3-card flushes | 1 per card |
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
- A set the game rejects for another reason costs nothing: fewer than 2 cards, more than one hand or crib card, or a set already scored.

#### After a score

The set's grid cards clear, the cards above them fall, and the stock fills the gaps from the top.

Your hand, crib and starter are edge cards. They stay, and they power up. Power multiplies the sets they're in, so there's one score: steps.

- Each edge card starts the turn at power 0.
- A set with powered edge cards multiplies its combos. Add up the power levels of its edge cards; the multiplier is 1 plus 0.1 for each level (level 1 is ×1.1, level 3 is ×1.3), with no limit (r21). A cap may come back as a mechanic you can see and change with jokers. Each card's chip shows its own multiplier, so you can watch it climb. Round to the nearest step. Cards left over aren't multiplied.
- After a set scores, each edge card in it goes up one level. The starter is in a set only when it's part of a combo.
- Power lasts the turn. Values: to tune (the mock has settings for the step per level, adding or multiplying levels, and the cap).

| Set | Edge power | Combos | Multiplier | Steps |
|---|---|---|---|---|
| 7-8, grid only | none | Fifteen, 2 | ×1 | 2 |
| 5 from your hand, 10 from the grid | the 5 at level 3 | Fifteen, 2 | ×1.3 | 3 (2.6, rounded) |
| 5 and 5 from your hand, 5 from the grid | levels 2 + 3 = 5 | Pair royal and fifteen, 8 | ×1.5 | 12 |
| The same, later in the turn | levels 4 + 4 = 8 | Pair royal and fifteen, 8 | ×1.8 | 14 (14.4, rounded) |
| 7-8 from the grid, K from your hand | the K at level 2 | Fifteen, 2; K left over, −2 | ×1.2 on the 2 | 0 |
| 7-8 from the grid, a joker-made 10★ ×1.25 | none | Fifteen, 2 | ×1.25 | 3 (2.5, rounded) |

Each set's steps carry its most common suit, for suit gates in the maze. A tie carries no suit (see Suit gates).

#### The score breakdown

Every score plays out part by part, like counting a hand aloud: the set's name and suit, each combo with its cards lit and a running total, cards left over, edge power, the power-up, then the total. The timer pauses while it plays, and a tap skips to the end. It starts slow and speeds up; its speed is a player setting.

#### Special jokers

Special jokers are jokers that carry an action. The ones you hold are your power jokers, kept below the board; others turn up on the board. Tap one to arm it; tap it again to cancel.

Your power jokers are one set for the whole game: the same cards work on the scoring grid and on the maze, each in its own way (2026-11-17). What you use in one phase is gone from the other.

| Card | On the scoring grid | On the maze |
|---|---|---|
| Swapper (⇄) | Trace a straight line of 2 to 4 grid cards. The line reverses; 2 cards trade places | Swap places with another token, not back in the same round |
| Bomb | Tap a grid card. It and its 4 neighbours (a plus shape) clear and refill, scoring nothing | Tap a door with an end within 10 steps of you: it opens if its number (strength left) is 12 or less, otherwise it loses 12 (to tune). Or tap a cell on another player's way, within 10 steps of them, for a mine: like a fire but worse. The next token over it loses 2 or 3 plays, and one that stops on it loses 6 or 7. Then it's gone, and the walk pauses on it while a card shows what blew up |
| Reach | Tap it and it works at once: your hand size (the cards a set can pick) goes up for a while. Usually +1 for about 20 seconds; sometimes +2, or 10 to 45 seconds (to tune). Reaches stack, up to a hand size of 6. A countdown shows over the reach card, and the extra cards show in violet on the hand size counter | Your next play picks its way at each junction, instead of following the arrows, and the arrows don't turn |
| Burn (flame) | Tap a grid card. It leaves the board and the deck for the rest of the game, scoring nothing. The deck can't be burned below 40 cards (to tune) | Set a fire on a cell on another player's way, within 10 steps of them. The next token through loses 1 or 2 plays; one that stops on it loses 4 or 5. Then it's out. Plays it can't take come off the next round. The walk pauses on the fire while a card shows what burnt, then goes on |
| Key | Tap it and it works at once: your hand size goes up by 1. One time in 4 that lasts the rest of the game; otherwise it lasts a while, like a reach (usually about 20 seconds), with its countdown over the key card. It stacks with reaches and other keys (odds to tune from stats) | Works by itself: one play goes past a door of another suit |

You start the game with 2 swappers, 1 bomb, 1 reach and 1 burn (to tune), and no key. You get more, keys included, from prizes, hand and crib bonuses, jokers and the shop.

- Special jokers you start with, win as prizes or buy last the whole game; what you don't use carries over to your next turn.
- Special jokers made by a joker's reveal last only for that round.
- Each type of special joker will get its own rules (uses, limits), balanced from stats later.

#### The deck lasts the game

The game is about building your deck. A card a joker makes stays in the deck for the rest of the game, and a burned card stays out. Either can then be dealt to anyone, in any turn. The deck shows on the deal screen and between turns: its size, the cards made into it, and the cards burned out of it.

For now a game is 3 turns (to tune), and the deal alternates. Your power jokers carry from turn to turn, and each turn's prize joins them. Whether there's one shared deck or one each is a setting while we decide (shared to start); with one each, what you make or burn changes only yours.

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

- A card is a new card of any rank and suit, made by the joker and placed in its spot. A scoring card is a new 5 or 10-value card (10, J, Q, K). Cards a joker makes are marked ★ and stay in the deck for the rest of the game. Each one also carries its own multiplier, shown on its chip: usually small (×1.05 or ×1.1), sometimes up to ×3 (to tune). It multiplies every set the card is in, on top of edge power.
- The teal joker's special joker is picked from every known special joker (the swapper, bomb and reach so far) and shuffled into this turn's stock. Drawn onto the board, it waits there until you tap it to use it. It can't be part of a set. If the stock is empty, it goes straight to your power jokers.
- When the prize doesn't go to the board, the stock fills the card's spot. If the stock is empty, the spot stays empty.

##### A joker dealt into a hand

A joker dealt into your hand (or the crib, or cut as the starter) is wild: it counts as whatever card scores best in each set, as in joker cribbage. Each joker also carries one power, which is enabled, and recharged, each time a set with the joker in it scores. A charged power waits until you tap the joker to use it. The power comes from the joker's kind (amber and teal each have their own); the wildcard joker rolls one of any power (decided 2026-11-15; which kind gets which power, and the details, are to design):

| Power | What it does |
|---|---|
| Reach | Hand size +1 for a while |
| Multiplier | A multiplier on the next set |
| Time | Seconds added to the clock |
| Surprise | A random item or power joker |

Not designed yet: items; the title and blank card prizes; how many jokers a round can have (n); each special joker type's own rules; and what happens when an extra card is dealt into a hand or the crib, cut as the starter or played in pegging.

#### Ending the turn

| When | What happens |
|---|---|
| The stock is empty or your card budget is used | Nothing refills. Gaps stay empty and you play out the cards left |
| No set on the board can score | The game says so. Use a special joker, or end your turn |
| You clear the board (every grid card gone) | The turn ends with a clear-board bonus (to tune; the mock gives 10 steps) |
| The timer runs out | The turn ends |
| No sets are left on the board | With no power jokers, the turn ends. With some, you have 25 seconds to use one (to tune), shown on the clock; a joker that opens up a set stops the count |

At the end, your best score wins one prize: a special joker for your power jokers. A bigger best score wins a better tier: common below 28 steps, rare from 28, epic from 34 (to tune; r25). How match prizes relate to maze prizes: not designed yet. Timer and budget: to tune (180 seconds and the whole stock for now).

Your token doesn't move during the turn. Each scoring set becomes a play, with its cards, steps and suit, used on the maze in pegging (see 5).

Computer players' match turns aren't played out on screen: you see each result (steps, best set and prize).

### 4. The shop

After the scoring grid, before pegging, each player visits the shop. Prices are placeholders, to tune; the shop is mocked in [mocks/shop.html](mocks/shop.html).

- **You pay with plays.** Pick whole plays whose steps cover the price. There's no change: steps over the price are lost. A play you spend is one you won't walk, or close a door with, on the maze.
- **At most 3 buys a hand.** The extra-buy card raises the limit by 1 for this hand and isn't a buy itself (a placeholder; a special joker may do this instead).
- **Your own stock.** Each player gets their own shelf each hand, drawn from their own dice stream. Computer players shop by the same rules.
- **The reroll** takes one slot on the shelf. It deals a new stock and costs more each time you use it. It isn't a buy.

What's for sale:

| Kind | Items | Lasts |
|---|---|---|
| Power jokers | Swapper, reach, burn, bomb, key (see Special jokers) | The game, in your tray |
| Deck edits | Clone, paint or nudge a card you kept, add a made card, or burn a card out of the deck. Each is a set offer, such as "Clone 5♥" | The game, in the shared deck |
| Play edits | Dye: give a play a suit. Join: two plays become one. Save: keep a play for the next hand | This hand (save: until the next) |
| Extra buy | One more buy this hand | This hand |

Placeholder prices, in steps: swapper and reach 12, burn 16, key 18, bomb 20; clone 10, paint and nudge 8, made card 14, burn a card 6; dye 6, join 8, save 10; extra buy 6. The first reroll costs 5, then 10, 15 and so on.

Later, the stock may also offer cards you've discovered in earlier games, such as a special joker you won or saw in a reveal, so the game reveals itself over many games (not designed yet).

### 5. Pegging on the maze

Pegging is the maze. Classic play to 31 is gone: all the scoring happens on the grid, and pegging is where those scores move you, in turns (decided 2026-11-17). It's an echo of classic pegging, where the cards you hold turn into scores one play at a time.

Every set you scored on the grid is a **play**, and so are your hand and crib counts from the show. A play has its cards, its steps (its points, after multipliers) and its suit. A typical hand gives each player about 14 plays and 226 steps (medium bot, r27).

Players take turns, starting with the player to the dealer's left, until every play is used. On your turn you must use one play, and you may play one joker, before the play or after it. You use a play in one of three ways:

- **Walk it:** move your token its steps (see Moving through the maze). Before you choose, the board shows where each play would take you.
- **Close a door with it:** put a door on an open passage that no token stands beside. The door takes the play's suit, and its steps as strength. A play with no suit can't make a door. You can close one door a hand (to tune).
- **Flip a switch with it:** see Switches.

You see every player's plays left and their total steps, but not their cards.

### Stuck: the maze stirs, or a duel

A player who ends a round no closer to the goal than they began it is stuck. At the next deal, the maze stirs for them: the door in their way fades (any suit wears it down, at half its strength), a star falls a few steps ahead, or a wall beside them opens. One stir a round, for the player furthest behind.

When two players are stuck, or one is stuck behind a door the other closed, they duel instead. A DUEL! screen takes over and the two play classic two-player pegging, back and forth to 31, as in cribbage (fifteens, pairs, runs, go, 31 and last card; see Scorekeep's How to play page), each with the 4 cards they kept this round (a player whose hand clashes, or isn't known, gets 4 from the rest of the deck). The higher score wins. A tie plays again once, with the other player leading; tied again, a coin decides. A duel between two computer players isn't shown: you see its result. Then the screen shows what it means: the door in the winner's way breaks, and the winner takes the loser's biggest play, its cards and steps.


Which play to use, and when, is the game: a big play can carry you through a door of its suit, and the order you arrive at a junction decides which way you go.

### 6. Next round

All cards go back into the deck, and the deck is shuffled. The deck lasts the whole game: cards a joker made stay in it, and burned cards stay out, hand after hand. The deal passes to the left.

## Moving through the maze

The maze is a grid of passages built from the game's seed, with one golden path from start to goal (900 steps in the mock, to tune for a game of 6 to 12 rounds), a few variants, doors and switches. Everything else is dead ends, which walks never turn into.

- **Variants** leave the golden path and rejoin it later, so the choice they give is about doors and cards. Every golden-path door gets a way round where the maze allows (about 9 in 10 do in the mock), with a door of another suit, or a longer way with no door. Shortcuts have a suited door at their entrance. Variants don't overlap, and there are no little loops: every way round is at least 30 cells (to tune).

- One point is one step, and you must take every step.
- Walks go forward. A walk never turns into a dead end or a pocket the goal isn't in; it only walks one when it has no other way.
- Walks avoid a door they can't open when there's another way. A token stopped at a door may turn back on its next play, or go in with a play of the door's suit.
- **Junctions.** Where two ways both lead on, a junction's arrow decides: you go the way it points, and the arrow turns to the other way for whoever comes next. Arriving first or second matters, since one way is often a loop that circles back.
- All tokens share the maze and may stand on the same cell.
- The game ends the instant a token reaches the goal.

### A play's suit

Each play's steps carry the suit that appears most often among its cards, hand, crib and starter included. If two or more suits tie for most, the steps carry no suit: they walk open paths, and wear down only doors with no suit.

| Set | Suits | Its steps carry |
|---|---|---|
| 7♥ 8♥ | 2 hearts | ♥ |
| 4♣ 5♥ 6♥ | 2 hearts, 1 club | ♥ |
| 5♠ 5♦ 5♣ J♣ | 2 clubs, 1 spade, 1 diamond | ♣ |
| 9♦ 6♠ 9♠ 6♦ | 2 diamonds, 2 spades | no suit (a tie) |
| 7♠ 8♦ | 1 spade, 1 diamond | no suit (a tie) |

So a set built around one suit is worth more than its steps: a run of 3 hearts wears down a heart door that a mixed run of 3 can't touch.

There are no gates (merged into doors, 2026-11-17).

### Doors

A door is a card laid across the path: its rank is the strength left, and its suit is the suit it needs. Only steps of its suit wear it down, and the steps spent on it don't move you. Steps of another suit stop at the door, and the rest of the walk is lost. A door with no suit is worn down by any steps.

- There are about 14 doors on the golden path (to tune), about 22 in a maze with the variants', so every stretch has a door to plan for. They get stronger toward the goal (6, 7, 8 and so on in the mock, to tune).
- A variant's door sits at its entrance, beside the golden path. Round a golden-path door, it has another suit and 60% of that door's strength; on a shortcut, a suit and half the steps the shortcut saves (to tune).
- A door you close takes your play's suit, and its steps as strength. Opening it needs the same suit, like any door.
- You can't close a door in the way of a player who closed one in your way this round.
- Damage stays on a door between turns, whoever did it. Once a door is down, it's open for every player.

### Switches

A switch is a pair of passages, one open and one shut, marked with the same letter. Flipping it (with a play) swaps them, for everyone. Each switch flips once a round, and no setting of the switches can cut a cell off from the goal.

### Fog

Each token sees a few cells around it (how many: to tune). Cells anyone has seen stay revealed.

### Jokers on the maze

You use one joker a turn on the maze, before or after your play (Special jokers, above, says what each does there).

**Landing on another player.** A walk that ends on another player's cell, using all its steps there, starts a duel (Stuck, above): classic pegging with your kept hands, and the winner takes the loser's biggest play. It doesn't count at the start, at a door (a walk stopped by a door, or spending its steps on one), or for a pair that has already duelled this round. The turn goes on after the duel. Stars sit along the paths, and a play that ends on one wins a joker: a key, swapper, burn, bomb or reach (odds to tune). In the mock, players start with the scoring grid's starting set: 2 swappers, a bomb, a reach and a burn.

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
