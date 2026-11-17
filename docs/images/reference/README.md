# Reference screenshots

What the Mac beta (Noddy Yookerspiel) shows, for other builds to match shot for shot. Made by `apps/apple/scripts/reference.sh` from Apple build 0.17.0, spec 3; re-shoot when a scene changes.

- Each phone shot is the 402 pt wide phone with 24 pt of page around it, rendered at 2x (900 px wide). The settings shot is the 340 × 620 pt panel at the Mac's screen scale (2x).
- Every shot is a still from `--snapshot`, the beta's own renderer: `"Noddy Yookerspiel" --snapshot <file> --seed 1 <flags>`. Animations are at their end state, so motion isn't shown; ui.md › Motion and `config/fx.json` give the timings.
- Toasts are hidden unless a shot asks for one. The beta uses the system font; Crib Maze, and the beta with `--saira`, use Saira Semi Condensed (ui.md › Type).
- Where the app and ui.md disagree, follow ui.md: `BUGS.md` › Open and ui.md › Gaps list what the app gets wrong, and the shots show those bugs too.

| Shot | Flags | Shows |
|---|---|---|
| [deal](deal.png) | `--seed 1 --deal` | The deal: the bot's backs, your six cards, the empty crib slots |
| [deal-picked](deal-picked.png) | `--seed 1 --deal --pick 3S,QD` | The deal with two cards picked |
| [deal-hint](deal-hint.png) | `--seed 1 --deal --hint` | The deal with the discard hint showing |
| [turn](turn.png) | `--seed 1` | The match turn as it starts |
| [turn-toast](turn-toast.png) | `--seed 1 --toast` | A prize toast over the board (the blank card's +5 steps) |
| [trace](trace.png) | `--seed 1 --select g00,g01` | Tracing two cards that make no combo |
| [trace-combo](trace-combo.png) | `--seed 1 --select g02,g03` | A combo lighting while tracing (8♥ 7♣, a fifteen) |
| [armed-bomb](armed-bomb.png) | `--seed 1 --arm bomb` | A bomb armed, waiting for its target |
| [pop](pop.png) | `--seed 1 --pop g02,g03` | A scored set mid-pop, with the breakdown off |
| [pop-bomb](pop-bomb.png) | `--seed 1 --pop g00 --bomb` | A bombed card mid-pop |
| [breakdown-1](breakdown-1.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 1` | Breakdown, cue sheet order 1: the breakdown starts and the board dims |
| [breakdown-2](breakdown-2.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 2` | Order 2: the cards are up in the row |
| [breakdown-3](breakdown-3.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 3` | Order 3: the banner is in |
| [breakdown-4](breakdown-4.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 4` | Orders 4 and 6: the tally is in and the first combo (the fifteen) is lit |
| [breakdown-5](breakdown-5.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 5` | Order 6: the fifteen unlit, before the next combo |
| [breakdown-6](breakdown-6.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 6` | Order 6: the second combo (the pair) lit |
| [breakdown-7](breakdown-7.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 7` | Order 6: the pair unlit |
| [breakdown-8](breakdown-8.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 8` | Order 12: power up, the edge cards lit with their new chips |
| [breakdown-9](breakdown-9.png) | `--seed 1 --breakdown g32,g33,c3,h2 --stage 9` | Order 13: the total line |
| [breakdown-hold](breakdown-hold.png) | `--seed 1 --breakdown g32,g33,c3,h2` | Order 14: the hold, waiting for a tap |
| [warning](warning.png) | `--seed 1 --trace g02,g03,g13` | The left-over warning (8♥ 7♣ J♠: the J is left over) |
| [info-hand](info-hand.png) | `--seed 1 --info hand` | Info card: the hand |
| [info-crib](info-crib.png) | `--seed 1 --info crib` | Info card: the crib |
| [info-starter](info-starter.png) | `--seed 1 --info starter` | Info card: the starter |
| [info-tray](info-tray.png) | `--seed 1 --info tray` | Info card: the power jokers |
| [info-counter](info-counter.png) | `--seed 1 --info counter` | Info card: the card counter |
| [summary](summary.png) | `--seed 1 --end` | The turn summary |
| [settings](settings.png) | `--seed 1 --settings` | The settings panel, Game tab (drawn on its own: it is a popover over the footer) |
