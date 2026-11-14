# Cribbage Mini-Games: Ideation

Status: ideation, 2026-11-13. Nothing here has been playtested.

> Superseded in part, 2026-11-13. Bruce chose one fixed combination: a maze replaces the pegboard and the play phase, and a match-n game replaces counting hands. See [concept.md](concept.md). The slot framework and components below still apply. The other modules are parked as ideas for later variants.

## Summary

Keep cribbage's deal, discard and crib, and turn the parts that come after into slots that mini-games plug into. Three slots exist: the Play (replaces pegging), the Show (replaces counting hands), and the Track (replaces the 121-hole board). Every module MUST report its result as points, so modules can be swapped without touching the rest of the game.

The first four to prototype are Nine Square, Liar's Pegging, Crib Auction and Called Shot. Each is playable with one 52-card deck and a pencil, and each pulls the discard decision in a new direction.

## Why this works

Cribbage's best decision is the discard: which 2 of 6 cards go to the crib, knowing the starter is still unknown. Pegging matters because it fights the discard. You want 5s and runs for the Show, but those same cards are risky to play into a count of 10.

A good mini-game keeps that fight going while changing what the fight is about. A mini-game that ignores the hand you built is just a separate game sitting on the table.

## Design principles

1. The deal and discard MUST stay as in classic cribbage. That's the heart of the game.
2. Each module SHOULD reward different cards from the Show, so the discard gets harder, not easier.
3. Cards played in the Play return to hand for the Show, as in classic pegging. Playing a card costs information, not the card.
4. A module MUST emit point deltas per player (`{dealer: n, pone: n}`), plus optional events. Nothing else crosses the slot boundary.
5. A module SHOULD take under 3 minutes at the table.
6. One standard deck. A module that needs a second deck or extra components is flagged as such.
7. Two players first. Three- and four-player rules come after a module survives two-player testing.

## Components

These are the shared pieces every module builds on. Most of them are also the full classic cribbage game, so building them serves both tracks.

| Component | What it does | Shared with classic |
|---|---|---|
| Deck and deal | Shuffle, cut for deal, deal 6 each (2p), crib of 4, cut starter, his heels | Yes |
| Hand scorer | Scores any set of cards for 15s, pairs, runs, flush, nobs; 4-card vs 5-card flush rule for crib | Yes |
| Running count | Count to 31, go, 31, last card, pairs and runs in sequence | Yes (pegging) |
| Round loop | Deal, Discard, Cut, Play slot, Show slot, Track slot, rotate dealer | Yes, with classic modules in each slot |
| Module contract | Inputs: hands, crib, starter, dealer, scores, seed. Output: point deltas and events | New |
| Track | Holds scores, checks win, skunk lines; swappable | Yes (121 board) |
| Bots | Simple players for simulation: greedy discard, random, heuristic | Yes |
| Sim harness | Plays thousands of games per module mix, reports stats | Yes |

Classic cribbage is then just the default module in each slot: Pegging, Classic Show, 121 Board.

### Rules source: Scorekeep

Classic rule wording comes from Scorekeep's How to play page, `~/projects/utilities/scorekeep/docs/rules/cribbage.md`. We reference it and MUST NOT copy it. The reasoning behind its house rules is in `docs/game-rules.md` § Cribbage in the same repo. Confirmed with the SCOREKEEP session on 2026-11-13.

What that means for us:

- Scorekeep is a scorekeeper, not a referee. It never sees cards and has no hand-counting code, so our hand scorer and running count are new code, tested against the rules on that page.
- House rules we inherit: crib scores only a 5-card flush; his heels 2 is its own event, not part of the play; last card is distinct from go; show order is pone, dealer, crib, and the game ends the instant anyone reaches the target; muggins off by default; no skunk scoring; target 121 or 61.
- If a variant ever reports into Scorekeep, the smallest path is finished-game Standings (players by name, winner flag) under its own game kind. Mini-game results don't fit Scorekeep's `Cribbage.Hand` shape. That's a later decision for Bruce, and Scorekeep's main branch is frozen at v1.

