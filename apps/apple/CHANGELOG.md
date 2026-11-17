# Changelog

Crib RPG for Mac (called Crib Maze before 0.17.0) and its beta, Noddy Yookerspiel: changes a player would notice, newest first. Versions are `major.minor.patch`, pre-1.0 (PORTING.md › Versions). Spec changes are in the top-level [CHANGELOG.md](../../CHANGELOG.md).

## 0.21.1 — 2026-11-17

### Changed

- A card's multiplier is now a gold coin on its bottom left edge, so it no longer covers the HAND, CRIB and STARTER tags. A joker-made card's ★ sits inside the card, under its rank, and the numbers showing your trace order sit at the bottom right.

## 0.21.0 — 2026-11-17

### Added

- The grid deals in five different ways, one picked each turn: rain, a deal from the deck, a spiral, a wave from your hand's corner, or a scatter of tossed cards.

## 0.20.1 — 2026-11-17

### Changed

- The card that explains the grid shows on a game's first turn only.

## 0.20.0 — 2026-11-17

### Added

- After your hand and crib are counted, a card explains the grid: collect more steps by matching crib hands across touching cards. Tap Start to deal the grid in and start the clock.

### Changed

- Power jokers from a big count come sooner: 1 for every 5 points past 6, so an 11 wins 1 and a 16 wins 2.

## 0.19.0 — 2026-11-17

### Added

- A big hand or crib count wins power jokers: 1 for every 5 points past 10, so a 15 wins 1 and a 20 wins 2. They land in your power jokers before the grid deals in, ready for this turn.

## 0.18.1 — 2026-11-17

### Changed

- Prizes are easier to win again, now that a set uses only one hand or crib card: rare from a best set of 28 steps, epic from 34.

## 0.18.0 — 2026-11-16

### Added

- Each turn starts by counting your hand with the starter, as in cribbage, then your crib if you dealt, over the empty board. The steps land, then the grid deals in.
- Drag your cards to sort them while you pick for the crib. The 4 you keep lie along the hand row in that order.

### Changed

- A set can use only one card from your hand and crib, since they've already been counted.
- The deal's button says "Pick 2 for the crib", then "Score the hand" once you've picked.

## 0.17.0 — 2026-11-16

### Added

- Settings › Game has Restart game, which plays the current game again from its first turn, with the same deal.

### Changed

- The release app is now called Crib RPG (it was Crib Maze). The beta is still Noddy Yookerspiel.

## 0.16.0 — 2026-11-16

### Changed

- Crib Maze uses Saira Semi Condensed, the game's own typeface, with suits and stars drawn as shapes to match it. Noddy Yookerspiel keeps its current look for now; launch it with `--saira` to try the new one.

## 0.15.4 — 2026-11-16

### Changed

- About Noddy Yookerspiel and the settings title show which build this is and what it plays, as `Mac 0.15.4 · spec 2 · r23`.

## 0.15.0 — 2026-11-16

### Changed

- Each game is now saved as one record, written as you play, instead of one file per turn. Settings › Advanced › Show the game record finds it. Records from earlier builds stay where they were.

## 0.14.0 — 2026-11-15

### Added

- A game is now 3 turns, and the deal alternates. Next turn starts the next one; New game starts over.
- The deck lasts the game. Cards a joker makes stay in it, so you or the bot can be dealt them in later turns.
- A new power joker, Burn: tap a grid card to take it out of the deck for the rest of the game. You start with 1, and prizes can win more. The deck can't go below 40 cards.
- The deck shows on the deal screen and after each turn: its size, the cards made into it and the cards burned out of it, with this turn's changes outlined.
- Your power jokers carry over from turn to turn, and each turn's prize joins them.

### Changed

- The Shared deck switch now works. Off, the cards you make or burn change only your own deck. It takes effect at the next game.

## 0.13.0 — 2026-11-15

### Added

- Settings › Advanced has a Shared deck switch, on by default. It decides whether cards jokers change go into the deck everyone is dealt from or into your own. It does nothing yet: deck edits aren't built.

### Changed

- Prizes are harder to win, to match scores without the power cap: rare from a best set of 40 steps, epic from 70.

## 0.12.0 — 2026-11-15

### Added

- Each turn starts with a deal at the table: the bot's cards face down across the top, the crib's 4 spots and the deck in the middle, and your 6 held in a fan along the bottom. Tap 2 to throw them to the crib (tap one there to take it back). Once you throw, the bot's 2 land face down, the starter is cut and turned, and the turn starts. It's untimed. Pause, or tap Hint, and a hint names one thing to look for and blinks the cards it's about. It never tells you what to throw. Turn the deal off in the settings to go straight to the grid.

### Changed

