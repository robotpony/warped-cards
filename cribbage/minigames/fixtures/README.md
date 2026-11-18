# Fixtures: the conformance kit

Shared test cases for every build of the engine: the JS mocks, the Swift engine, and any port. A port is done when it passes every rung below, in order. Each rung only needs the ones above it. The spec for each is in [engine.md](../engine.md); how to port is in [PORTING.md](../../../PORTING.md).

| Rung | File | Spec | Passing means |
|---|---|---|---|
| 1 | `dice.json` | Dice | Raw outputs, draws below n, weighted picks and a shuffle of 52 match for every seed and stream |
| 2 | `counting.json` | Counting a set | Every case gives the same combos, in order, with the same card indexes, total and left-over cards |
| 3 | `classic-hands.json` | Classic cribbage › The show | Every hand and crib counts the same |
| 4 | `pegging.json` | Classic cribbage › The play | Every play scores the same, in order |
| 5 | `records/*.jsonl`, read | Records | Every record reads: header, steps, end. Unknown kinds are skipped |
| 6 | `records/*.jsonl`, scripted | Records, Actions, Events | Fed the recorded rolls, the engine gives the same events at every step |
| 7 | `records/*.jsonl`, verify | Dice, Bots, every rules section | From the seed alone, the engine draws the same rolls and gives the same events at every step |
| 8 | `records/*.jsonl`, written | Records › Encoding | Writing each game again gives the same bytes, ignoring `at` |

Rung 6 before 7: scripted replay checks the rules without the dice, so a dice bug and a rules bug show up apart. Rung 7 also checks the bots, since the records are bot games.

`pegging.json` covers classic pegging, which the Swift engine doesn't play yet.

## Who checks what today

| Build | Rungs | How |
|---|---|---|
| JS mocks | 1 to 4 | `node --test cribbage/minigames/` |
| Swift | 1, 2, 3, 5 to 8 | `swift test` in `engine/swift/` (`CribMazeTests` › golden records) |

## Making fixtures

- `make-dice.js` writes `dice.json` from `mocks/dice.js`. Rerun it only when Dice changes, and say so in the commit.
- `make-counting.js` fills in card indexes from the mock counter and stops if it disagrees with a hand-worked total.
- `swift run cribmaze-sim record --games 1 --seed 1 --out ../../cribbage/minigames/fixtures/records/seed1.jsonl` (from `engine/swift/`) re-records the golden game. Re-record only when a rules change breaks it on purpose, and say so in the commit. A re-recorded game is a new reference for every port.
- `spec.test.js` isn't a fixture: it checks that `engine.md` names every action and event the Swift engine writes, with its fields, and shows every config file's shape. When it fails, fix the spec (or the code) in the same change.

## What the records don't reach yet

`seed12.jsonl` is a second 3-hand bot game, kept for the opening bonus (r26): its second hand counts 24, ×1.31 from a made card, for 31 steps and 5 power jokers (r27). Re-record it with `--seed 12` as above.

`seed55.jsonl` is a third, kept for the key joker (r28): a key for the game in hand 1, carried into hands 2 and 3 (`keyCards` in `turnStart`), and a timed key used from the board in hand 2. Re-record it with `--seed 55`.

`seed1.jsonl` is a 3-hand bot game: deals and discards (with a sorted `kept`), opening counts of hands and cribs, traces, swaps, bombs, reaches, extra cards and made cards, stock out, no sets left and cleared boards. It never has a burn, a `reachOver`, `timeUp` or `endTurn`, a rejected trace (Swift's OpeningTests check `edge_cards`), a left-over warning or penalty (bots are always warned and never trace a bad set), or own decks. Add a record when a rules version adds something the records don't reach (scripted actions in a test are fine), so every port is checked on it.
