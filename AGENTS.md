# Agents

Status: agreed, 2026-11-16.

Who works on Warped Cards, where they run, and what each one owns. Claude Code sessions and people are listed by handle. A handle names a role, not a session: whoever is the Linux commander today answers to `@linux`.

## Who

| Handle | Role | Runs on | Checkout | Owns |
|---|---|---|---|---|
| `@bruce` | Owner. Final say on anything that changes play | | | Everything |
| `@apple` | Apple commander: the Swift engine, the Mac and iOS apps | Mac | The Mac's own checkout (shared into the Linux VM at `/mnt/mac/games/warped-cards`) | `apps/apple/` and its build version; `engine/swift/` as the reference build (both in `swift/` until the move) |
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

## Working together

- An agent edits only what it owns, plus the shared parts. If another agent's code needs to change, file a mention; don't make the edit.
- Before changing a shared file, pull and look at its recent history (`git log -3 -- <file>`). Keep each change to one small commit and push it soon, so commits rarely clash.
- Stage only the files the task touched (CLAUDE.md › Commits). Pull with rebase before pushing. Never force-push.
- A change to the spec bumps `specVersion` in `cribbage/minigames/spec.json` when a port would have to change something (PORTING.md › Versions).
- Each agent's checkout is its own. The Linux VM MUST NOT build or commit in `/mnt/mac`: build folders would collide, and two sessions would be writing to the same index.