- Edge power has no limit: each level adds another ×0.1 to the sets its card is in, however high it climbs. Scores run much higher, so prizes come easier for now.

### Fixed

- A score's breakdown shows how edge power adds up: each powered card as +0.2 and so on, so Total multi matches.

## 0.11.0 — 2026-11-15

### Added

- Cards a joker makes carry their own multiplier, usually small (×1.05 to ×1.25) and now and then up to ×3. It shows on the card's chip and multiplies every set the card is in. The score's breakdown shows it as a Joker card line.

### Changed

- Hand, crib and starter cards now power up 10% at a time, up to ×1.5, so each power-up shows. Before, one power-up reached the cap and later ones did nothing.
- The clock's pulse quickens and deepens as time runs out, and the clock shows the last 10 seconds.

## 0.10.0 — 2026-11-15

### Added

- A new power joker, the reach. Tap it to raise your hand size, the cards a set can pick, for a while: usually +1 for about 20 seconds. A countdown shows over the reach card, and the extra cards show in violet on the counter. You start with one, and prizes can win more.
- The card counter is now the hand size counter.
- In a score's breakdown, the line that combines the edge power multipliers is now called Total multi.
- Turn records note each reach and what was scored under it, so its effect can be measured.

## 0.9.2 — 2026-11-15

### Fixed

- Tapping the card counter explains it again; the rest of the bottom bar still opens the settings.

### Changed

- The README has screenshots, and the plan, to-do list, rules and release notes are tidied for the current beta.

## 0.9.1 — 2026-11-15

### Changed

- The beta is now called Noddy Yookerspiel. Its saved turn records move to the new name's folder the first time it saves a turn.

## 0.9.0 — 2026-11-15

### Added

- Hints. When no sets are left and you hold power jokers, the power jokers panel blinks. Turn hints off under the gear's Game tab.
- When a score's breakdown ends, its total floats up from the scoresheet to the step count.

### Fixed

- Four cards of one suit score a flush again, whatever the starter's suit; a matching starter makes it 5. The starter now never costs a set points (match rules r18).

### Changed

- There's no gear: tap or click the top (the step count and track) or the bottom bar to open the settings.
- The clock breathes slowly while it runs, so you can tell the turn is live.
- The step count reads "steps scored".

## 0.8.4 — 2026-11-15

### Changed
- There's no End turn button. A turn ends when the timer runs out, the board is cleared, or no sets are left. If you still hold power jokers, you get 25 seconds to use one first.
- The power jokers panel fills the width, with bigger cards and empty slots for jokers you haven't found yet. The step count is bigger.
- The card counter, timer and gear move to a lighter bar along the bottom, under the power jokers, which now sit close under the board. The line under the board is a single line, and the game is only as tall as it needs to be.
- The timer is a clock with no numbers: a green wedge grows until it fills the circle. It turns orange in the last 10% of the time, pulses orange while a stuck board waits for a power joker, turns red when the turn is over, and is grey with the timer off.
- The gear's settings are in three tabs: Game (next turn, the last score and this turn's log), Advanced and Animation. The seed field shows the current seed; type another to replay it.
- The stock shows as a number in a gold badge on the deck. "Your match turn" and "Stock" are gone from the top line.
- The turn's log of scores moves behind the gear, and the help line under the board is gone. That line now only shows what a trace would score, an armed joker's next step, or that no sets are left.

### Fixed
- A long score breakdown, with many fifteens, shrinks to fit on the board instead of spilling past it.

## 0.8.3 — 2026-11-15

### Changed
- A set picks 2 to 4 cards (was 5), plus the starter, which still joins for free (rules r17).
- Settings, the last score and the turn's feed are behind the gear in the top line, so the window is just the game.
- The window fits the game exactly, so nothing is cut off. On a short screen, the whole game scales down to fit.
- The strong and medium bots are re-tuned for 4-card sets, so strong scores more than medium again.

## 0.8.2 — 2026-11-15

### Changed
- A match turn's timer starts at 180 seconds (was 90).
- The tray is now called power jokers, on screen and in the rules.
- Crib Maze (the version for players) no longer shows the animation diagnostics, which are for testing.

## 0.8.1 — 2026-11-15

### Changed
- Edge power multiplies a set by at most ×1.5 (was ×2), so the starter joining every set doesn't run scores away.
- Prizes are rarer: a best score of 25 wins a rare prize and 31 an epic one (were 8 and 16). A medium bot now wins about 60% common, 25% rare and 15% epic.

### Fixed
- The score breakdown's background covers the whole board, so no stray borders show through it.

## 0.8.0 — 2026-11-15

