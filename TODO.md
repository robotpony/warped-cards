# To do

Small next tasks. Bigger work is in [PLAN.md](PLAN.md).

## Crib Maze

- [x] `@apple` Move `swift/` to `engine/swift/` and `apps/apple/`, in one patch build (PORTING.md › Layout › Moving there) (from `@linux`, 2026-11-16)
- [x] `@apple` Show the build line (`Mac 0.15.2 · spec 1 · r23`) on the About screen and add `specVersion` to the record header, with engine.md › Records updated (PORTING.md › Versions) (from `@linux`, 2026-11-16)
- [x] `@apple` Read AGENTS.md and add the Mac checkout's real path to its row (from `@linux`, 2026-11-16)
- [ ] `@apple` Move the UI's hard-coded cue timings into config (`timing.json` or a new `fx.json`), and the app reads them, before the Linux UI is built (ui.md › Hard-coded numbers; PORTING.md › Open questions 3) (Bruce, 2026-11-16)
- [ ] `@apple` Reference screenshots of the current beta for the Linux build to match: every scene and state in ui.md (deal, turn, tracing, combo while tracing, each breakdown stage, pops, summary, info cards, the warning, settings), from fixed seeds, in `docs/images/reference/` with a README naming each one's seed and flags. Re-shoot when a scene changes (from `@linux`, 2026-11-16)
- [ ] `@apple` Slow-motion recordings (5x) of the cues, as WebM or MP4 or frame sequences: a trace, a breakdown, a pop, a board change, the deal. Stills can't show motion (from `@linux`, 2026-11-16)
- [ ] `@apple` Card art as data, not Swift: the reach and burn icons exist only in `CardView.swift` (`cards.js` has swap and bomb). Put every card drawing in `design/` as SVG or `shapes.json` paths, and draw both builds from it (ui.md › Cards) (from `@linux`, 2026-11-16)
- [ ] `@apple` Colours still in code go into `palette.json`: page, ink, card face, rule and soft, the four-colour suits, starter bed, clock colours, left-over reds (ui.md › Look, Gaps 18) (from `@linux`, 2026-11-16)
- [ ] `@apple` Bundle Saira Semi Condensed from `design/fonts/saira-semi-condensed/`, and draw suits and ★ from `shapes.json`, since Saira has neither (ui.md › Type; Bruce decided 2026-11-16) (from `@linux`, 2026-11-16)
- [ ] `@apple` Springs as numbers: ui.md gives springs as "300 ms with a strong bounce". With the cue timings in config, give each spring's duration and bounce as numbers, and say how bounce maps to a damped spring so Godot can match it (from `@linux`, 2026-11-16)
- [ ] `@linux` Spec 2: record headers carry `specVersion`, and `GameRules` gains `static var specVersion` (engine.md › Records › Lines; CHANGELOG.md) (from `@apple`, 2026-11-16)
- [ ] `@linux` The version hook reads the Linux build version from `apps/linux/project.godot` (`config/version`); change `LINUX_VERSION` in `.claude/hooks/check-version-bump.sh` if it lives elsewhere (from `@apple`, 2026-11-16)
- [ ] `@linux` `scripts/check.sh` runs `apps/linux/scripts/check.sh` on Linux, if it exists (PORTING.md › Layout) (from `@apple`, 2026-11-16)
- [ ] Make clearing the board hard enough to feel big, once the first playtest shows how often a person clears it (`playtests/plan.md`)
- [ ] Jokers and extra cards: design the title and blank card prizes, how many jokers a round can have, each special joker type's rules, and what happens when one is dealt or cut (`rules.md` › Jokers and extra cards)
- [ ] Jokers: design items (amber's rare outcome) and settle how many joker draws a game has (`mocks/README.md` › Jokers v1)
- [ ] Show the amber and teal jokers, title card and blank card on the card design page (`design/cards/index.html`)
- [ ] Measure "no suit" ties in human playtests before changing the tie rule (`playtests/plan.md`)
- [ ] Graph playtest runs by rules version (`cribbage/minigames/stats.md` › Mock playtests)
