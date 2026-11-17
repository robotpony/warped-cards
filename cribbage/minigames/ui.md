# Crib Maze: UI Spec

Status: draft 1, 2026-11-16, spec 2, from the beta app at 0.15.1, rules r23

## Summary

This spec describes how the Crib Maze beta app (Noddy Yookerspiel, `apps/apple`) looks and behaves above the engine: its scenes, what the player can do in each, what plays when the engine reports something, and how long it takes. It is written so a port to Linux or Windows, in another language and UI toolkit, can rebuild the same game feel without reading Swift.

The engine is specced in [engine.md](engine.md). This spec starts where that one stops: the app sends the engine actions and gets back events, and everything here is how those events reach the player. Player-facing names come from [rules.md](rules.md). The HTML match turn mock is frozen at r16; from r17 on, the beta app is the only source of truth for UI behaviour, and this spec records it.

The app has three scenes, all inside one phone-shaped window: the deal, the match turn and the turn summary. The match turn carries most of the game feel, mainly in tracing a set and in the score breakdown that follows each score. There is no sound and no haptics yet, and no joker reveal.

Where the app's behaviour seems unintended, or disagrees with rules.md or engine.md, it is described as built and listed under Gaps. Nothing here changes the code.

## How to read this

- Sizes are in points (pt) at the app's reference frame: a 64 pt wide card, 1.4 times as tall (89.6 pt). See Layout.
- Times are in milliseconds (ms) at normal speed. Every animation and pause in the app goes through one global motion scale (1 normally, 5 in the beta's slow motion), so a port SHOULD route its durations through one such scale too.
- A value marked (config) is read from a config file. A value marked (hard-coded) is written into the app's code. Every hard-coded number that should move to config is collected in Hard-coded numbers.
- Colours are named by their key in `design/neon/palette.json` (for example `gold`, `panel`, `joker.special`). A colour that isn't in the palette is given in hex and listed in Look.
- Words in capitals in quotes ("POWER JOKERS") are on-screen text, shown as the app shows it.
- MUST, SHOULD and MAY follow RFC 2119. They apply to a port that wants the same game feel. Behaviour listed under Gaps is described, not required.

### Terms

| Term | Meaning here |
|---|---|
| Session | The app's game controller. It owns the clock and timers, sends actions to the engine, and keeps what the screen shows |
| Presented state | What the screen shows. It lags behind the engine's state while cues play (ARCHITECTURE.md › How a move flows) |
| Busy | A move is playing out on screen. Most input waits, and the timers pause |
| Blocked | Busy, or a card covers the board (the left-over warning, an info card), or the turn is over. Board input is ignored |
| Cue | One timed piece of feedback: a card popping, a line added to the tally, a toast |
| Toast | A short gold message over the middle of the screen that fades by itself |
| Feed | The turn's log, one line per event, shown only in the settings panel |
| Armed | A power joker the player has tapped and that now waits for a target |

## The app at a glance

The window is a phone. Every scene draws inside it; there are no other windows in play, apart from the settings panel, which opens beside the footer.

```
App flow (one game is 3 turns, config game.turns)

  Launch ........................ a new game, random seed
    Deal (if the Deal setting is on) .... pick 2 for the crib
    Match turn .................. trace sets until the turn ends
    Turn summary ................ the turn's numbers, the deck
      [Next turn] ............... back to Deal, for the next turn
      after the last turn:
        [Same seed] ............. the same game again
        [New game] .............. a new random seed
```

| From | Event | To |
|---|---|---|
| Launch, New game, Same seed | Game starts; first hand starts | Deal, or Match turn if the Deal setting is off or the hand is fixed |
| Deal | Player throws 2 (after a 1,450 ms throw and cut sequence) | Match turn |
| Match turn | Engine ends the turn (`turn_end`) | Turn summary |
| Turn summary | Next turn (more turns left) | Deal, or Match turn |
| Turn summary | Same seed, or New game (game over) | Deal, or Match turn, of a new game |
| Any scene | Menu: New Turn, Same Seed Again, or the seed field in settings | Deal, or Match turn, of a new game |

Each scene draws over the one before it: the deal and the summary are full-screen covers over the match turn. Switching scenes is immediate; there is no transition between them.

The game is 1 player against 1 bot. In this build the bot only deals and throws to the crib; it doesn't play a match turn on screen or off (see Gaps).

Source: `CribMazeApp.swift`, `MatchTurnView.swift` (PhoneView, SummaryView, DealView), `GameSession.swift` (newGame, startTurn, nextTurn).

## Layout

### The reference frame

Everything is laid out in points at a fixed card size. The app draws the phone at full size and never reflows it. If the screen is too short, the whole phone scales down evenly.

| Size | Value | Notes |
|---|---|---|
| Card | 64 × 89.6 pt | Width × 1.4. Every card size in the app is a ratio of this |
| Gap between cards | 5 pt | |
| Edge gap | 12 pt | Between the grid and the hand row and crib column |
| Card corner | 5 pt | |
| Board | 352 × 480 pt | 4 × (64 + 5) + 12 + 64 wide; 4 × (89.6 + 5) + 12 + 89.6 tall |
| Phone width | 402 pt | Board + 2 × 16 side padding + 18 |
| Phone height | about 840 pt | As tall as its content; the app measures it after layout (first guess 800) |
| Phone corners | 42 pt radius | With a 10 pt near-black bezel (#111111) around it |
| Window margin | 20 pt | Around the phone, on the page colour (#05070F) |

Scale: `min(1, (screen's usable height − 32 − 2 × 20) / phone height)`, applied to the whole phone from its top left corner. The window is exactly the scaled phone plus its margin, and can't be resized.

The code has a size factor for cards (1 today) that would scale the card, gap, edge gap and corner. The edge padding (6 and 9 pt) and most text sizes don't follow it, so a port SHOULD NOT rely on it as built. ARCHITECTURE.md says scenes SHOULD lay out from the board size; a port SHOULD do that, using these numbers as the reference at a 64 pt card.

### Board positions

```
Board, 352 x 480 pt (x, y of each card's top left)

  g00 (0,0)     g01 (69,0)     g02 (138,0)     g03 (207,0)       c0 (288,0)
  g10 (0,94.6)  ...                                              c1 (288,94.6)
  g20 (0,189.2) ...                                              c2 (288,189.2)
  g30 (0,283.8) ...                            g33 (207,283.8)   c3 (288,283.8)

  h0 (0,390.4)  h1 (69,390.4)  h2 (138,390.4)  h3 (207,390.4)    s (288,390.4)
```

Column x is `col × 69`, plus 12 for the crib column. Row y is `row × 94.6`, plus 12 for the hand row. Position names are engine.md's.

### The match turn screen

```
Match turn (402 pt wide; 16 pt side padding; 10 pt between rows)

  14 pt top padding
  42 ...................................... [stock: card back 46 pt, count badge]
  steps scored
  ==== progress track, 6 pt tall ====================================

  9 pt
  Board, 352 x 480, centred
    4 x 4 grid ............................ crib column (dealer only)
    hand row .............................. starter (tilted)

  help line, 20 pt tall, one line ("7♥ 8♣  (sum 15): fifteen (+2)")

  POWER JOKERS (tag on the panel's top edge)
    [swapper x2]   [bomb x1]   [reach x1]   [burn x1]

  footer bar, full phone width
    pick counter pips .................................. turn clock
    HAND SIZE 2 / 4
```

| Part | Size and spacing |
|---|---|
| Steps number | 44 pt bold. Below it "steps scored", 13 pt medium at 75% opacity |
| Stock | A card back 46 pt wide. Its count sits on a gold badge (13 pt bold, at least 24 × 22) at its bottom right, pushed out 8 pt right and 6 pt down. With no cards left to draw, a dashed outline of the same size |
| Progress track | 6 pt tall, full width, rounded. Background `text` at 15%; fill `gold` with a soft gold glow, as a share of 121 steps |
| Board | 9 pt below the track, centred |
| Help line | 20 pt tall, 14 pt text, shrinks to 75% before truncating. Pulled up and down 4 pt so the power jokers sit close under the board |
| Power jokers panel | Padding 8 pt sides, 20 pt top, 14 pt bottom. Rounded 12 pt, `panel` fill, `joker.special` border at 50%, 1 pt. Slots spread evenly: one per known kind (config `specials.known`), at least 4. Each tray card is 72 pt wide |
| "POWER JOKERS" tag | 10 pt bold, letter-spaced 0.8, 16 pt tall capsule in `joker.special`, text in `bg`, centred on the panel's top edge (8 pt above it) |
| Footer | Fills the phone's width, 4 pt below the panel. `panel` fill with a 1 pt `rim` line on top. Padding 30 pt sides, 12 pt top, 20 pt bottom |
| Pick counter | One pip per card a set may pick: 9 × 13 pt, corner 2, 4 pt apart. Under them "HAND SIZE n / limit", 11 pt bold, letter-spaced 0.6 |
| Turn clock | A 30 pt circle at the footer's right |

### The edge cards' background

The hand row, the starter and (for the dealer) the crib column sit on one rounded shape. It is the union of two rounded rectangles: one around the hand row and starter, one around the crib column and starter. Each grows 6 pt on its inner sides and 9 pt on its outer (right and bottom) sides, to clear the starter's tilt, with a corner of 11 pt (card corner + 6). For a non-dealer it is the hand row's rectangle only.

- Fill `panel`; a 5 pt `cyan` stroke at 12% (a soft glow); a 1 pt `cyan` stroke at 50%.
- The starter sits on its own lighter bed: a rounded rectangle 9 pt bigger than the card on every side, corner 13, filled #3A4A80, with a 1.5 pt `text` border at 60%.
- Empty cells show a dashed outline (1 pt, `text` at 25%, dashes 4 and 3). For a non-dealer, the crib cells also say "no crib" (11 pt, 50%).

Source: `Theme.swift`, `BoardView.swift` (BoardLayout, EdgeBackground, EmptyCell), `MatchTurnView.swift` (MatchTurnView, PhoneView).

## Look

### Colours

The app reads the table colours (`bg`, `text`, `panel`, `rim`, `cyan`, `magenta`, `gold`, `joker.special`) from palette.json, bundled into the app (0.15.2). Colours that aren't in the palette are still in code (see Gaps). Cards use the original card art from `design/cards/cards.js`, not the neon cards.

| Role | Palette key or hex | Used for |
|---|---|---|
| Table | `bg` (#0A0E1F) | Phone background, text on light chips |
| Text | `text` (#DDE6FF) | Text on the table, starter ring and tag |
| Panel | `panel` (#121A33) | Edge background, power jokers panel, footer, hint box |
| Rim | `rim` (#2E3A66) | Footer top line |
| Cyan | `cyan` (#3CF2FF) | Edge background outline, picked pips, power (edge multipliers) in the breakdown, tally border, "Tap to continue", settings tint, turn titles on the summary |
| Gold | `gold` (#FFD447) | Steps, track, edge card rings, HAND and CRIB tags, toast, banner, combo light, power chips, full pick counter, hint ring |
| Violet | `joker.special` (#C77DFF) | Power jokers panel, tray counts, reach countdown, reach pips, the bot's crib tag |
| Overlay | `bg` at 95% | Turn summary background |
| Page | #05070F (not in palette) | Around the phone |
| Ink | #2B2A26 (cards.js) | Dark text on gold and on cards |
| Card face | #FDFCF8 (cards.js) | Card faces, info cards |
| Card rule | #D6D0C4 (cards.js) | Card outline, mini card outline |
| Card soft | #7C6C48 (cards.js) | Card back hatching, extra card names |
| Joker purple | #6A1B9A (cards.js) | Special joker card art |
| Red | #E00000 (cards.js) | Bomb pop glow, burn flame, burned mark, reach plus |
| Left over | #FF5A5A | Left-over ring and glow in the breakdown |
| Penalty text | #FF7A7A | Left-over points in the tally and floats |
| Warning card | #FFFDF7 | Left-over warning background, banner suit chip |
| Warning names | #C00000 | The left-over cards named in the warning |
| Clock green, orange, red | #39E07A, #FF9F1C, #FF4D4D | Turn clock looks |
| Tray stack | #A99E86, #CFC6B3 | The cards behind a tray card when you hold 2 or more |
| Bezel | #111111 | Phone frame |

Suit colours on card faces are the four-colour deck from cards.js: spades #000000, hearts #E00000, diamonds #0070E0, clubs #00843D. palette.json's `suit` colours are left from the neon cards, which were dropped on 2026-11-16 as too hard to read.

### Cards

Cards are drawn in cards.js's 50 × 70 unit box, scaled to the card's width.

- Face: rounded 4.5 units, card face fill, 1.2 unit card rule outline. The rank at top left (centre at 9, 10.5), 16 units bold (14 for a 10, tracked −1.2), and again rotated 180° at bottom right (41, 59.5). A large suit glyph in the centre (25, 35), 34 units. Suit glyphs MUST draw as text, never as emoji.
- Special jokers: an inset border in joker purple at 50%, "JOKER" at the top and the kind's name at the bottom ("SWAP", "BOMB", "REACH", "BURN"), 8 units bold, and an icon: two arrows (swapper), a black bomb with a red spark (bomb), a red and gold flame (burn), a card with a dashed extra card and a red plus (reach). shapes.json's neon swap and bomb icons belong to the dropped neon cards and aren't used.
- Extra cards (amber, teal, title, blank): the kind's name in capitals, 7 units bold, card soft colour, centred.
- Back: crosshatch at 45°, lines 3.4 units apart, 0.7 units wide, card soft at 70%, inside a 41 × 61 unit inner outline.

### A card on the board

Each card on the board takes one look from its state. Looks combine where it makes sense.

| State | Look |
|---|---|
| Edge card (hand, crib) | 2 pt `gold` ring, plus a soft 4 pt `gold` halo at 22% when not selected |
| Starter | 2 pt `text` ring, tilted −5°, a hard drop shadow (black 35%, 4 pt down) |
| Selected (in the trace) | 2 pt white ring, raised 2 pt, scaled 1.04, hard drop shadow. A white numbered badge (18 pt circle) at bottom left gives its order |
| In a combo while tracing | 3 pt white ring, white glow (55%), 8% white wash, raised 4 pt, scaled 1.1 |
| Armed board joker | 3 pt white ring, raised 6 pt |
| Popped before clearing (score, breakdown off) | 3 pt white ring, `gold` glow, scaled 1.12 |
| Popped before clearing (bomb, burn) | 3 pt white ring, red glow, scaled 1.18 |
| Dimmed (breakdown, not in the set) | A `bg` wash at 72% |
| Joker-made card | A 16 pt `gold` circle with ★ at top left |
| Power chip | Edge cards with a power level, and joker-made cards, show their multiplier ("×1.2") at top right: 12 pt bold on a `gold` capsule, 18 pt tall. While the breakdown lights it, the chip turns `cyan` and grows to 1.5× |
| Word tags | "HAND" on h0 and "CRIB" on c0 (`gold` capsule, ink text); "STARTER" on the starter (`text` capsule, `bg` text). 10 pt bold, 16 pt tall, 10 pt above the card; 10 pt to the left when the card has a chip |

Selection and combo looks ease in over 120 ms. The pop springs over 300 ms with a strong bounce.

### Type

The design face is Saira Semi Condensed (palette.json `fonts.ui`). Every build MUST bundle it from `design/fonts/saira-semi-condensed/` (decided 2026-11-16, so the builds look the same; Linux can't ship Apple's system font). The Apple app tries it in Crib Maze first (decided 2026-11-16); the beta keeps the system font at its condensed width until Bruce has seen the trial. Sizes in this spec are for Saira. palette.json's number face, Russo One, isn't used.

Saira has no suit glyphs and no ★. Suits and the star MUST be drawn from `design/neon/shapes.json` (`S`, `H`, `D`, `C`, `star`) at the size and position the text would take, so every build draws the same shapes.

Source: `Theme.swift`, `CardView.swift`, `BoardView.swift` (CellView, CellLook).

## Scene: Match turn

### States

The match turn is one scene with an input mode and a few covers. These are its states, from the player's side.

```
Match turn states

  Starting ........ the session shows the engine's turn_start; timers start
  Tracing ......... the default; trace sets, tap jokers
    Selecting ..... cards picked, not yet submitted
  Armed ........... a swapper, bomb or burn waits for its target
  Playing out ..... busy: a move's cues play; input waits
    Breakdown ..... a score plays part by part (skippable)
    Holding ....... the breakdown waits for a tap to move on
  Warned .......... the left-over warning covers the board
  Info ............ an info card covers the board
  Stuck ........... no sets left; a 25 s grace runs if you hold power jokers
  Over ............ turn_end; the summary covers the screen
```

| From | Trigger | To |
|---|---|---|
| Starting | Turn shown | Tracing (or Stuck, if the first board has no sets) |
| Tracing | Tap or drag onto a card | Selecting |
| Selecting | Release a drag with 2 or more cards, or tap the last card again | Playing out (if it scores, is rejected, or costs steps), or Warned |
| Selecting | Release a drag with fewer than 2 cards; tap the only card again | Tracing (selection cleared) |
| Tracing | Tap a swapper, bomb or burn in the tray, or on the board | Armed |
| Armed | Tap the same tray joker again | Tracing |
| Armed | A valid target | Playing out |
| Tracing | Tap a reach (tray or board) | Playing out (it's used at once) |
| Playing out | Cues end | Tracing, Stuck or Over |
| Breakdown | Tap anywhere | Holding (skips to the end) |
| Breakdown | Sequence ends | Holding |
| Holding | Tap anywhere | Playing out (cards fly home, the board moves on) |
| Warned | "Got it" | Tracing |
| Tracing, Stuck | Tap the HAND, CRIB or STARTER tag, the pick counter, or the "POWER JOKERS" tag | Info |
| Info | "Got it" or a tap outside the card | Back where it was |
| Stuck | A joker opens a set | Tracing |
| Stuck | Grace runs out, or 1,500 ms with no power jokers | Over |
| Any | Timer runs out | Over |
| Playing out | The board is cleared | Over |

Source: `GameSession.swift` (send, commit, submit, arm, watchDeadBoard), `BoardView.swift`.

### Starting a turn

When a turn starts, the session resets everything the screen shows for a turn: no selection, input mode back to tracing, no armed joker, no warning, toast or info card, an empty feed, no reach timers and no grace count. It then shows the engine's turn as it is, with no deal-in animation: the grid, the hand, the crib and the starter simply appear. Any extra card resolved during setup shows its toast (see Cue sheets). The turn timer is set to `match.timerSeconds` (config, 180) and starts.

### Tracing a set

A set is traced with one drag, or with taps. Both build the same selection: an ordered list of board positions.

Hit areas:

- A tap hits a card anywhere inside its frame (64 × 89.6 pt).
- During a drag, a card is picked only when the pointer is near its centre: inside the middle 70% of its width and height (44.8 × 62.7 pt). This keeps a diagonal swipe from catching the cards beside it. The mock and ARCHITECTURE.md call this a setting; in the app it is fixed (see Gaps).
- Only positions holding a card can be hit. Empty cells are ignored.

Dragging:

1. A press doesn't start a drag. The pointer has to move more than 6 pt from where it went down.
2. When it does, the selection starts fresh with the card under the starting point (by its full frame), or empty if there was none.
3. As the pointer moves, each card it reaches (by the 70% area):
   - If the selection is empty, the card starts it.
   - If it is the second-to-last card in the selection, the last card is removed (backing up undoes one card).
   - If it is new, touches the last card (8 neighbours, diagonals included), and fits under the pick limit, it is added.
   - Otherwise nothing happens. A card already in the selection (other than the second-to-last) is skipped.
4. On release, a selection of 2 or more cards is submitted. Either way the selection clears.

Tapping:

1. Tap a card that touches the last card in the selection (or any card, when the selection is empty) to add it.
2. Tap the last card again to submit (2 or more cards) or to clear (1 card).
3. Tap a card earlier in the selection to cut the selection back to just before it.
4. Tap a card that doesn't touch the last one to start a new selection with it.
5. Tapping a card that would go over the pick limit shows the toast "A set picks N cards at most" and leaves the selection as it was.

Limits:

- The pick limit is `match.maxSet` (config, 4) plus the cards of every reach in effect. The starter is free: while it can join (config `match.starterJoins`, and the starter is a playing card), it can always be added and doesn't count against the limit.
- Hand, crib and starter cards follow the same touching rule as grid cards.
- The selection itself doesn't check the other rules (a grid card, a special joker, a set already scored). The engine checks them on submit, and the help line warns about them while tracing (see The help line).

Cancelling:

- Drag back over the cards to undo them one at a time.
- Release with only 1 card picked.
- Tap the only card again, or tap a card earlier in the selection.
- There is no cancel key.

When the board is blocked (busy, a warning or info card, the turn over), drags and taps on the board are ignored, and releasing clears any selection.

While cards are selected in trace mode and there are 2 or more, every selected card that is in a combo takes the "in a combo" look (and so does the starter when it joins a combo). A selected card that stays plain would be left over.

Source: `BoardView.swift` (drag, hit, tap, canAdd), `GameSession.swift` (litPositions, submit).

### Power jokers

The tray shows one slot per known kind, in config order (`specials.known`: swapper, bomb, reach, burn), and empty dashed slots for kinds still to come when fewer than 4 are known. Each tray card shows the joker card at 72 pt with:

- A violet count badge (12 pt bold, 20 pt min) at its bottom right.
- Two cards stacked behind it, offset up and right by 3 and 6 pt, when you hold 2 or more.
- 30% opacity when you hold none.
- When armed, a 3 pt white ring, a drop shadow, and raised 10 pt (eases over 120 ms).
- For the reach, while any reach is in effect: a dark wash over the card and a violet pie in a 62% circle that empties as the reach that ends first runs out. The pie moves smoothly between the 1-second ticks.

| Tap | When | What happens |
|---|---|---|
| Swapper, bomb or burn in the tray | You hold one, the turn isn't over | Arms it (clears the selection). If it is already armed from the tray, disarms it. If another joker is armed, switches to this one |
| Reach in the tray | You hold one, in trace mode | Uses it at once. Nothing happens while another joker is armed |
| A special joker on the board | Trace mode | Arms it from that cell (a reach is used at once) |
| Burn, when the deck is at its minimum | Any | Doesn't arm. Toast "The deck is as small as it gets: N cards" |

When a joker is armed, a toast says what to do: "Trace a straight line to reverse it", "Tap a grid card to blast it" or "Tap a grid card to burn it out of the deck". The help line says it too, with how to cancel (see The help line).

Targets:

- Swapper: trace (drag or taps, as for a set) a straight line of 2 to 4 grid cards. In swap mode, every selected card lights up. A line that isn't straight shows the toast "Trace a straight line of 2 to 4 grid cards" and stays armed.
- Bomb: tap any grid card. A tap on an edge card does nothing (see Gaps).
- Burn: tap a playing card on the grid. Anything else shows the toast "Tap a playing card on the grid to burn it" and stays armed.
- While a bomb or burn is armed, the pointer over the board is a crosshair.

A valid target sends the action and returns to trace mode.

Source: `MatchTurnView.swift` (bottom, tapTray, TrayCard), `GameSession.swift` (arm, disarm, submit).

### Other taps and clicks

| Where | What it does | When |
|---|---|---|
| HAND, CRIB or STARTER tag (80 × 24 pt box centred on the tag) | Opens that info card | The tagged cell holds a card; not a drag |
| Pick counter | Opens the hand size info card | Not blocked |
| "POWER JOKERS" tag | Opens the power jokers info card | Not blocked |
| Header (steps, stock and track) or the rest of the footer | Opens the settings panel | No breakdown playing |
| Anywhere, while a breakdown plays | Skips, or moves on from the hold (see Score breakdown) | Breakdown playing |

Hovering shows short tooltips (the stock, the track, the clock, each tray joker, the pick counter, the footer). They carry no information the screen doesn't.

### The help line

The line under the board says what the current trace would do, or what an armed joker or a stuck board needs. It is empty otherwise.

| Situation | Text |
|---|---|
| Bomb armed | "Bomb armed: tap a grid card to blow it up. Tap the bomb again to cancel." |
| Burn armed | "Burn armed: tap a grid card to take it out of the deck for the game. Tap the burn again to cancel." |
| Swapper armed, nothing traced | "Swapper armed: trace a straight line of 2 to 4 grid cards to reverse it. Tap the swapper again to cancel." |
| Swapper armed, tracing | The cards and their sum, then ": reverse this line" or ": not a straight line" |
| Stuck, grace running | "No sets left. Use a power joker before the clock fills." (semibold, `gold`) |
| Stuck, no grace | "No sets left on the board. The turn is over." (semibold, `gold`) |
| 1 card selected | The card and its sum, such as "7♥  (sum 7)" |
| A rule the set breaks | The cards and sum, then ": needs a grid card", ": already scored", ": cards must touch" or ": a special joker can't score" |
| Combos, nothing left over | "...: fifteen + run of 3 (+5)" |
| Combos and cards left over, warned | "...: fifteen (+2), K♠ left over (−2) = +0" |
| Combos and cards left over, not warned yet | "...: K♠ left over" |
| No combo | "...: no combo", plus the cost once warned, such as " (−4)" |

The sum adds every selected playing card's value. Combo names are lower case here: "fifteen", "pair", "pair royal", "double pair royal", "run of 3", "run of 3 ×2", "flush of 4", "his nobs".

Source: `GameSession.swift` (pickMessage, comboName).

### The pick counter

- One pip per card a set may pick now. Picked pips are `cyan`; when the selection reaches the limit, every picked pip and the label turn `gold`. Empty pips are `text` at 14% with a 30% outline.
- Pips a reach adds are the last ones, drawn with a violet fill at 35% and a 1.5 pt violet outline.
- The count shows only in trace mode; with a joker armed it reads 0.
- The label reads "HAND SIZE n / limit". Changes ease over 120 ms.

### The turn clock

A 30 pt circle: a 15% fill of its colour, a solid wedge from 12 o'clock that grows clockwise as time is used, and a 2 pt ring, with a soft shadow of its colour.

| Look | When | Colour | Wedge | Motion |
|---|---|---|---|---|
| Running | Timer on, more than 10% left | Green #39E07A | Time used / timer | Breathes |
| Warning | Timer on, last 10% | Orange #FF9F1C | Time used / timer | Breathes |
| Stuck | Grace running | Orange | Grace used / 25 s | Opacity pulses 100% to 35%, 600 ms each way |
| Done | Turn over | Red #FF4D4D | Full | None |
| Off | Timer off | `text` at 30% | Empty | None |

- From 10 seconds left, the clock shows the seconds in white, 14 pt bold, counting down.
- Breathing: the clock scales between 1 + depth and 1 − depth / 2, easing in and out, repeating. Urgency rises with the share of time left: over 50% is level 0, over 25% level 1, over 10% level 2, then level 3. Half-breaths take 2.0, 1.4, 0.9 and 0.55 s; depths are 0.05, 0.07, 0.10 and 0.13.
- The wedge animates linearly over 1 s between ticks. A change of look eases over 300 ms.

Source: `MatchTurnView.swift` (TurnClock, Wedge, PickCounter).

### Timers

The engine has no clock. The session runs three countdowns, each ticking once a second. The engine's `time_up`, `reach_over` and `end_turn` are actions the session sends (engine.md › Clock and timer).

| Countdown | Starts | Pauses while | Ends |
|---|---|---|---|
| Turn timer | When the turn is shown, at `match.timerSeconds` (config, 180; 0 with the Timer setting off) | Busy (including a breakdown waiting for a tap), the left-over warning, an info card | At 0: sends `time_up` |
| Each reach | When the engine reports the reach, at its rolled seconds | Busy, the warning, an info card. It runs with the turn timer off too | At 0: sends `reach_over` for that reach. At most one reach ends per tick |
| Stuck grace | When the board has no sets left and you hold any power joker, at 25 s (hard-coded) | Busy, a joker armed, the warning, an info card | At 0: sends `end_turn` |

- A tick that lands while paused is skipped, not saved up. A port SHOULD count whole seconds of unpaused time the same way, or the timer runs a little fast compared with the beta.
- The turn timer doesn't pause while the settings panel is open (see Gaps).
- With no power jokers, a stuck board ends the turn by itself 1,500 ms (hard-coded) after it was found, once nothing is busy.
- If a move opens up a set, the stuck state and its grace stop at once.
- While the grace runs, and hints are on, the power jokers panel blinks a gold ring (see Hints).
- The time stamped on each action (`clockMs`) is game time since the game started. It stops whenever the turn timer pauses (a move playing, the warning, an info card), and runs through the deal (0.15.2; engine.md › Clock and timer).

Source: `GameSession.swift` (startTimer, watchReaches, watchDeadBoard, act).

### What input does while cues play

| Input | While busy (not a breakdown) | During a breakdown | While holding | Warning or info card up |
|---|---|---|---|---|
| Drag or tap on the board | Ignored; selection clears on release | Taken by the skip layer | Taken by the skip layer | Ignored |
| Tap a tray joker | Arms (the action is still refused while busy) | Taken by the skip layer | Taken by the skip layer | Covered |
| Tap a reach | Dropped | Taken by the skip layer | Taken by the skip layer | Covered |
| Tap anywhere | Nothing | Skips to the hold | Moves on | "Got it" or (info card only) outside |
| Open settings | Allowed | No | No | Covered |
| Menu: New Turn, Same Seed Again | Allowed | Allowed | Allowed | Allowed |

Nothing is queued: input during cues is either taken by the cue (skip) or dropped. A move can be sent only when nothing is busy.

## Score breakdown

Every score plays out part by part over the board, like counting a hand aloud. The board keeps showing the turn as it was before the score until the breakdown ends; then it moves on. The Breakdown setting can turn it off, for a quick pop instead (see Cue sheets).

### Layout over the board

```
Breakdown over the board (352 pt wide)

  banner, 50 pt tall, centred
    [MULTI x2]  Run of 3  [♥]

  set row, top at 72 pt (cards 50 pt wide, 6 pt apart, centred)
    4♣  5♥  6♥      S       starter last, 18 pt apart, tagged STARTER

  tally, top at 156 pt
    Fifteen ............... 4♣ 5♥ 6♥ .... +2    2
    Run of 3 .............. 4♣ 5♥ 6♥ .... +3    5
    Run of 3 · ♥ .......................... +5
              (Tap to continue)
```

- The board is covered by a `bg` panel at 94%, reaching 17 pt past the edge background, so nothing behind it shows. It fades in and out over 300 ms.
- Banner: a `gold` capsule (corner 12, gold glow) holding a tag ("SINGLE" or "MULTI ×n", 11 pt bold, `gold` on ink), the headline (22 pt bold, ink) and a suit chip (13 pt, on #FFFDF7): the suit glyph, or "no suit".
- Set row: the set's cards in count order (the starter last), each 50 × 70 pt, with a 2 pt white ring and a soft shadow. The starter is set 18 pt apart and tagged "STARTER" (13 pt bold). Edge cards with power show their chip (15 pt bold).
- Tally: a panel (`bg` at 92%, corner 12, `cyan` border at 35%, drop shadow) with one line per part. Each line has a name on the left, its cards as mini cards beside its points, its points (48 pt column; 64 pt for the total) and a running total. Lines are at least 24 pt tall, 16 pt medium; the total line is 20 pt bold under a 1 pt rule. Points are `gold`, power lines `cyan`, left-over lines #FF7A7A, the total `text`. Lines slide in from 10 pt left as they fade in, over 220 ms.
- A tally too tall for the 332 pt below its top scales down to fit, from its top edge.
- Mini cards: 22 × 26 pt min, card face fill, rank and suit in the suit's colour (12 pt bold), card rule outline; joker-made cards have a `gold` outline. A special joker shows ★.
- Floats: text that pops over the cards it's about and rises away. 30 pt bold with a 13 pt line under it; white, `cyan` for power, #FF7A7A for left over. Over 900 ms it scales from 0.6 to 1.15 and back to 1, rises 36 pt, and fades in and out (keyframes at 180, 630 and 900 ms). It is removed at 1,000 ms.

The headline is the set's biggest combo that isn't a fifteen (the first of the biggest, in count order), or "Fifteen", or "Two fifteens", "Three fifteens" and so on. Combo names in the breakdown: "Fifteen", "Pair", "Pair royal", "Double pair royal", "Run of 3", "Double run of 3", "Triple run of 3", "Double double run of 3", "Flush of 4", "His nobs".

### Pace

Each counted part takes one step. Steps start at the base time and get 15% quicker each time, never under 400 ms: step n takes `max(400, base × 0.85^n)`. The base is the player's breakdown speed: Slow 1,200 ms (the default), Medium 900, Quick 600, Practised 400. Fixed waits are scaled by `base / 1200`. The app doesn't read these from `timing.json`, which holds the same numbers for the simulator (see Hard-coded numbers).

| Base | Steps (ms) |
|---|---|
| 1,200 | 1,200, 1,020, 867, 737, 626, 532, 452, 400, then 400 |
| 900 | 900, 765, 650, 553, 470, 400, then 400 |
| 600 | 600, 510, 434, 400, then 400 |
| 400 | 400 every step |

Only the waits change with speed. Animation durations inside each cue (the springs and fades) don't.

### Cue sheet

Times are at the default speed (base 1,200). "Step" is the next step time from Pace.

| Order | Cue | Wait after |
|---|---|---|
| 1 | Input waits (busy); the selection clears. The board dims. Powered edge cards in the set get their chips | 150 × scale |
| 2 | The set's cells empty and each card flies from its cell to its place in the row, shrinking from 64 to 50 pt: a 500 ms spring with a light bounce, each card 50 ms after the one before. The starter straightens from its tilt | 650 × scale (after a 20 ms beat) |
| 3 | The banner springs in (250 ms), scaling up from 90% and dropping 8 pt into place | 900 × scale |
| 4 | The tally fades in (200 ms) | none |
| 5 | Only if the starter is in the set: it lights (`gold`), floats "Starter / joins the set", and adds the line "Starter joins" | step, then it unlights (150 ms) |
| 6 | For each combo, in count order: its cards light `gold` and rise 10 pt; float "+n / name"; line "name, +n, running total" | 88% of the step; then the cards unlight (150 ms); then 12% of the step |
| 7 | For each edge card in the set with power: it lights `cyan`; float its share ("+0.2" when levels add, config `edgePower.combine` "add"; "×1.2" when they multiply) and "edge power"; line "Edge power" (or "Starter power") | step, then it unlights |
| 8 | Only with a cap (config `edgePower.capPercent` above 0) that the sum passes: line "Power cap: ×n is held at ×m" | step |
| 9 | For each joker-made card in the set: it lights `cyan`; float "×1.1 / joker card"; line "Joker card" | step, then it unlights |
| 10 | Only after 7 or 9: float the total multiplier over the whole set ("×1.3 / +n"); line "Total multi", with the multiplied running total | step |
| 11 | For each card left over: a #FF5A5A ring; float "−2 / left over"; line "Left over, −2, running total". Not multiplied | step |
| 12 | Only if the set has edge cards: every one lights `cyan` and its chip moves to its new level (300 ms spring); each floats "▲" and its new multiplier; line "Power up ▲" with their cards | step, then they unlight |
| 13 | The total line: "headline · suit" and the set's points, signed | max(400, 500 × scale) |
| 14 | Hold: a "Tap to continue" pill (13 pt, `cyan`) hangs from the tally's bottom edge. Waits for a tap, with no time limit | until tapped |
| 15 | The total flies from the tally's total line to the steps number (500 ms, easing in, 34 pt shrinking to 26 pt, `gold` glow). The tally and banner fade (200 ms). The row cards fly back to their cells (500 ms spring, staggered) | 500 ms (not skippable) |
| 16 | The breakdown clears (200 ms fade). The board moves on (see Board changes). The steps number turns `gold` and grows to 1.25× (260 ms spring) | 320 ms |
| 17 | The steps number settles back (200 ms). Input is open again; the timers run again | none |

Example, 4♣ 5♥ 6♥ from the grid (a fifteen and a run of 3, no edge cards): the row is up by 800 ms, the banner at 800 ms, the tally and the fifteen at 1,700 ms, the run at 2,900 ms, the total at 3,920 ms, and the hold from 4,420 ms. After the tap, the board moves on about 500 ms later.

### Skipping

- A tap anywhere on the phone while the breakdown plays, before the hold, skips. Every remaining wait ends at once and no more floats show; the remaining tally lines are still added, so the tally is complete. The breakdown goes straight to the hold.
- A tap during the hold moves on (order 15).
- Two taps get from any point to the next move. The fly home in order 15 (500 ms) and the settle in order 16 (320 ms) always play.
- The settings panel can't open while the breakdown plays.

Source: `Breakdown.swift` (Playback, playBreakdown, BreakdownOverlay, RowLayout, RowCard, FloatView, FlyView), `GameSession.swift` (send).

## Cue sheets for engine events

The session hands each action's events to the screen in the order the engine emits them. What plays depends on the event. A move's events are applied together: the board changes once, after the move's pop or breakdown.

### What starts a move

| The action's events include | What plays first | Then |
|---|---|---|
| `score`, Breakdown setting on | The score breakdown | Board changes; steps bump |
| `score`, Breakdown setting off | The set's cards pop `gold` (scaled 1.12), 340 ms | Board changes; 320 ms more busy |
| `bomb` | The cleared cards pop red (scaled 1.18), 380 ms | Board changes; 320 ms more busy |
| `burn` | The burned card pops red, 380 ms | Board changes; 320 ms more busy |
| Anything else (a swap, a reach, a rejected trace, the warning, a penalty) | Nothing: no busy time | Board changes at once |

### Per event

| Event | Cue | Duration | From |
|---|---|---|---|
| `turn_start` | The turn appears; the timer starts | Instant | Timer: config |
| `trace_rejected` | Toast with the reason: "Sets are 2 to N cards", "A special joker can't be in a set", "Every set needs a grid card", "The cards must touch", "That set already scored" | Toast, 2,400 ms | Hard-coded |
| `leftover_warning` | The left-over warning covers the board (see Overlays). Timers pause | Until "Got it" | Cost: config `leftOverCost` |
| `leftover_penalty` | Steps drop (number and track animate). Feed line "K♠ 9♦  no combo: K♠ 9♦ left over  −4". No other cue | Steps: quick spring; track 400 ms | Hard-coded |
| `score` | See What starts a move. Feed line with the set, single or multi, combos, points, suit and edge power. The last score's panel in settings updates | See Score breakdown | Breakdown: hard-coded |
| `board_changed` | Cleared cards shrink to 20% and fade; cards that fall slide down; drawn cards drop in from above (as many card heights as cards were drawn into that column) and fade in. All in one 300 ms ease-out | 300 ms | Hard-coded |
| `extra_drawn` | Toast "Amber joker: 7♥ on the board" (or "shuffled into the stock", "to your tray", or the steps prize). Feed line with the tier. No reveal; the timer doesn't pause | Toast, 2,400 ms | Hard-coded |
| `swap` | The line's cards slide to their new cells (with the board change). Feed line "Swapped ... to ...". No toast | 300 ms | Hard-coded |
| `bomb` | Red pop, then the board change. Feed line "Bomb: cleared ..." | 380 + 300 ms | Hard-coded |
| `burn` | Red pop, then the board change. Toast "Burned 7♥ for the game". Feed line with the new deck size | 380 + 300 ms | Hard-coded |
| `stock_out` | The stock pile becomes a dashed outline. Feed line "Stock empty: play out the board" or "Card budget used: play out the board" | Instant | Hard-coded |
| `reach` | Toast "Reach: hand size +1 for 20 s". The pick counter grows violet pips. The reach card's countdown starts | Toast, 2,400 ms | Seconds and cards: config (rolled) |
| `reach_over` | The pick counter shrinks back. Feed line "Reach over: hand size back to 4". No toast | Quick ease | Hard-coded |
| `no_sets_left` | Toast "No sets score: use a power joker" (or "No sets score" with none). The help line turns gold. The clock turns to Stuck and the power jokers blink, if you hold any | Toast, 2,400 ms; grace 25 s or end after 1,500 ms | Hard-coded |
| `board_cleared` | Feed line "Board cleared! +10 steps". The summary's title says "Board cleared!" | With `turn_end` | Bonus: config `clearBonus` |
| `prize_won` | Feed line "Prize: rare (best set 42), wins a bomb". The summary shows "Rare prize: a bomb, for your power jokers" | With `turn_end` | Tiers: config `prize` |
| `turn_end` | The timer stops. The turn summary covers the screen, at once | Instant | Hard-coded |
| `game_start`, `hand_start`, `deal`, `discard`, `hand_end`, `game_end` | Nothing on their own; they change which scene shows | Instant | n/a |

The steps number changes with a numeric roll (digits slide) and a quick spring; the track's fill eases over 400 ms.

Source: `GameSession.swift` (send, commit, describe, show).

## Scene: Deal

Before each turn (with the Deal setting on and a random hand), you're dealt 6 and throw 2 to the crib. It is untimed and covers the whole phone.

### Layout

```
Deal (full phone, 24 pt side padding, 36 pt top)

  TURN 2 OF 3 ................................ 14 steps so far
  THE DECK  52 cards · 1 made
    [made and burned cards, if any]

  BOT · DEALS
    6 card backs, 44 pt, fanned

  YOUR CRIB (gold) or BOT'S CRIB (violet)
    [your 2 slots] [bot's 2 slots] ............ [deck, starter on top]

  You deal. Throw 2 to your crib. ............. (Hint)

  your 6 cards, 70 pt, fanned like a held hand

  [ Tap 2 cards for the crib ]
```

| Part | Look |
|---|---|
| Header | "TURN n OF 3", 10 pt bold at 60%; after turn 1, "n steps so far" at the right, 12 pt |
| Deck panel | Compact (see Turn summary › The deck) |
| Bot's cards | Card backs 44 pt wide, overlapping by 18 pt, each turned 3° more than the last. Labelled "BOT" or "BOT · DEALS" |
| Crib slots | 54 pt cards. Empty slots are dashed `gold` outlines at 45% on `panel` at 60%; the bot's empty slots are at 50% |
| Deck | A card back, 54 pt; the starter turns up on it, tagged "STARTER" |
| Hint row | At least 44 pt tall. Before a hint: "You deal. Throw 2 to your crib." or "The bot deals. Throw 2 to its crib.", 14 pt at 80%, and a "Hint" capsule button. With a hint: a `panel` box with a `gold` border at 60%, a gold light bulb and the principle's line |
| Your hand | 70 pt cards, overlapping by 18 pt (4 pt once 4 or fewer are left), each turned 5° from the middle around its bottom edge, and dropped into a gentle arc (3 pt × distance from the middle, squared) |
| Button | Full width, 12 pt padding, 16 pt semibold. Grey ("Tap 2 cards for the crib", "Tap 1 card for the crib") until 2 are picked, then `gold` "Throw to the crib", then "Cutting the starter…" |

### States and input

```
Deal states

  Dealing in ...... 12 cards, one at a time
  Picking ......... tap cards to and from the crib; untimed
  Hinted .......... a hint shows (asked, or after a pause)
  Throwing ........ the bot throws, the starter turns
  Done ............ the match turn starts
```

- Dealing in: 12 cards, one every 90 ms, alternating, the bot's first. Each springs in over 300 ms with a light bounce: the bot's rise from 60 pt below, yours drop from 200 pt above. The bot always gets the first card, whoever deals (see Gaps).
- Picking: tap a card in your hand to throw it to the next empty crib slot; tap a card in a crib slot to take it back. Each move is a 250 ms snappy slide between the two places. A third card can't be picked. Input is open during the deal-in.
- Hint: one principle about your deal, never which cards to throw. It shows after 8 s (hard-coded) without a pick or unpick, if the Hints setting is on, or at once on "Hint". The cards it's about blink a gold ring. Once shown it stays for the deal. The hint is picked from `hints.json` › `discard` (config: each principle's worth and `minWorth`). If you ask and nothing stands out, a toast says "Nothing stands out: keep cards that work together". The principles' lines are in the engine (`Principles`), for example "Keep your 5s: every ten-card on the grid makes 15 with them."
- Throwing: tap "Throw to the crib" with 2 picked. Picking locks. The bot's 2 cards fly face down into its crib slots (450 ms spring); 550 ms later the starter turns up on the deck (400 ms spring with a bounce, scaling up from 60%); 900 ms later the match turn starts. 1,450 ms in all. Nothing here is skippable.

Source: `MatchTurnView.swift` (DealView), `GameSession.swift` (togglePick, showHint, watchHint, throwToCrib), `Hints.swift`.

## Scene: Turn summary

When the turn ends, a cover fills the phone (`bg` at 95%, 24 pt side padding, 56 pt top).

```
Turn summary

  TURN 1 OF 3        (or GAME OVER)
  Time's up                               cyan, glowing
  42 steps                                48 pt gold
    Sets scored ...................... 9
    Best set ......................... 14
    Steps from edge power ............ +6
    Cards left over .................. −4
    Clear-board bonus ................ +10     (only if cleared)
    Swaps, bombs, burns .............. 2, 1, 0
    Game so far ...................... 61 steps (from turn 2)
  Rare prize: a bomb, for your power jokers
  THE DECK  53 cards · 1 made
    [cards made and burned; this turn's ringed in gold]

  [ Next turn ]          or      [ Same seed ] [ New game ]
```

- Title by the turn's end: "Time's up" (timer), "Board cleared!" (cleared), otherwise "Turn over". 24 pt bold, `cyan`.
- Rows are 15 pt, values semibold, right-aligned.
- The prize line is 17 pt semibold `gold`. ", for your power jokers" is left off after the last turn.
- Buttons are full-width, 15 pt semibold: a solid `text` button with `bg` text, or (Same seed) an outline at 40%.
- It appears and goes at once, with no transition. There is no input here but the buttons.

### The deck

The deck panel shows on the summary and, compact, on the deal.

- A tag ("THE DECK", or "YOUR DECK" with own decks), the card count, "· n made", "· n burned".
- With no changes, the summary says "A standard 52. Cards jokers make stay in it for the game, and burned cards stay out." The compact panel says nothing more.
- Otherwise up to 14 mini cards (34 pt wide): made cards first, a thin divider, then burned cards at 45% under a red ✕. Made cards show their multiplier on a violet chip under them. Cards from this turn get a 2 pt `gold` ring. Any more are counted: "+3".

Source: `MatchTurnView.swift` (SummaryView, DeckPanel).

## Overlays

These cover the match turn. While the left-over warning or an info card shows, the board is blocked and the timers pause.

| Overlay | Look | Dismiss |
|---|---|---|
| Toast | `gold` rounded box (corner 12), 20 pt bold ink text, centred, 46% down the phone, at most the phone's width less 40 pt. Fades and scales in from 90% over 200 ms | By itself after 2,400 ms. A new toast replaces the old one and restarts the time. Can't be tapped |
| Left-over warning | Black wash at 25%; a #FFFDF7 card (corner 16, deep shadow), 20 pt from the sides: "Every card must score", the rule, the cards left over in #C00000 bold, and the cost from config. "Got it" button | "Got it" only |
| Info card | Black wash at 25%; a 340 pt card face card (corner 14): a title and 2 to 5 lines for the hand, the crib, the starter, power jokers or hand size. Lines use config values (power per level, cap, pick limit). "Got it" button | "Got it", or a tap on the wash |
| Hint blink | A 3 pt `gold` ring with a gold glow around the place to look, blinking 15% to 100% opacity, 500 ms each way | When the hint no longer applies |

The left-over warning shows the first time a set has a card left over in each hand (see Gaps: rules want once ever).

Source: `MatchTurnView.swift` (Toast, WarningCard, InfoCard), `Hints.swift`.

## Settings panel

A tap on the header or footer opens the settings in a panel anchored above the footer (340 × 620 pt), in the dark panel colours with a `cyan` tint. A tap outside closes it. It has a title (the app's name, then the build line and build number: `Mac 0.15.4 · spec 2 · r23 (54)`) and three tabs. The app menu's About panel shows the same build line, without the build number (PORTING.md › Versions). Settings live for the session only; they reset when the app starts.

| Tab | Contents |
|---|---|
| Game | Toggles: you deal the first turn; the timer (with its seconds from config); the deal; hints. Hand: Random or Strong (4♥ 5♣ 6♦ J♠, starter 5♠). A seed field (shows this turn's seed; type one and press Return, or blank for random) and "New game". The last score's lines, edge power, left over and steps. "This turn": the newest 8 feed lines, or "Drag across 2 to N touching cards." |
| Advanced | Card budget: Whole stock, 12, 16, 24 (next turn). Shared deck (next game), with an explanation. In the beta, "Show the game record" (reveals the record file). A short how to play |
| Animation | "Play each score's breakdown (tap to skip)". Speed: Slow (1.2 s), Medium (0.9 s), Quick (0.6 s), Practised (0.4 s). In the beta, Diagnostics: slow motion (5× slower), frames per second, hitches during moves, the worst frame, and a reset |

Settings take effect at the next turn or game, except the breakdown toggle and speed, which apply to the next score, and slow motion, which applies at once.

Source: `MatchTurnView.swift` (SidePanel), `GameSession.swift` (TurnSettings).

## Keyboard and menus

| Key | Menu item | Does |
|---|---|---|
| Command-N | New Turn | Starts a new game: the seed typed in settings, or a random one (1 to 999,999) |
| Command-R | Same Seed Again | Starts a new game from the current seed |

Both work in any scene, at any time, including during a breakdown (see Gaps). There are no keys for play: no cancel, no submit, no joker keys. A port on Linux or Windows SHOULD use Control in place of Command.

Source: `CribMazeApp.swift`.

## Sound and haptics

The app plays no sounds and no haptics yet. There is no effects catalogue (`fx.json`) and no sound or haptic switches.

ARCHITECTURE.md › Presenter and cues sketches where they'll go. A port SHOULD leave room for these cue points, which this spec's cue sheets already name:

| Cue point | Planned (ARCHITECTURE.md) |
|---|---|
| A set locks in (breakdown order 2, or the pop) | Cards pulse, a tick sound, a light tap |
| Each combo lights (order 6) | Points count up |
| The total (order 13) | A chime that grows with the score |
| Steps fly to the counter (order 15) | Steps fly |
| Skip | Jump to the end state, play only the last cue's sound |

Rules from ARCHITECTURE.md that a port MUST keep when it adds them: sound and haptics each have an off switch, and they never carry information that isn't also on screen.

Note: on the Mac, ARCHITECTURE.md plans trackpad feedback (three patterns) and a small on-screen marker in the beta when a haptic fires; on iOS, Core Haptics.

## Hints

A hint is a small nudge when a player seems stuck. It marks a place on screen with the hint blink. Hints follow the Hints setting and never show while busy or after the turn.

| Hint | When | Where |
|---|---|---|
| Power jokers | The stuck grace is running | The power jokers panel |
| Discard principle | On the deal, after 8 s without a change, or on "Hint" | The cards it's about, and the hint row |

Source: `Hints.swift`, `MatchTurnView.swift` (DealView).

## Beta-only tools

These exist only in the beta (Noddy Yookerspiel). The release app (Crib Maze) has none of them.

- Records: every game is written as a GameRecord file under the app's data folder, `Records/<YYYY-MM-DD>/<time>-crib-maze.jsonl` (ARCHITECTURE.md › GameRecord). Writing starts at the player's first choice, so a game opened and left leaves no file. The deal's hint is kept as a `deal_hint` note.
- Diagnostics: slow motion and the frame meter (see Settings panel). A hitch is a frame that took over 1.5 times the display's frame time while something was moving.
- Command-line modes: `--snapshot <png>` renders the play screen (or the deal, or a breakdown's last frame) to an image and quits, with options to pick a seed, a turn, traces, a selection, an armed joker and more. `--demo [--slow]` has the medium bot play turn after turn with full animation and no waiting for taps, for profiling.

Source: `Beta/Recording.swift`, `Beta/Snapshot.swift`, `Motion.swift`.

## Hard-coded numbers

Numbers in the app's code that the game feel depends on and that SHOULD move to config, so a port and the beta tune the same values. Layout sizes (card size, gaps, paddings, text sizes) are left out: they belong in a theme or layout file, not game config. "Config today" names a file that already holds the same value for the simulator, where one does.

| # | Value | Where it's used | Config today | Should move to |
|---|---|---|---|---|
| 1 | 25 s | Stuck grace with power jokers | None (rules.md: to tune) | `rules.json` › match |
| 2 | 1,500 ms | Stuck board with no power jokers ends after | `timing.json` human `ending` (1,500), not read | `timing.json` or `fx.json` |
| 3 | 8 s | Discard hint shows after a pause | None | `hints.json` › discard |
| 4 | 1,200 ms | Breakdown base step (Slow) | `timing.json` human `breakdownBase`, read since 0.15.2 | Done |
| 5 | 0.85 | Breakdown step gets quicker by | `timing.json` human `breakdownStep`, read since 0.15.2 | Done |
| 6 | 400 ms | Breakdown shortest step | `timing.json` human `breakdownMin`, read since 0.15.2 | Done |
| 7 | 1,200, 900, 600, 400 ms | Breakdown speed choices | None | `fx.json` |
| 8 | 150, 650, 900 ms | Breakdown waits before the row, the banner, the tally | None | `fx.json` |
| 9 | 500 ms | Breakdown wait after the total line | None | `fx.json` |
| 10 | 88% / 12% | A combo's step: lit, then unlit | None | `fx.json` |
| 11 | 500 ms | Fly home after the hold (not skippable) | None | `fx.json` |
| 12 | 50 ms | Stagger between row card flights | None | `fx.json` |
| 13 | 340 ms | Score pop with the breakdown off | None | `fx.json` |
| 14 | 380 ms | Bomb and burn pop | None | `fx.json` |
| 15 | 320 ms | Busy time after the board changes, and the steps bump | None | `fx.json` |
| 16 | 300 ms | Board change (clear, fall, drop in) | None | `fx.json` |
| 17 | 1,000 ms; 180, 450, 270 ms; 36 pt | Float life, keyframes, rise | None | `fx.json` |
| 18 | 2,400 ms | Toast time | None | `fx.json` |
| 19 | 90 ms | Deal: time between cards | `timing.json` human `dealIn` (1,600 for the whole deal), not read | `timing.json` or `fx.json` |
| 20 | 550 ms, 900 ms | Deal: bot throw to starter, starter to turn start | None | `fx.json` |
| 21 | 10 s | Clock shows seconds from | None | `fx.json` |
| 22 | 10% | Clock turns orange in the last | None | `fx.json` |
| 23 | 50%, 25%, 10% | Clock breath urgency thresholds | None | `fx.json` |
| 24 | 2.0, 1.4, 0.9, 0.55 s | Clock half-breath per urgency | None | `fx.json` |
| 25 | 0.05, 0.07, 0.10, 0.13 | Clock breath depth per urgency | None | `fx.json` |
| 26 | 600 ms | Stuck clock pulse | None | `fx.json` |
| 27 | 500 ms | Hint blink | None | `fx.json` |
| 28 | 121 steps | Progress track length, and its tooltip | None (rules.md: 61 or 121) | `rules.json` › game, once the maze is specced |
| 29 | 70% | Drag hit area (ARCHITECTURE.md: a setting) | None | A player setting, default in config |
| 30 | 6 pt | Movement that starts a drag | None | Input config |
| 31 | 80 × 24 pt | Word tag tap box | None | Layout file |
| 32 | 12, 16, 24 | Card budget choices in settings | None | `rules.json` › match |
| 33 | 4H 5C 6D JS, 5S | The Strong hand | None | A fixtures or scenarios file |
| 34 | 1 to 999,999 | Random seed range | None | App config |
| 35 | "about 20 seconds", "+1 (sometimes +2)" | Reach tooltip text | Rolled from `specials.reach`; text not tied to it | Generate from `rules.json` › specials.reach |
| 36 | 50 (percent per level) | Fallback when config is missing, in the info card and chips; the breakdown's fallback is 10 | `rules.json` `edgePower.percentPerLevel` (10) | Remove the fallbacks: config MUST load |
| 37 | 2 (left-over cost), swapper and bomb (known kinds), 4 (min slots) | Fallbacks and the slot count | `rules.json` | Remove the fallbacks; slot count to layout |
| 38 | 8 lines, 14 cards | Feed lines in settings; mini cards in the deck panel | None | Layout file |
| 39 | 5× | Slow motion | None | Beta config |

39 rows.

## Platform seams

Each place the app relies on something Apple-specific, and what any platform MUST (or SHOULD) provide instead.

| Seam | In the app (Apple) | A port provides |
|---|---|---|
| Window | One fixed-size window sized to its content, not resizable, titled with the app's name | A fixed-size window, or a full-screen view with the phone centred |
| Screen size | The main screen's usable height, to scale the phone | The work area's height (taskbar excluded) |
| Drawing and layout | A declarative UI toolkit; views placed by offset in a fixed board space | Any 2D scene or canvas. Cards placed by absolute position in the 352 × 480 board space |
| Animation | Springs (duration and bounce), ease curves, keyframes, numeric text roll, views that move between places when they change parent | A tween library with springs and easing, keyframe tracks, and a way to fly a card between two parents |
| Shapes | Vector paths, rounded rectangles, path union for the edge background | Vector paths with union (or draw two rounded rectangles and their outline carefully) |
| Text | System font at its condensed width; a text-style selector so suit glyphs never draw as emoji | Bundle Saira Semi Condensed from `design/fonts/`, and draw suits and ★ from shapes.json (Type) |
| Pointer | A drag gesture with no minimum distance, then a 6 pt threshold; hover for tooltips | Raw pointer down, move and up events; tooltips on hover. On touch: the same, with no hover |
| Cursor | A crosshair over the board while a bomb or burn is armed | A cursor API (none on touch) |
| Settings panel | A popover anchored to the footer, dark appearance, native toggles, pickers and a text field | Any anchored panel or modal sheet with the same controls |
| Menus and shortcuts | App menu items with Command-N and Command-R | A menu or shortcuts with Control-N and Control-R |
| Timers | Async tasks on the main thread sleeping 1 s; a monotonic clock for game time | Main-loop timers and a monotonic clock. Timers MUST run on the UI thread or post to it, since they change what's shown |
| Config files | Bundled as a resource folder | A resources folder beside the app |
| Records folder | The user's Application Support folder | The per-user app data folder (XDG data home on Linux, AppData on Windows) |
| Install ID | Stored in user defaults | Any small per-user settings store |
| Reveal a file | Opens Finder with the record selected | The platform's file manager, or a "copy path" button |
| Version stamp | App version, build number and git commit read from the app bundle's info | Stamped at build time into the binary or a resource |
| Frame meter | A display link that fires every frame | A vsync or frame callback |
| Logging | The system log (subsystem `ca.robotpony.cribmaze`) | Any log |
| Snapshot | Renders the view offscreen to a PNG | Offscreen rendering to an image |
| Sound (planned) | A low-latency audio engine with preloaded buffers and buses | Any low-latency audio mixer with preloading and volume per bus |
| Haptics (planned) | Trackpad feedback on Mac; Core Haptics on iOS | Controller rumble or nothing; the beta's on-screen marker |
| Reduce Motion (planned) | The system's Reduce Motion setting | The platform's reduced-motion setting, or an in-app switch |

## Gaps

Behaviour found while writing this spec that seems unintended, is unclear, or disagrees with rules.md, engine.md or ARCHITECTURE.md. Nothing was run; these come from reading the code.

1. No joker reveal. rules.md › Jokers and extra cards says an extra card on the board pauses play and the timer and plays a reveal; engine.md › Clock and timer says the timer pauses for it. The app shows only a toast and a feed line, and the timer keeps running.
2. The bot never plays a match turn. rules.md says the computer players' turns come first, as a quick sequence of results. The app's bot only deals and throws (engine.md › The game says bots don't play grid turns yet, so rules.md is ahead of both).
3. The left-over warning shows once per hand. engine.md › Left-over warning says once per player, ever, passed in from a saved profile. The app never passes `warned` into a hand, so it starts false every turn.
4. Fixed in 0.15.2: action times didn't pause. `clockMs` is now game time since the game started, stopped while the turn timer is; engine.md says so.
5. The breakdown holds for a tap with no time limit, and the turn timer and reach timers stay paused while it holds. A player can stop the clock as long as they like. rules.md says "a tap skips to the end" and doesn't mention the hold, so skipping takes two taps.
6. The turn timer keeps running while the settings panel is open, though it pauses for info cards and the warning.
7. A board-armed joker can't be cancelled. rules.md says tap it again to cancel. Tapping an armed bomb on the board again bombs at its own cell; tapping the matching tray joker re-arms it from the tray instead of cancelling.
8. A failed target drops the board source. With a swapper or bomb armed from the board, a line that isn't straight, or a bomb tap on an edge card, keeps the joker armed but forgets its board cell, so the next try uses one from the tray.
9. Tapping a tray swapper, bomb or burn arms it during the short busy time after a pop (the 640 to 700 ms with no breakdown). It isn't sent until the move ends, so this is harmless, but it is the one input not blocked while busy.
10. Starting a new game (Command-N, Command-R, the seed field) during a breakdown looks unsafe: the breakdown's task carries on and, when it ends, puts the old turn's board back on screen. Not seen in play; worth checking.
11. A stuck board ending by itself is recorded as reason `player`, so the feed says "You ended the turn" though there's no End turn button. rules.md › Ending the turn still says "Use a special joker, or end your turn".
12. The stuck grace starts whenever you hold any power joker, including a reach that can't open a set or a burn when the deck is at its minimum.
13. A `leftover_penalty` (a set with no combo, once warned) has no on-screen cue besides the steps dropping. The only explanation is in the feed, behind the settings.
14. The progress track measures this turn's steps against 121. rules.md has a 61 or 121 step main route, and steps are spent on the maze across the game, so the track neither matches the game length nor the game's total.
15. The Command-N menu item is called "New Turn" but starts a new game.
16. The deal always deals the bot's card first, even when the bot deals; the code comment says the dealer deals to the other player first.
17. The drag hit area (70%) is fixed. ARCHITECTURE.md › Mac first, iOS later says it's a setting, as in the mock.
18. Partly fixed in 0.15.2: the app reads the table colours from `palette.json`. It still doesn't read `shapes.json`, a few colours aren't in the palette (page, ink, the starter bed, the clock's green, orange and red, the left-over reds), and the reach and burn icons are drawn only in Swift. Cards keep the cards.js art; the neon cards were dropped (2026-11-16).
19. Fixed in 0.15.2: the app reads its breakdown base, step and minimum from `timing.json` › profiles.human, so tuning the file changes both the app and the simulator. The other `timing.json` numbers (Hard-coded numbers 2, 19) still aren't read.
20. Config fallbacks disagree: with no config, edge power per level falls back to 50% in the info card and chips but 10% in the breakdown. Config failing to load shows an error screen, so this only matters if a field goes missing.
21. Reduce Motion (ARCHITECTURE.md › Presenter and cues) isn't supported, and there are no sound or haptic switches yet (none are needed until sound and haptics exist).
22. rules.md's status line says match rules r22 is in the beta; the beta and `rules.json` are at r23.
23. The info card for your hand says "The 4 cards you kept from the deal" even with the Deal setting off.
24. The phone is 402 pt wide; the mocks' frame is 393 pt (mocks/README.md). The extra 18 pt in the width has no stated reason.
25. Breakdown speed changes only the waits; the springs and fades inside each cue keep their length. At Practised speed (400 ms steps), a 250 ms spring and 150 ms unlight fill most of each step. Unclear whether that's meant.
26. Settings reset every launch, including the breakdown speed that rules.md calls a player setting.

## Source

The beta app at 0.15.0 (`MARKETING_VERSION` in `apps/apple/project.yml`), rules `match-r23` (`cribbage/minigames/config/rules.json`):

- `apps/apple/Shared/`: `MatchTurnView.swift`, `GameSession.swift`, `Breakdown.swift`, `BoardView.swift`, `CardView.swift`, `Motion.swift`, `Theme.swift`, `Hints.swift`, `CribMazeApp.swift`, `GameRecorder.swift`
- `apps/apple/Beta/`: `Edition.swift`, `Recording.swift`, `Snapshot.swift`; `apps/apple/Release/` for the release stand-ins
- `cribbage/minigames/config/`: `rules.json`, `timing.json`, `hints.json`
- `design/neon/palette.json`, `design/neon/shapes.json`
- Read alongside: [engine.md](engine.md), [rules.md](rules.md), [mocks/README.md](mocks/README.md), `ARCHITECTURE.md`
