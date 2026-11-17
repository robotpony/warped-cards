# Agents

Status: agreed, 2026-11-16.

Who works on Warped Cards, where they run, and what each one owns. Claude Code sessions and people are listed by handle. A handle names a role, not a session: whoever is the Linux commander today answers to `@linux`.

## Who

| Handle | Role | Runs on | Checkout | Owns |
|---|---|---|---|---|
| `@bruce` | Owner. Final say on anything that changes play | | | Everything |
| `@apple` | Apple commander: the Swift engine, the Mac and iOS apps | Mac | `~/projects/games/warped-cards` on the Mac (shared into the Linux VM at `/mnt/mac/games/warped-cards`) | `apps/apple/` and its build version; `engine/swift/` as the reference build |
| `@linux` | Linux commander: the Linux port | Linux VM | `~/src/warped-cards-linux`, its own clone | `apps/linux/` and its build version |
| `@scorekeep` | Classic cribbage rule wording | Mac | The scorekeep repo | `scorekeep/docs/rules/cribbage.md` |

The shared parts belong to no single agent: the specs (`rules.md`, `engine.md`, `ui.md`), `config/`, `fixtures/`, `spec.json`, `design/`, and the root docs. Any agent MAY change them, following the checks in Working together below. The folder layout is in PORTING.md › Layout.

`engine/swift/` is shared code with one keeper: `@apple` changes it, and other clients file mentions for what they need. This MAY change once a second Swift client ships.

A commander MAY spawn helpers for focused work. A helper uses its commander's handle and a suffix, such as `@linux-ui`, and works only in its commander's area. It gets a row here only if it lasts beyond one task.

## Talking to each other

Agents on different machines can't message each other, so they talk through the repo.

- **Mentions:** put a handle in backticks at the start of a line in `PLAN.md`, `TODO.md` or `BUGS.md`. The backticks let Space Command pick the line up as a tag and stop GitHub linking a real user who has that login.
- **Line shape:** what's wanted, where it's specced, and who asked when:
  ```
  - [ ] `@apple` Show the spec version on the About screen (PORTING.md › Versions) (from `@linux`, 2026-11-16)
  ```
- **Who owns it:** the agent mentioned owns the item. It closes the item the usual way: tick it in `PLAN.md` or `TODO.md`, or move the bug to Fixed in `BUGS.md`.
- **Starting work:** a commander pulls, reads this file, and looks for its handle:
  ```
  git grep -n '`@linux`'
  ```
- **A question for Bruce** is a `` `@bruce` `` mention. It MUST say what waits on the answer.

## Latest

Each commander keeps one short entry here for the others: what changed that they need to know, newest first. Replace your entry rather than adding to it; the detail lives in commits, `TODO.md` and the specs.

### From `@apple`, 2026-11-16 (Apple build 0.17.2, spec 3)

- **The layout move is done** (0.15.3). The engine is `engine/swift/`; link it by path from `apps/linux/`. Run the simulator from `engine/swift/`: its default config is `../../cribbage/minigames/config`. The Apple app is `apps/apple/`, with its scripts in `apps/apple/scripts/`.
- **Spec 2** (0.15.4). Record headers carry `specVersion`. `GameRules` has a static `specVersion` (CribMazeGame's is 3 from spec 3), and readers accept headers without it. `seed1.jsonl` is re-recorded; only its header changed. Details: `CHANGELOG.md`, engine.md › Records › Lines.
- **Checks.** On Linux, `scripts/check.sh` runs the JS checks, `swift test` in `engine/swift/`, then `apps/linux/scripts/check.sh` if it exists.
- **Versions.** The version hook asks for a Linux bump on changes under `apps/linux/`, reading `config/version` in `apps/linux/project.godot`. If the version lives elsewhere, change `LINUX_VERSION` in `.claude/hooks/check-version-bump.sh`.
- **Shared data the client reads.** Every colour comes from `design/neon/palette.json` (all of them since 0.15.6: the original cards are `colours.card`, plus `page`, `ink`, `paper`, `clock`, `leftOver` and more; ui.md › Colours names each) and the breakdown pace from `timing.json` › profiles.human, as the Apple app does. Don't copy the values.
- **Game time.** `clockMs` is game time since the game started, paused whenever the turn timer pauses (engine.md › Clock and timer). A client MUST pause it the same way.
- **Spec 3: the cue timings are in config** (0.15.5). Every motion and wait is in `config/fx.json`; ui.md › Motion says what each is and how a spring's duration and bounce map to stiffness and damping. Read the file, don't copy the numbers. `seed1.jsonl` is re-recorded; only its header's `specVersion` changed.
- **Your asks, answered** (Bruce, 2026-11-16). The original cream cards stay; the neon cards are dropped as too hard to read. Saira Semi Condensed is tried in the release app first, then the beta. Card art (SVG in `design/cards/`) and the colours still in code (`palette.json`) come from the Mac, and the Mac draws from them first so we can check they match; don't make your own copies meanwhile.
- **Cards from SVG** (0.15.7). The Mac now draws every card from `design/cards/*.svg`; their README says how to read them, text slots included. Draw from the same files.
- **Saira** (0.16.0). The release app (now Crib RPG) draws in Saira, with suits and ★ from `shapes.json` on cards and in text; ui.md › Type gives the sizes. The beta does too with `--saira`, for comparing.
- **Reference shots** (0.16.1). `docs/images/reference/` has 28 shots of the beta, seed 1, at 2x: deal, turn, tracing, a combo lighting, each breakdown stage, pops, info cards, the warning, the summary and settings. Its README gives each shot's flags; `apps/apple/scripts/reference.sh` re-shoots them.
- **Motion films** (0.17.1). `docs/images/reference/motion/` has the deal, a trace with its pop and board change, a full breakdown, and a bomb, at 5x slow motion. Check feel against them; take the numbers from `fx.json`.
- **Renamed** (0.17.0, 0.17.2). The game is Crib RPG (was Crib Maze) in the specs and the Mac app. Code names (`CribMaze`, `CribMazeGame`) and the record ID `crib-maze` are unchanged, so nothing in the engine or records moves. There's a `@linux` item in `TODO.md` for `apps/linux/`.
- **Open app bugs.** `BUGS.md` › Open holds the Apple app's gaps from the ui.md review. ui.md's gap list also has design questions waiting on Bruce; they aren't spec yet.

## Working together

- An agent edits only what it owns, plus the shared parts. If another agent's code needs to change, file a mention; don't make the edit.
- Before changing a shared file, pull and look at its recent history (`git log -3 -- <file>`). Keep each change to one small commit and push it soon, so commits rarely clash.
- Stage only the files the task touched (CLAUDE.md › Commits). Pull with rebase before pushing. Never force-push.
- A change to the spec bumps `specVersion` in `cribbage/minigames/spec.json` when a port would have to change something (PORTING.md › Versions).
- Each agent's checkout is its own. The Linux VM MUST NOT build or commit in `/mnt/mac`: build folders would collide, and two sessions would be writing to the same index.
