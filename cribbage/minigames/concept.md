# Crib Maze: Concept

Status: concept, 2026-11-14. Working title. The match turn has been mocked and bot-tested (match rules r15); nothing else has been playtested or simulated, so most numbers here are starting guesses.

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
- You trace sets of 2 to 5 touching cards, like words in Boggle. A set scores at once if every card is part of a cribbage combo, counted like a hand. A card left over costs steps, after a one-time warning, so guessing has a price.
- Every set needs a grid card, so the hand and crib can't simply be counted. The hand you built is what your sets grow from, and the cards beside it decide how well it does.
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
- Open: can you hold steps back for a later round? Must you land exactly on a cell to trigger it? How long can the walk take before it drags?

## Transitions and effects

Each part of a round is its own mini game, so moving between them, and starting and ending each one, needs its own moment. The match turn's begin and end effects are mocked (match turn mock v8, 2026-11-14); transitions between mini games wait until the other mini games are designed.

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
| 2026-11-15 | Players call the tray "power jokers": the on-screen tag and the rules say so. The engine and config keep the name `tray` |
| 2026-11-15 | Releases: Crib Maze for Mac, signed with Developer ID and notarized, posted as free pre-release demos on GitHub releases ([RELEASING.md](../../RELEASING.md)) |
| 2026-11-15 | A card counter shows how many cards a set can pick (the pick limit, `maxSet` for now). Some combos, jokers and prizes will raise it for a while; not designed yet |
| 2026-11-15 | A score's breakdown plays over a row of its cards, flown up from the board with the starter on the right, so it always sits in the same place instead of away from the set. It waits for a tap at the end, and each line shows its cards. The mock still plays over the board |

## Open questions

1. Which prizes go into the shared deck, and which does a player keep? Can you choose to keep a card instead of shuffling it in?
2. How many power slots, and how do you get more?
3. Can tokens get in each other's way at a gate or a fork?
4. Match turn timer and card budget: starting values come from the simulator. With play-out (r8), does a 180-second timer (raised from 90 on 2026-11-15) leave a person room to clear the board?
5. Edge power: is ×1.5 a level, levels added, capped at ×2 right? Bot tests so far (mocks/README.md › Match turn v9) say the cap matters most; the simulator should settle it.
6. Doors: how strong and how many? This decides how much of a match score becomes distance.
7. With match scores far above pegging, does pegging still matter? Doors treat both the same, so pegging may need its own edge.
8. The maze walk: how choosing bundle order plays, holding steps back, and how long it can take.
9. The shop: what you pay with now that pips are gone (steps, prizes or something new), what's for sale, prices, and whether bots shop the same way.
10. Clear-board bonus: steps or a prize, and how big?
11. Jokers and extra cards: what items and the title and blank card prizes are, how many jokers a round can have (n), each special joker type's rules, and what happens when one is dealt into a hand or the crib, cut as the starter or played in pegging.

## Plan

Two tracks run side by side: design, so we can think about how the game plays and feels, and engine, so we can measure it.

| Phase | Track | What | Status |
|---|---|---|---|
| 1 | Design | Rules draft ([rules.md](rules.md)) | Draft done; kept in step with decisions |
| 2 | Engine | Stats and simulator ideation ([stats.md](stats.md)) | Ideation done |
| 3 | Design | First mocks, clickable HTML in an iPhone frame. Cards (v2), match turn (v9, rules r15, with the score breakdown, joker reveals and begin and end effects), jokers (v3). The prize pick, shop, maze walk and pegging on the maze move to phase 6 | Done, but for playtests |
| 4 | Engine | Engine spec: data model, event log, bot interface, sim clock | After 3 is planned |
| 5 | Engine | Swift engine, bots, simulator and stats reports; classic cribbage as the baseline ([ARCHITECTURE.md](../../ARCHITECTURE.md) phases A to D) | After 4 |
| 6 | Design | Maze, prizes and shop: doors, prizes and power slots, door types, branches, traps, fog, generator; mocks of the prize pick, shop, maze walk, pegging on the maze and transitions between mini games | After 5 |
| 7 | Both | Tune with simulation until the numbers hold up | After 5 |
| 8 | Design | Face-card art: full graphics for J, Q and K (letters until then) | Not scheduled |
| 9 | Design | Card backs: design more backs (crosshatch until then) | Not scheduled |
| 10 | App | Mac beta app, then iOS ([ARCHITECTURE.md](../../ARCHITECTURE.md) phases E to I) | Beta after 5; iOS after 7 |
