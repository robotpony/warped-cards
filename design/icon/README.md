# App icon

Crib RPG's icon on every platform: four cream cards in a 2 × 2 grid, one suit each in the four-colour deck, on joker purple, with a gold star where the cards meet. No text; the app name sits under the icon (Bruce, 2026-11-16, version E2 in `index.html`).

## Source

The layers in `layers/` are the source. Each is a 1024 × 1024 SVG. Edit these, then run the export.

| File | Draws |
|---|---|
| `layers/background.svg` | Joker purple, #8A2BC2 at the top to #3D0E63 at the bottom |
| `layers/background-dark.svg` | The same purple near black, #2A0B40 to #0E0418, for dark icons |
| `layers/cards.svg` | The four cards, 316 units wide with 28 between, suits at 72% of the card width, soft shadows. Transparent around them |
| `layers/star.svg` | The gold star badge, 84 radius, centred. Transparent around it |
| `layers/favicon.svg` | Its own simpler drawing for 16 to 48 px: four tiles, one suit each, no star |

Card colours and suit shapes come from `design/neon/palette.json` (`card`) and `design/neon/shapes.json`.

`index.html` is the mock page with the ideas and versions Bruce chose from.

## Export

```
node design/icon/export.js
```

Run it from the repo root on a Mac. It needs Google Chrome to draw the SVGs and `sips` to resize them (LIBRARIES.md). It rebuilds `export/` from the layers; don't edit `export/` by hand.

| File | For |
|---|---|
| `export/apple/ios-1024.png` | iOS app icon, light. Full bleed; iOS rounds the corners |
| `export/apple/ios-1024-dark.png` | iOS dark icon: the dark background with the same cards and star |
| `export/apple/ios-1024-tinted.png` | iOS tinted icon: cards and star in grey on black; iOS adds the tint |
| `export/apple/mac-16.png` to `mac-1024.png` | macOS: the rounded plate (824 on the 1024 canvas, 185 corners) with its shadow, at 16, 32, 64, 128, 256, 512 and 1024 |
| `export/linux/crib-maze.svg` | Linux scalable icon (hicolor `scalable/apps`) |
| `export/linux/crib-maze-16.png` to `-512.png` | Linux sized icons (hicolor `NxN/apps`) |
| `export/web/favicon.svg`, `favicon.ico`, `favicon-32.png` | Browser tab icon, from the favicon layer. The `.ico` holds 16, 32 and 48 |
| `export/web/apple-touch-icon.png` | 180 px home screen icon for Safari |
| `export/web/icon-192.png`, `icon-512.png` | Web app manifest icons |
| `export/web/icon-maskable-512.png` | Manifest icon with `"purpose": "maskable"`: the art at 80% so any mask shape keeps it |

## Layers on Apple

Xcode's Icon Composer builds layered icons. Its layers SHOULD be `background.svg`, `cards.svg` and `star.svg` in that order, with `background-dark.svg` as the dark background, so the system's light, dark, tinted and glass looks come from the same source. The PNGs in `export/apple/` are for a plain asset catalogue until then.

The iOS PNGs are opaque but carry an alpha channel, which App Store Connect refuses on the light icon. Flatten it when adding it to the catalogue.
