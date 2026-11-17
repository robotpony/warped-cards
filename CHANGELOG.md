# Changelog

Spec changes, newest first: what a port has to change to stay in step (PORTING.md › Versions). The spec version is `specVersion` in [spec.json](cribbage/minigames/spec.json). Each platform's builds have their own changelog, such as [apps/apple/CHANGELOG.md](apps/apple/CHANGELOG.md).

## spec 9 — 2026-11-17

Rules unchanged (r27).

### Added

- `fx.json` › fill: the grid's first deal-in comes in one of five patterns (rain, deal, spiral, wave, scatter), picked from the turn's seed on the presentation-only stream `fx.fill` (ui.md › The grid fills). Refills still fall from above. `seed1.jsonl` and `seed12.jsonl` are re-recorded with spec 9 in their headers.

## spec 8 — 2026-11-17

Rules unchanged (r27).

### Changed

- ui.md: the grid intro shows on a game's first turn only (Scene: Match turn › The opening count).
- concept.md › Phases lists every phase of a game in order, with what the beta has and what the first version targets; rules.md, ui.md and engine.md point to it. `seed1.jsonl` and `seed12.jsonl` are re-recorded with spec 8 in their headers.

## spec 7 — 2026-11-17

Match rules r27 (concept.md › Decisions, 2026-11-17).

### Changed

- The opening bonus starts lower: `match.opening.bonus.from` is 6 (was 10), so 11 wins 1 power joker, 16 wins 2, 21 wins 3 and 26 wins 4. `seed1.jsonl` and `seed12.jsonl` are re-recorded; seed 12's 31 now wins 5.

### Added

- ui.md: the grid intro, a card after the opening count that says what the grid is for and waits for Start before the grid deals in and the timer starts (Scene: Match turn › The opening count). The reference set adds `grid-intro`.

## spec 6 — 2026-11-17

Match rules r26 (concept.md › Decisions, 2026-11-17).

### Added

- The opening bonus: `rules.json` › `match.opening.bonus` (`from` 10, `per` 5). A hand or crib count above `from` wins `(points − from) / per` power jokers for the tray, each picked by `prize.special` weights from the new dice stream `opening`, purpose `bonus` (engine.md › The opening count).
- The `opening` event gains `bonus`, the kinds won in the order drawn (an empty list when none), and the totals gain `openingJokers`.
- A second golden record, `seed12.jsonl`, whose second hand counts 24 × 1.31 = 31 and wins 4 power jokers. `seed1.jsonl` is re-recorded at spec 6.
- ui.md: the bonus toast, and each joker landing in the tray after the count's steps (Scene: Match turn › The opening count).

## spec 5 — 2026-11-17

Match rules r25 (concept.md › Decisions, 2026-11-17).

### Changed

- Prizes retuned for r24's lower scores: `rules.json` › `match.prize` is rare from a best set of 28 steps and epic from 34 (were 40 and 70). Nothing else in the engine changes, but a port's game from the same seed now awards different prizes and so plays differently in later turns.
- `seed1.jsonl` is re-recorded at spec 5.

## spec 4 — 2026-11-16

Match rules r24 (concept.md › Decisions, 2026-11-16).

### Added

- The opening count: before the grid plays, the hand (and the dealer's crib) is counted with the starter as a classic show, from `rules.json` › `match.opening`, and emits `opening` (what, positions, cards, combos, comboPoints, madePercent, points). Made cards' multipliers apply; edge power, power up, left over and the best set don't. Its steps also go to the new `openingSteps` total (engine.md › The opening count).
- `match.maxEdgeCards` (1): a set picks at most that many hand and crib cards together, or the trace is rejected with the new reason `edge_cards` (engine.md › Trace, step 2b).
- The `discard` action takes `kept`, the player's other 4 in the order they lie along the hand row. Without it, the dealt order, as before. A bot in the player's seat sends its keep in card ID order.
- `seed1.jsonl` is re-recorded at spec 4: every hand now has `opening` events and a sorted keep, and the steps change.
- ui.md: the opening count over the empty board and the grid's deal-in (Scene: Match turn › Starting a turn), sorting the hand in the deal, and the deal button's new words. The reference shots and films add the opening count; the breakdown shots use a set with one edge card.

## spec 3 — 2026-11-16

### Added

- `config/fx.json`: every cue's motion (a spring with a duration and bounce, or an ease curve) and wait, which clients MUST read instead of copying numbers. ui.md › Motion says what each value is and how a spring's duration and bounce map to a damped spring's stiffness and damping. The values are the ones ui.md gave in words at spec 2, so nothing moves differently.
- The stuck board's wait before the turn ends comes from `timing.json` › profiles.human.ending (1,500 ms, as before).
- `seed1.jsonl` is re-recorded at spec 3; only its header's `specVersion` changes.

## spec 2 — 2026-11-16

### Added

- Record headers name the spec version the writer implements, as `specVersion` (engine.md › Records › Lines). Readers MUST accept records without it, written before spec 2. The golden record `seed1.jsonl` is re-recorded with it; its steps are unchanged.

## spec 1 — 2026-11-16

### Added

- The first versioned spec, covering rules `match-r23`: engine.md, ui.md (draft 1), the config files, and the fixtures with the `seed1.jsonl` golden record.