```
Round loop

  Deal 6 each .......... fixed
  Discard 2 to crib .... fixed
  Cut starter .......... fixed (his heels: dealer +2)

  [Play slot] .......... Pegging | Nine Square | Liar's Pegging | Crib Auction | Four Tricks
  [Show slot] .......... Classic | Called Shot | Poker Show | Head-to-Head
  [Track slot] ......... 121 Board | Tug of War | Event Board | Point Shop | Doubling Cube

  Rotate dealer
```

## Play slot modules (replace pegging)

### Nine Square

Both players' 4 cards plus the starter fill a 3x3 grid exactly. The starter goes in the centre. Players alternate placing one card into an empty cell, pone first.

```
  A  .  B        Lines: 3 rows, 3 columns, 2 diagonals (8 total)
  .  S  .        S = starter, neutral
  B  .  A        Edge lines: 3 player cards, majority always exists
                 Centre lines: 2 player cards + starter
```

Each line scores like a 3-card cribbage hand: 15s, pairs, runs of 3, a 3-card flush (1 point). The player who owns 2 or more cards in a line takes its points. Centre lines with one card each are dead, or go to the dealer (to test both).

Why it's good: it's tic-tac-toe with cribbage combos, the card count fits perfectly, and placement is a real decision every turn. It rewards different things from the Show: you want cards that combine with many others, and you want to block. Cribbage solitaire uses a 4x4 grid of hands, but the 2-player alternating placement with line majority is the new part.

Open questions: average points per hand (needs simulation to fit a 121 race); whether pone-first balances the dealer's crib.

### Liar's Pegging

Classic pegging, but cards are played face down and the player announces the new count. The opponent may challenge any play. If the card was a lie, the liar loses the points they claimed plus 2; if it was true, the challenger loses 2. Unchallenged cards stay face down until the Show, where lies are revealed and claimed points stand.

Why it's good: smallest rules change of any module, so it's the quickest to playtest. Experienced players already track the count closely; this rewards them for it. It also makes holding a 5 into a count of 10 a bluffing tool.

Open questions: whether lies found at the Show should cost anything (probably yes, or lying is free when unchallenged); how to stop runs getting tangled when an earlier card in the sequence was a lie.

### Crib Auction

The crib is no longer the dealer's. After the cut, crib cards are flipped one at a time. For each, both players secretly commit one card from hand and reveal together. Higher rank wins the crib card (ties to the dealer; starter's suit breaks rank ties if we want fewer ties). Each hand card can be committed only once, so 4 hand cards cover the 4 prizes. Won crib cards form each player's spoils, which is scored with the starter at the Show as a mini-crib.

Why it's good: it's Goofspiel bolted to cribbage. It turns the discard into a strange gamble: you're throwing cards you may have to fight for, so throwing a pair of 5s to the crib is an invitation. It also replaces the dealer's crib advantage with tie-breaks, which is worth checking in simulation.