### Added
- The starter counts with every set you score, as in a cribbage hand (rules r16). You don't trace it and it doesn't use up a card. When it's part of a combo, it lights up, its power multiplies the set and it powers up. It's never left over.
- A card counter beside the help line shows how many cards you've picked and how many a set can take. The starter is free.
- Tap the HAND, CRIB, STARTER or POWER JOKERS tag, or the card counter, to read what it does.

### Changed
- The starter sits on a lighter bed of its own, so it reads as special.
- A score's breakdown waits for a tap or click at the end before the board moves on. Tapping earlier skips to the end.
- A score's cards fly up from the board into a row, with the starter on the right, and the breakdown plays over that row. Each line of the breakdown shows its cards: the combo's cards, the powered card, or the card left over.
- The tray is bigger and sits on its own panel, tagged POWER JOKERS.
- The match turn mock now plays r16, with a setting to turn the starter rule off. It's frozen there: Crib Maze Beta is the match turn mock from now on.

### Fixed
- Card moves in Crib Maze Beta are smoother, and a card's tags, power chip and badges now move with it instead of staying behind.
- Crib Maze Beta no longer pauses for a second or so at launch.

## 0.7.0 — 2026-11-14

### Added
- Crib Maze Beta for Mac: play a match turn on the 4 × 4 grid with your hand, crib and starter around it. Drag across touching cards, or tap them and tap the last one again.
- The beta shows what a set would score as you trace, lights the cards in combos, and breaks down each score.
- Swappers, bombs, jokers, edge power, the 90-second timer and prizes work as in the match turn mock (rules r15).
- Each score plays its breakdown as in the mock: a SINGLE or MULTI banner, combos counted one by one over the cards, edge power, left-over costs and power-ups. Tap to skip, or turn it off or speed it up in the side panel.
- Cards fall, drop in from the stock, swap and blow up with animations, so you can follow where they go.
- Pick a seed to replay a deal, or try the strong hand. Each finished turn is saved as a record you can open from the side panel.
- Maze retro looks mock: three retro styles for the maze tiles and pieces to choose from.
- Neon asset gallery: the chosen vector arcade look for the table, jokers and the maze, with a page that tracks every asset. Cards keep their original faces, which read better.
- Crib Maze Beta uses the neon table colours, with the original cards on top.

## 0.6.0 — 2026-11-14

### Added

- Maze walk mock: walk your steps through a maze to the goal, like Labyrinth. Each seed builds its own maze and deals its own rounds, so changing the seed shows another game. Choose a way at forks, pass suit gates on shortcuts with the right suit, break down doors, and win items from prize cells: a jump ahead, a skeleton key or extra steps. Fog is optional.
- Maze walk: every cell sits on a visible grid, walls are bold, the start and goal have their own pads, doors are wooden planks showing their strength, gates are suit plates, and a legend under the maze names each one.
- Maze walk: you see a quarter of the maze at a time, with bigger cells. The view scrolls as you walk, either when you near its edge or keeping you centred, and a pointer shows which way the goal is.
- Maze walk: you play against 1 or 2 bots, taking turns making plays as in pegging. The seat after the dealer goes first, the deal passes each round, and a player with no plays left says go. The view follows whoever's turn it is, and the first to the goal wins.
- Maze tiles: a style guide showing every tile and icon in the maze at game size, with sliders to tune them, so the maze's look can be reviewed and changed in one place.
- Maze inspiration notes: what Labyrinth, Mario Party, Slay the Spire, Balatro, Karuba and others could lend the maze.

### Changed

- Maze walk: what you spend is now called plays (it was steps to spend).

- Rules: bouncing off a suit gate of the wrong suit costs one step, and the rest of your steps walk back the way you came.

### Fixed

- Maze walk: a token caught between two gates of other suits could bounce forever. Bouncing off a gate now costs a step.

### Removed

- Rules: shifting walls, for now. The maze stays fixed, so the route from start to goal is always the same number of steps.

## 0.5.1 — 2026-11-14

### Added

- Engine spec, draft 3: a full game of classic cribbage for 2 or 3 players (cut for deal, deal and discard, the cut, the play, the show and winning), with three classic bot levels. The simulator plays it as the baseline that Crib Maze is measured against.
- The game's settings files: match turn rules, jokers, bots, timing and the classic game, so the app, the bots and the simulator all read the same numbers.
- Shared test cases for counting hands, classic hands (the 29, flush rules, his nobs), pegging and the dice, so every version of the game counts the same way.

### Fixed

- Match turn: a set with two separate runs (possible in sets of 6 or more) now scores both, not just the higher one.

## 0.5.0 — 2026-11-14

### Changed

- Match turn: there's one score, steps. Your hand, crib and starter cards still power up, but now their power multiplies the sets they're in (×1.5 a level, levels added, up to ×2) instead of earning pips. Cards left over still cost their steps, unmultiplied.
- Match turn: edge cards show their multiplier (×1.5, ×2), and the score breakdown shows each powered card and the multiplier it gives the set.
- Jokers: the title and blank cards' +5 pips prize is now +5 steps.
- Match turn settings: the multiplier per level, whether several edge cards add or multiply, and the cap.

