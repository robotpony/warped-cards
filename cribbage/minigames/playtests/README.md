# Crib RPG playtests

The first human playtest of the beta follows [plan.md](plan.md).

Data from the match turn mock ([../mocks/match-turn.html](../mocks/match-turn.html)), kept for tuning, for graphs of scores over time, and for the simulator. Every run carries `rules`, the match turn rules version ([history](../mocks/README.md#match-turn-rules-versions)); compare runs only within one version.

- `*-runs.jsonl`: one finished turn per line (settings, hand, crib, starter, classic count, every set scored, totals). From "Copy runs" or "Download runs".
- `*-event-log.json`: every event in one turn, with times in ms from its start. From "Download this turn's event log".

| File | What |
|---|---|
| [2026-11-14-bot-turn-event-log.json](2026-11-14-bot-turn-event-log.json) | Rules r4 (before versioning). One fast bot turn, dealer, max 5 cards per set: 7 sets, 137 steps, a prize on every set |