Open questions: whether spoils should score with the starter or alone; whether high cards are too dominant (a variant: the starter's rank decides if high or low wins this hand).

### Four Tricks

Four tricks of trick-taking. Starter's suit is trump, pone leads, follow suit if able. Each trick scores 1; a trick whose two cards make 15 scores 2 more for its winner; winning all four scores 4 bonus.

Why it's good: trick-taking wants high cards and trump; the Show wants 5s, face cards, and runs. That's a strong pull in a new direction, and it's familiar to anyone who plays Euchre or Bridge.

Open questions: whether knowing the trump suit before discarding is needed (it isn't, the starter comes after the discard, which is the fun of it).

## Show slot modules (replace counting hands)

### Called Shot

Before the cut, each player secretly writes how many points their hand will score. At the Show, score the hand normally. Hit the call exactly: double it. Under the call: score as normal. Over the call: score only the call. The crib is scored normally.

Why it's good: one sentence of new rules and a real decision. Cribbage players already estimate hand value; the unknown starter makes the call a bet.

Open questions: whether "over the call scores only the call" is too gentle. Alternative: over scores zero.

### Poker Show

Hand plus starter is scored as a poker hand on a fixed table (pair 2, two pair 4, trips 6, straight 8, flush 10, full house 12, quads 16, straight flush 20). Crib likewise.

Why it's good: discard strategy changes completely; 5s lose their magic. Easy to explain to anyone who knows poker.

Open questions: point table needs simulation so averages sit near classic (about 8 to 9 points per player per round across hand and crib).

### Head-to-Head Show

Score both hands normally, but only the higher hand scores, and it scores the difference. Crib scores normally.

Why it's good: zero-sum, shorter games, less runaway luck. Risk: big hands feel less big.

## Track slot modules (replace the 121 board)

### Tug of War

One marker on a line from -31 to +31. Each player's points pull it their way. First to reach their end wins. Games are shorter and every point is also a point taken from the opponent.

### Event Board

The 121-hole track gets marked spaces, like a party board game. Landing exactly on one triggers an event mini-game (below) or an effect: swap a card with the crib next hand, steal 3, re-cut the starter. This is the "mini-games replacing the board" reading of the brief, and it can sit on top of any Play and Show modules.

### Point Shop

Points can be spent instead of banked. Prices are a first guess: peek at one crib card (3), re-cut the starter (5), discard 3 and draw 1 (6), double your next hand (10). Spending delays your own win, which is the tension.

### Doubling Cube

Backgammon's doubling cube, per hand or per game, for match play. Light rules, big swings.

## Event mini-games (triggered by the Event Board)

| Event | How it plays | Notes |
|---|---|---|
| Fifteen Snap | Flip deck cards into a row; first to slap a set summing to 15 takes the points | Real-time; strong for digital |
| High-Low | Guess higher or lower on the next deck card; bank or keep going; a miss loses the streak | Push your luck |
| Blind Cut | Both cut the deck; higher wins; a jack wins outright | Fast, pure luck, use sparingly |
| Spread Sprint | Flip 5 cards; both secretly write the best 4-card score in it; closest to correct wins | Rewards counting skill |

## Shortlist

| Module | Slot | Rules delta | Why first |
|---|---|---|---|
| Nine Square | Play | New placement game | Most original; perfect card count |
| Liar's Pegging | Play | Small | Fastest to playtest at a table |
| Crib Auction | Play | Medium | Changes the discard most |
| Called Shot | Show | One sentence | Cheap test of a Show-slot module |

The Track modules wait until at least one Play module works, since they mostly change pacing.

## How we'll test

1. Build the shared components first: deck, hand scorer, round loop, classic modules. Classic cribbage is the control.
2. Write each shortlisted module against the module contract.
3. Run the sim harness with simple bots, at least 10,000 games per mix. Measure points per round per player, dealer edge, variance, game length in rounds, and how often the discard choice changes versus classic.
4. Target: points per round within about 20% of classic pegging, unless we retune the Track. Dealer edge close to classic.
5. Physical playtests with Bruce for anything the numbers say is sane.

Average values for classic (about 4.7 per hand, 3.9 per crib, and roughly 4 in pegging for the dealer) are from memory and MUST be confirmed by our own sim before we use them as targets.

## Open questions

1. Target first: physical rules on paper, a digital prototype, or both?
2. Tech stack for the engine and sims (TypeScript would let the prototype run in a browser; Python is faster to sketch sims)?
3. Two players only for now, or keep 3 and 4 in view from the start?
4. Should a game mix modules per hand (a different Play module each round, picked by a card draw) or fix them per game?
5. Should variants default to Scorekeep's 61-point target, or 121? Mini-games may change points per round enough that neither fits without tuning.