### Fixed

- Match turn: a set with five or more cards of one rank (possible once a joker makes extra cards) stopped the game with an error. It now scores 2 for every pair in it, so five of a kind is 20.

### Removed

- Pips. What the shop takes instead is still to be designed.

## 0.4.1 — 2026-11-14

### Added

- Engine spec, draft 1: exactly how a match turn plays at rules r14, from the shuffle to the prize, so the app, the bots and the simulator play the same game from the same seed.

## 0.4.0 — 2026-11-14

### Added

- Match turn: the turn begins with the grid dealing in column by column, then your hand, crib and starter sliding into place. The timer starts once the deal is done.
- Match turn: clearing the board ends with a gold flash, confetti and a "Board cleared!" banner with your bonus. Any other ending is a quiet wrap-up: what's left on the board dims and a banner says why the turn ended.
- Match turn: tap to skip the deal or the ending. A setting plays them full, quick or off.

### Fixed

- Match turn: pressing End turn during a joker reveal or a score no longer ends the turn underneath it; End turn waits until they finish.

## 0.3.1 — 2026-11-14

### Added

- Plans for the Crib Maze app: a Mac beta first for playing, replaying and tuning games, then iOS. Its rules engine is Swift, replacing the planned Python one, so the app, bots and simulator all play by the same code.

## 0.3.0 — 2026-11-14

### Added

- Match turn: a card that isn't part of any combo in your set is left over. The first time, a warning explains this; after that, the set still scores its combos, minus 2 steps for each card left over. Your steps can go below 0.
- Match turn: while you trace, cards in a combo light up bigger and brighter, so a dimmer card is one that would be left over.
- Match turn: each round's deck holds 0 to 2 jokers, amber or teal, plus the title card and a blank card. When one lands on the board, play pauses, a shuffle, wheel or die decides what it becomes, and the prize is revealed (bigger for rarer prizes) and flies to the board, the stock, your tray or your pips. Tap to skip. The chances stay hidden.
- Match turn: a card a joker makes is a new card, marked with a star, and stays in the deck for the game.
- Match turn: a special joker shuffled into the stock waits on the board until you tap it to use it.
- Card designs: the title card and a blank card, plus an amber joker (star) and a teal joker (moon).
- Joker mock: draw any of the four extra cards and watch the same reveal as the match turn. Game-maker panels edit the hidden chances and simulate 10,000 games.

### Changed

- Swappers and bombs are now called special jokers. A joker is any card outside the standard 52 that does something.
- Rules: a new section names the parts of a game: rounds, stages, turns and minigames. The shop is its own stage, and sells jokers and any card you've discovered in any game.
- Match turn rules and the mock's How to play are shorter, with tables for what scores, cards left over, special jokers and how a turn ends, and a diagram of what touches the starter.
- Match turn mock: the panels beside the phone are now tabs, so you can switch between how to play, settings, the breakdown, runs and the log while looking at the board.
- Match turn: swiping picks a card only near its centre, so diagonal swipes no longer catch the cards beside them. A setting changes how near.

### Fixed

- Match turn: watching a bot below perfect could stop with an error when it went to use a swapper.

## 0.2.0 — 2026-11-14

### Added

- Match turn: every score now plays its full breakdown on the board, combo by combo. Tap to skip it, or replay the last score.
- Match turn: each set shows its suit, or "no suit" on a tie, and the turn summary shows steps by suit.
- Match turn: clear every grid card to end the turn with "Board cleared!" and a clear-board bonus.
- Match turn: when no set can score, the game tells you and points you to a special card or End turn.

### Changed

- Match turn: when the stock or card budget runs out, you play out the cards left on the board instead of the turn ending.

### Removed

- The separate score breakdown mock. It now lives in the match turn.

## 0.1.0 — 2026-11-14

### Added

- Crib Maze: a concept, a player-facing rules draft and a stats plan for cribbage on a maze, where match turns replace counting hands.
- Card designs: standard cards with four-colour suits that all pass 4.5:1 contrast, a crosshatch back, and swapper and bomb jokers.
- A playable match turn mock in an iPhone frame. Trace touching cards to score cribbage combos with your hand, crib and starter, earn pips from edge power, win a prize for your best score, and use swapper and bomb cards.
- Watch a bot play a match turn at four skill levels, from weak to perfect.
- Playtest runs: every finished match turn is saved with its rules version, and Copy runs or Download runs takes them out for tuning.
- A score breakdown mock that counts each score aloud, combo by combo, starting slow and speeding up.
