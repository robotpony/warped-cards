# Crib RPG for Linux

Status: 0.3.0, 2026-11-16, spec 3, rules r23. Owner: `@linux` (AGENTS.md).

The Linux client: a Godot 4.7 project that runs the shared Swift engine (`engine/swift/`) through SwiftGodot. It plays the same game as the Mac from the same seed, and reads config, fixtures, the palette, the card art, the icons and the font where they live in the repo. Decided 2026-11-16 (PORTING.md › Open questions 2).

It plays the match turn as ui.md describes it: the board, tracing, combos lighting, the help line, pops, board changes, power jokers, the pick counter, the turn clock and timers, toasts, the score breakdown, the left-over warning, info cards and the turn summary.

Not built yet, so these are off for now:

- The deal: hands come off the top of the deck, as with the Mac's Deal setting off.
- The settings panel, and with it the build line on screen (`Linux 0.3.0 · spec 3 · r23`; the check prints it), and with it the breakdown speed and the Breakdown setting (on).

## Set up

1. Swift 6.4.2 with swiftly, and the two Arch libraries: PORTING.md › Swift, on Linux or Windows.
2. Godot 4.7.2 for your machine from godotengine.org (the plain build, not .NET). Put it on PATH as `godot`, or set `GODOT` to its path.

## Build, run, check

```
apps/linux/scripts/run.sh               # build the bridge, then play in a window
apps/linux/scripts/check.sh             # build, then the headless check (scripts/check.sh runs it on Linux)
apps/linux/scripts/build.sh release
apps/linux/scripts/reference.sh [dir]   # shoot the match turn as docs/images/reference/ shoots the Mac's
apps/linux/scripts/install-desktop.sh   # add Crib RPG to your app launcher, with its icons
```

Keys: Control-N starts a new game, Control-R plays the same seed again (ui.md › Keyboard and menus).

The check confirms the extension loads, the engine's spec and rules versions match `spec.json` and `rules.json`, config and `fx.json` load, every golden record verifies inside Godot, and actions, state and previews come through the bridge.

`run.sh` passes the game's own options on: `--seed N`, and the snapshot flags `main.gd` lists (`--select`, `--trace`, `--drag`, `--arm`, `--pop`, `--breakdown` with `--stage`, `--taps`, `--info`, `--end`, `--shot file.png`), which match the Mac's in `docs/images/reference/README.md`.

## How it fits together

```
apps/linux/
  project.godot ......... the Godot project; config/version is the build version
  extension/ ............ Swift package: the bridge (CribEngine), linking engine/swift by path
  bin/ .................. crib_maze.gdextension, and the built libraries (not committed)
  scenes/
    main.gd ............. the phone: layout, covers, window, snapshot flags
    session.gd .......... the game controller: actions, presented state, timers, toasts, help line
    board.gd, cell.gd ... the board, its input, and each card's looks
    parts.gd ............ header, help line, power jokers, pick counter, clock, toast
    breakdown.gd ........ the score breakdown over the board
    covers.gd ........... left-over warning, info cards, turn summary, deck panel
    card_art.gd ......... cards from design/cards/*.svg, text slots in Saira
    look.gd ............. palette.json colours, Saira, shapes.json suits in text
    motion.gd ........... fx.json: springs, curves, waits, the slow-motion scale
    repo.gd ............. finds the shared data
  tests/check.gd ........ the headless check
  scripts/ .............. build, run, check, reference shots, desktop entry
```

### The bridge

The bridge passes JSON. Actions go in and steps come back in the engine's own encoding (engine.md › Records › Encoding), so the Godot side is written from engine.md and ui.md, never from the Swift types. Between steps the screen asks the bridge what it needs to draw, and what a trace would do before it's sent. These shapes are the bridge's own, not part of the spec; cards are engine.md card references and positions are indexes (engine.md › Positions):

| Call | Answers |
|---|---|
| `turnState()` | The match turn: `cells` (25, null when empty), `power` by position, `steps`, `tray`, `drawable`, `stockOut`, `dead`, `over`, `endReason`, `warned`, `reaches`, `pickLimit`, `starterJoins`, `canBurn`, `deckSize`, `timerSeconds`, `made`, `burned`, `totals` |
| `preview(positions)` | What a trace would do now: `picked`, `problem` (a trace reason, left out when none), `value` (`combos`, points, multiplier parts, `suit`, `counted`, `inSet`, `leftOverPositions`) |
| `isLine(positions)` | Whether a swapper can reverse the line |
| `gameState()` | The game: `stage`, `turn`, `turns`, `dealer`, `over`, `steps`, `shared`, `seed`, `deck`, `results`, `dealing` |
| `dealHint()` | The deal's hint: `principle`, `line`, `cards`, or `{}` |

Fields with no value are left out, as in records. The engine is called from Godot's main loop; it has no threads or async code.

### Drawing

Cards are the SVGs in `design/cards/`, rasterised by Godot's SVG reader and cached. It draws no text, so ranks and words are drawn in Saira at the README's text slots, and suits are `shapes.json` shapes. Suits and ★ inside text are shapes too (ui.md › Type). Every motion and wait comes from `fx.json` through `motion.gd`: springs are ui.md › Motion › Springs' damped spring, in closed form, and curves its Bézier table.

Saira's lines are taller than the system font's, so the phone is about 27 pt taller than the Mac beta's reference shots until the beta moves to Saira (ui.md › Type).

## Versions

The build version is `config/version` in `project.godot`, `major.minor.patch` as in CLAUDE.md › Versions and tracking. The version hook asks for a bump when `apps/linux/` changes. The build line reads `Linux 0.3.0 · spec 3 · r23`.

## Known problems

- Godot 4.7.2 crashes when an import is the run that first registers the extension. `build.sh` imports with the extension hidden, then registers it by writing `.godot/extension_list.cfg`. Seen on Linux ARM64; not yet reported upstream.
- Swift's crash handler takes over crash reports for the whole Godot process and can crash itself. The scripts set `SWIFT_BACKTRACE=enable=no`, so Godot reports its own crashes.
- The project uses Godot's OpenGL (compatibility) renderer, which runs where Vulkan doesn't, as in a VM.
- It prefers Godot's Wayland driver, which knows the screen's scale (under XWayland Godot reports a scale of 1, so the phone came out half size on a 2x screen). A tiling compositor such as Hyprland tiles the window; the phone then sits centred on the page colour. `reference.sh` runs under X11, where the window gets the exact size asked for.
- The debug bridge library is large (about 200 MB for SwiftGodot). Release builds are smaller.
