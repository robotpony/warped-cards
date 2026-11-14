# Changelog

warped-cards' changes, newest first. Versions are `major.minor.patch`, pre-1.0.

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
