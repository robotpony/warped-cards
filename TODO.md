# To do

Small next tasks. Bigger work is in [PLAN.md](PLAN.md).

## Crib Maze

- [x] `@apple` Move `swift/` to `engine/swift/` and `apps/apple/`, in one patch build (PORTING.md › Layout › Moving there) (from `@linux`, 2026-11-16)
- [x] `@apple` Show the build line (`Mac 0.15.2 · spec 1 · r23`) on the About screen and add `specVersion` to the record header, with engine.md › Records updated (PORTING.md › Versions) (from `@linux`, 2026-11-16)
- [x] `@apple` Read AGENTS.md and add the Mac checkout's real path to its row (from `@linux`, 2026-11-16)
- [x] `@apple` Move the UI's hard-coded cue timings into config (`timing.json` or a new `fx.json`), and the app reads them, before the Linux UI is built. Give each spring its duration and bounce as numbers, and say in ui.md how bounce maps to a damped spring so Godot can match it. One spec bump for both (ui.md › Hard-coded numbers; PORTING.md › Open questions 3) (Bruce, 2026-11-16; springs from `@linux`, merged in by Bruce 2026-11-16)
- [ ] `@apple` Reference screenshots of the current beta for the Linux build to match: every scene and state in ui.md (deal, turn, tracing, combo while tracing, each breakdown stage, pops, summary, info cards, the warning, settings), from fixed seeds, in `docs/images/reference/` with a README naming each one's seed and flags. Re-shoot when a scene changes (from `@linux`, 2026-11-16)
- [ ] `@apple` Slow-motion recordings (5x) of the cues, as WebM or MP4 or frame sequences: a trace, a breakdown, a pop, a board change, the deal. Stills can't show motion (from `@linux`, 2026-11-16)
- [ ] `@apple` Draw the cards from the SVGs in `design/cards/` (README there) instead of `CardView.swift`'s own paths, text drawn by the app, and check the Mac looks the same before Linux uses them. Set the real suit size in `face-sample.svg` (24 units is a guess) (ui.md › Cards; the original cards stay, Bruce 2026-11-16) (from `@linux`, 2026-11-16; SVGs from the card guru designer session, 5a19fe5)
- [ ] `@apple` Colours still in code go into `palette.json`: page, ink, card face, rule and soft, the four-colour suits, starter bed, clock colours, left-over reds. The Mac reads them first, so we can check it looks the same before Linux uses them (ui.md › Look, Gaps 18) (from `@linux`, 2026-11-16)
- [ ] `@apple` Try Saira Semi Condensed in Crib Maze (the `CribMaze` target) first: bundle it from `design/fonts/saira-semi-condensed/` and draw suits and ★ from `shapes.json`, since Saira has neither. The beta switches once Bruce has seen it (ui.md › Type; Bruce 2026-11-16) (from `@linux`, 2026-11-16)
- [x] `@linux` Spec 2: record headers carry `specVersion`, and `GameRules` gains `static var specVersion` (engine.md › Records › Lines; CHANGELOG.md) (from `@apple`, 2026-11-16)
- [x] `@linux` The version hook reads the Linux build version from `apps/linux/project.godot` (`config/version`); change `LINUX_VERSION` in `.claude/hooks/check-version-bump.sh` if it lives elsewhere (from `@apple`, 2026-11-16)
- [x] `@linux` `scripts/check.sh` runs `apps/linux/scripts/check.sh` on Linux, if it exists (PORTING.md › Layout) (from `@apple`, 2026-11-16)
- [ ] Make clearing the board hard enough to feel big, once the first playtest shows how often a person clears it (`playtests/plan.md`)
- [ ] Jokers and extra cards: design the title and blank card prizes, how many jokers a round can have, each special joker type's rules, and what happens when one is dealt or cut (`rules.md` › Jokers and extra cards)
- [ ] Jokers: design items (amber's rare outcome) and settle how many joker draws a game has (`mocks/README.md` › Jokers v1)
- [ ] Show the amber and teal jokers, title card and blank card on the card design page (`design/cards/index.html`)
- [ ] Measure "no suit" ties in human playtests before changing the tie rule (`playtests/plan.md`)
- [ ] Graph playtest runs by rules version (`cribbage/minigames/stats.md` › Mock playtests)
