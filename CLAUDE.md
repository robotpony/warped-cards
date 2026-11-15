# Warped Cards

Card game prototypes, specs and tests. One session acts as project commander; other agents are spawned for focused work.

## Conventions

- Specs are Markdown, written per the `product-writing` skill (Canadian English, RFC 2119 words, no em-dashes, ASCII sketches without box-drawing). Write simply, for people first.
- Each game keeps a concept doc (intent, fun, decisions, plan), a rules doc (player-facing) and a stats doc. Record decisions with dates in the concept doc and keep the rules doc in step.
- One standard 52-card deck unless a spec says otherwise.
- Classic cribbage rule wording lives in `~/projects/utilities/scorekeep/docs/rules/cribbage.md` (owned by the SCOREKEEP session). Reference it, don't copy it. Don't invent classic scoring rules that conflict with it; ask SCOREKEEP.
- Balance claims need simulation numbers, not estimates.
- Order of work: rules and mocks (design track) alongside engine spec, Swift engine and simulator (engine track). The Mac beta app comes next, then iOS. Architecture: `ARCHITECTURE.md`; tools and libraries: `LIBRARIES.md` (add a row before adding anything new).
- Engine specs are written to port: plain Markdown, no Swift-only ideas. Numbers and tables the code needs (rules values, chances, timings, bot levels, effects) live in JSON config files, not in code.
- Games are 1 human vs 1 or 2 bots. Bots are game features, not just test tools.

## Versions and tracking

- Versions are `major.minor.patch`, pre-1.0: patch for fixes, tweaks, refactors and docs; minor when a capability is added or removed; major only when Bruce asks. The top heading of `CHANGELOG.md` is the version until there's code to hold it (then keep both in step).
- `CHANGELOG.md`: newest first, `## 0.x.y — YYYY-MM-DD` with `### Added`, `### Changed`, `### Fixed`, `### Removed`. Written for players in on-screen names, one or two sentences an item. No Unreleased section; provenance and build details go in the commit message. Style: `~/projects/utilities/warped-space-command/docs/changelog-style.md`.
- `PLAN.md`: `## Phase N · Name` headings with `- [ ]` items. `TODO.md`: `- [ ]` lines. `BUGS.md`: `## Open` and `## Fixed` headings exactly, one line per bug with (version, who, date). Items are one short line pointing at the spec.
- Space Command scans the repo: write tags like `#todo` in backticks in docs, or they become tasks.
- Match turn rule changes bump `RULES` in the mock and add a line to `cribbage/minigames/mocks/README.md` › rules versions.
