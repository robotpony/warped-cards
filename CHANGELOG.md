# Changelog

warped-cards' changes, newest first. Versions are `major.minor.patch`, pre-1.0.

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
