# Bugs

Open bugs first. Each entry is one line: what goes wrong, then (version, who found it, date). The details go in the spec or the commit, not here.

## Open

- No joker reveal: an extra card on the board shows only a toast, and the timer keeps running (ui.md › Gaps 1) (0.15.1, ui.md review, 2026-11-16)
- The left-over warning shows once per hand, not once per player ever; `warned` is never carried in (ui.md › Gaps 3) (0.15.1, ui.md review, 2026-11-16)
- A joker armed from the board can't be cancelled by tapping it again; an armed bomb bombs its own cell (ui.md › Gaps 7) (0.15.1, ui.md review, 2026-11-16)
- A failed swap or bomb target drops the board source, so the next try uses a tray joker (ui.md › Gaps 8) (0.15.1, ui.md review, 2026-11-16)
- A new game during a breakdown may put the old turn's board back when the breakdown ends; not seen yet (ui.md › Gaps 10) (0.15.1, ui.md review, 2026-11-16)
- A stuck board ending itself is recorded as reason `player`, so the feed says "You ended the turn" (ui.md › Gaps 11) (0.15.1, ui.md review, 2026-11-16)
- The Command-N menu item says "New Turn" but starts a new game (ui.md › Gaps 15) (0.15.1, ui.md review, 2026-11-16)
- The deal always deals the bot's card first, even when the bot deals (ui.md › Gaps 16) (0.15.1, ui.md review, 2026-11-16)
- With a config field missing, edge power per level falls back to 50% in the info card and chips but 10% in the breakdown (ui.md › Gaps 20) (0.15.1, ui.md review, 2026-11-16)
- The hand's info card says "The 4 cards you kept from the deal" with the Deal setting off (ui.md › Gaps 23) (0.15.1, ui.md review, 2026-11-16)

## Fixed

- Action times in records ran on through breakdowns and info cards; game time now stops when the turn timer does (ui.md › Gaps 4) (0.15.2, ui.md review, 2026-11-16)
- The app kept its own copies of the neon colours and the breakdown pace; it now reads `palette.json` and `timing.json` (ui.md › Gaps 18, 19) (0.15.2, ui.md review, 2026-11-16)
