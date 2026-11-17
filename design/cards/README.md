# Card art

The original cream cards, as SVG, so every build draws from one source (ui.md › Cards). Each file is in the 50 × 70 unit box (`viewBox="0 0 50 70"`), scaled to the card's width.

The SVGs copy what the Mac draws today (`apps/apple/Shared/CardView.swift`, 0.15.4), not `cards.js` where the two differ. `cards.js` and `index.html` stay as the mock page.

## Files

| File | Draws |
|---|---|
| `frame.svg` | The card frame: face fill, rounded 4.5, and the 1.2 unit card rule outline. Every card starts with it |
| `face-sample.svg` | A sample face (7 of hearts) showing where the rank and suit go |
| `back.svg` | The back: frame, 41 × 61 inner outline, and the 45° crosshatch, lines 3.4 units apart |
| `icon-swap.svg` | Swapper icon: two purple arrows, one each way |
| `icon-bomb.svg` | Bomb icon: a black bomb with its cap, fuse, red spark and highlight |
| `icon-reach.svg` | Reach icon: a card, a dashed extra card over it, and a red plus |
| `icon-burn.svg` | Burn icon: a flame, red outside and gold inside |
| `joker-swap.svg`, `joker-bomb.svg`, `joker-reach.svg`, `joker-burn.svg` | The special joker layout: frame, purple inset at 50%, "JOKER" at the top, the kind's word at the bottom, and its icon |
| `extra-amber.svg`, `extra-teal.svg`, `extra-title.svg`, `extra-blank.svg` | The extra card layout: frame and the kind's name in capitals, centred, in card soft |

Each icon file is placed in the card box already, so it lays straight over the joker layout. The joker files hold the same icon group, so a build can use either the whole card or the parts.

## Text

Text in these files is a layout reference. Each `<text>` has an `id` and is centred on its x, y (`text-anchor="middle"`, `dominant-baseline="central"`). Builds SHOULD draw the text themselves at those centres, in Saira Semi Condensed bold (ui.md › Type), since not every SVG reader draws text (Godot's importer doesn't).

| Slot | Centre | Size | Colour | Notes |
|---|---|---|---|---|
| Rank | 9, 10.5 | 16 (14 for a 10, tracked −1.2) | Suit colour | Drawn again turned 180° on 41, 59.5 |
| Suit | 25, 35 | See below | Suit colour | From `design/neon/shapes.json` |
| JOKER | 25, 9.5 | 8, tracked 1 | Joker purple | Special jokers |
| Kind word | 25, 61.5 | 8, tracked 1 | Joker purple | SWAP, BOMB, REACH, BURN |
| Extra name | 25, 35 | 7 | Card soft | AMBER, TEAL, TITLE, BLANK |

The Mac draws the suit as a 34 unit text glyph today. The 24 unit box in `face-sample.svg` is a first guess at the same size from `shapes.json`; `@apple` sets it when the Mac switches to the shapes.

## Colours

The SVGs carry hex values so they open anywhere. The same colours are in `design/neon/palette.json` › colours (since Apple 0.15.6), and a build SHOULD tint from there:

| Role | Palette key | Hex |
|---|---|---|
| Card face | `card.face` | #FDFCF8 |
| Card rule | `card.rule` | #D6D0C4 |
| Ink (bomb) | `ink` | #2B2A26 |
| Card soft (fuse, hatching, extra names) | `card.soft` | #7C6C48 |
| Joker purple | `card.joker` | #6A1B9A |
| Red (spark, plus, flame) | `card.red` | #E00000 |
| Flame gold | `card.flame` | #F2B705 |

Suits, `card.suit`: spades #000000, hearts #E00000, diamonds #0070E0, clubs #00843D.

## Differences from the Mac to check

- SwiftUI rounds corners with its smooth (continuous) curve; the SVGs use plain arcs. At these radii the gap is under a tenth of a unit.
- The back's hatching is a list of lines clipped to the inner box, not an SVG pattern, so readers without pattern support draw it the same. The lines start where the Mac's start.
