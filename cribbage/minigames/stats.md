# Crib Maze: Stats and Simulator

Status: ideation, 2026-11-14. Phase 2 of the plan in [concept.md](concept.md).

## Summary

Stats have two main jobs:

1. Balance: compare scoring curves between bots. How fast does each kind of player move through the maze, where do their steps come from, and does any strategy, seat or prize pull too far ahead?
2. Timing: how long real games, rounds and turns would take.

The engine records every event in a log from the first build. The simulator plays bot games on a modelled clock and can run at a chosen multiple of real time, such as 100x or 1000x, so we can see how long real games would last without waiting for them. Classic cribbage runs through the same engine as the baseline, so every comparison is against something measured, not remembered.

## Principles

1. Log events, not totals. Totals can be rebuilt from events, but events can't be rebuilt from totals.
2. Every event carries a time on the modelled clock, so timing comes from the same log as scoring.
3. Every game can be replayed from its seed and the players' choices.
4. The Python simulator and the Swift app use one event format, so real and simulated games can be compared.
5. Classic cribbage is the baseline. We measure it in our own simulator before setting targets.
6. A stat earns its place by answering a tuning question. If nobody would change a rule because of it, cut it.

## Scoring curves

A scoring curve is a player's position in the maze (steps from the start along the main route) plotted over the game. We plot it against round number and against modelled time.

What we compare:

- Bot against bot: random, greedy and planning, and the same bot with different skill settings, such as marking skill.
- Seat against seat: dealer first or second, and seat order with 3 players.
- Rules against rules: the same bots under two rule sets (A/B), so a rule change shows its effect directly.
- Crib Maze against classic: the same bots playing classic cribbage, with points instead of steps.

What we look for:

- Spread: how far apart the curves end up, and how early a game is decided.
- Lead changes, and comebacks from behind at the halfway point.
- Where steps come from: his heels, pegging (by reason), match turns (by match type), marked patterns, power levels, prizes.
- Flat spots, where a player is stuck at a gate or bounced back, and sudden jumps from cascades or prizes.

## Timing

Each action has a modelled duration: playing a card, choosing at a fork, a swap, marking a pattern, choosing a prize, and watching animations. There are two profiles to start with: human speed and bot speed (what a bot turn looks like on screen). The durations are guesses until mocks and playtests give us real ones.

From the modelled clock we report:

- Length of a game, a round, a pegging phase and a match turn.
- Waiting time: how long the human waits during bot turns.
- How match turns play out as the stock is used up: swaps, matches and steps over time, and where returns flatten. This is how we set the turn timer and card budget.

## Simulator

- Runs N games for a configuration (players, bot levels and skills, maze size, rules options, timing profile) from a base seed.
- Runs at a chosen speed against the modelled clock: 1x (real time, to watch a game play out), 100x, 1000x, or as fast as possible for bulk runs. The speed only changes how fast results arrive; the modelled times in the log are the same at any speed.
- Writes the event logs, then a report: scoring curves, timing, and each stat below with its average, its spread and a check against its target.
- Compares two configurations side by side.
- Includes classic cribbage as the control.

## Event log

One JSON Lines file per game. Each line is one event, with a sequence number, modelled time, round, player and type. The rules version is in every log, so logs from old rules don't get mixed with new ones.

| Group | Events |
|---|---|
| Game | game_start (seed, players, bot levels, maze size, timing profile, rules version), round_start, game_end (winner, positions) |
| Deal | deal, discard (kept, thrown), cut, heels |
| Pegging | card_played, peg_score (reason, points, scoring card), go |
| Maze | step, fork_choice (options, choice), gate (suit, passed, bounced, stopped), prize_cell, wall_shift, fog_reveal |
| Match | turn_start (stock size), swap, match (type, length, cards, edge card), cascade (depth), mark (pattern, cards), missed_pattern, power_up (card, level), reshuffle, turn_end (reason: timer, budget or empty stock) |
| Prizes | prize_won (source, tier, kind), prize_placed (deck or player layer), prize_used |

## Other stats

These back up the curves with specific checks.

| Question | Stat |
|---|---|
| Is the game the right length? | Rounds per game; modelled time per game |
| Is it fair by seat? | Win rate by seat and by first dealer |
| Is the match turn too strong or weak? | Match steps vs pegging steps per round; matches, cascades and multi-matches per turn |
| Does the hand still matter? | Link between a hand's classic value and its match-turn steps; how often the best discard differs from classic's |
| How much does marking matter? | Patterns available vs marked, by marking skill; steps lost to missed patterns |
| Is the maze working? | Branch choices, gate bounces and steps lost, prize cells reached, wall shifts and who they hurt |
| Are prizes balanced? | Prizes per game by tier and source; win rate by prizes held; how often deck prizes help someone else |

## Targets

These are placeholders until we've measured classic cribbage in our own simulator:

- Game length within about 20% of classic for the same target (61 or 121), in rounds and in modelled time.
- No seat wins more than a few points above a fair share (50% with 2 players, 33% with 3).
- Pegging and match turns each give a real share of steps; neither SHOULD dominate.
- Prizes SHOULD change results often enough to matter, but a player with no prizes SHOULD still be able to win.

## App telemetry

Decided 2026-11-14: the Swift app writes the same event log from real games and MAY send it, as data the player chooses to share.

- Sending MUST be opt-in and off by default.
- Logs MUST NOT contain personal details: no names, contacts or device identifiers, only a random install ID.
- The player SHOULD be able to see what's sent and turn it off at any time.
- Real logs use the same format as the simulator's, so their timings can replace our guessed durations.

## Open questions

1. What are good starting durations for human actions? Mocks and early playtests could give us real ones.
2. How long should a bot's match turn take on screen: played out in full, sped up, or skippable?
3. Which bot is the reference opponent for tuning: greedy or planning?
4. How many games per configuration is enough? A first guess is 10,000; the spread of results will tell us.
