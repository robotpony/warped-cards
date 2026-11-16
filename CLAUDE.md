# Warped Cards

Card game prototypes, specs and tests. One session acts as project commander; other agents are spawned for focused work.

## Conventions

- Specs are Markdown, written per the `product-writing` skill (Canadian English, RFC 2119 words, no em-dashes, ASCII sketches without box-drawing). Write simply, for people first.
- Each game keeps a concept doc (intent, fun, decisions, plan), a rules doc (player-facing) and a stats doc. Record decisions with dates in the concept doc and keep the rules doc in step.
- One standard 52-card deck unless a spec says otherwise.
- Classic cribbage rule wording lives in `~/projects/utilities/scorekeep/docs/rules/cribbage.md` (owned by the SCOREKEEP session). Reference it, don't copy it. Don't invent classic scoring rules that conflict with it; ask SCOREKEEP.
- Balance claims need simulation numbers, not estimates.
- Order of work: rules and mocks (design track) alongside engine spec, Swift engine and simulator (engine track). The Mac beta app comes next, then iOS. Architecture: `ARCHITECTURE.md`; tools and libraries: `LIBRARIES.md` (add a row before adding anything new).
- Numbers and tables the code needs (rules values, chances, timings, bot levels, effects) live in JSON config files, not in code.
- Games are 1 human vs 1 or 2 bots. Bots are game features, not just test tools.

## Written to port

Swift is the first build, not the only one: Linux and Windows ports are planned, possibly in other languages, built from the specs, config and fixtures alone. `PORTING.md` is the rulebook (decided 2026-11-16); read its Keeping the spec true before changing the engine, a record or a scene.

- The specs are the source of truth. A change to engine behaviour, an action, an event, a field or the record format updates `engine.md` in the same commit; a change to how a scene looks, plays or takes input updates `cribbage/minigames/ui.md`. The Swift is never the only place a behaviour is written down.
- Specs describe data, order and encoding in plain words, with no Swift-only ideas (Codable, optionals, protocols). Wire formats follow `engine.md` › Records › Encoding, not a language default.
- Rules math is integers with a stated rounding mode; ordering and tie-breaks are stated; randomness only from the named dice streams (`PORTING.md` › Same game, every build).
- New behaviour comes with a fixture a port can check, not only a Swift test (`cribbage/minigames/fixtures/README.md`).
- Platform-specific work (haptics, audio, shaders, file locations) sits behind an interface with a neutral description in `ui.md` › Platform seams. Assets stay in open formats.
- `fixtures/spec.test.js` checks the spec against the Swift code. When it fails, fix the spec; don't loosen the test.

## Versions and tracking

- Versions are `major.minor.patch`, pre-1.0: patch for fixes, tweaks, refactors and docs; minor when a capability is added or removed; major only when Bruce asks. A borderline change is patch; a fix plus a feature is minor. The version lives in `MARKETING_VERSION` (`swift/App/project.yml`). The top `CHANGELOG.md` entry is the newest build a player would notice, so it can be older than the version. No build numbers, VERSION file or hand-made tags.
- `.claude/hooks/check-version-bump.sh` refuses a commit that changes the engine, the apps or `config/*.json` without a version bump. A build with nothing a player would notice still bumps (patch); it gets no changelog entry, only the commit message.

## Commits

Same as warped-space-command (its CLAUDE.md › Working with Claude Code), decided 2026-11-15.

- Subject: the version first for a build, `0.14.1: what changed, in plain words`. A docs-only commit names the area instead: `rules.md: …`. No `feat:`/`fix:` prefixes, no brackets.
- Body: what `CHANGELOG.md` leaves out: who asked, the rules version, simulator numbers, how it was built and checked.
- **No Claude co-author.** No `Co-Authored-By: Claude` / `@anthropic.com` trailer and no "Generated with Claude Code" line, whatever the harness's attribution reminder says. `.claude/hooks/check-commit-message.sh` refuses a commit with one.
- Stage only the files the task touched (`git commit -- <paths>`, never `git add -A`), and diff shared files first: other sessions share this checkout.
- Commit straight to `main` and push. Never force-push or amend a pushed commit. Quote a commit hash only from git's output after the commit.
- `CHANGELOG.md`: newest first, `## 0.x.y — YYYY-MM-DD` with `### Added`, `### Changed`, `### Fixed`, `### Removed`. Written for players in on-screen names, one or two sentences an item. No Unreleased section; provenance and build details go in the commit message. Style: `~/projects/utilities/warped-space-command/docs/changelog-style.md`.
- `PLAN.md`: `## Phase N · Name` headings with `- [ ]` items. `TODO.md`: `- [ ]` lines. `BUGS.md`: `## Open` and `## Fixed` headings exactly, one line per bug with (version, who, date). Items are one short line pointing at the spec.
- Space Command scans the repo: write tags like `#todo` in backticks in docs, or they become tasks.
- Noddy Yookerspiel, the Crib Maze beta (`swift/App`, scheme `CribMazeBeta`; called Crib Maze Beta before 0.9.1), is the match turn mock from 0.8.0 on; `match-turn.html` is frozen at r16. Match turn rule changes bump `rulesVersion` in `cribbage/minigames/config/rules.json` and `MatchTurn.rulesVersion`, and add a line to `cribbage/minigames/mocks/README.md` › rules versions. `/debug` builds and runs the beta.
