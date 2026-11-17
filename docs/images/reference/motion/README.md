# Motion reference

The main cues filmed from the Mac beta at 5x slow motion (`fx.json` › waits.slowMotion), seed 1, by `apps/apple/scripts/reference.sh --motion` from Apple build 0.18.0, spec 4. One second of video is a fifth of a second of game. The beta films its own offscreen window (`--film <file> --cue <cue>`); each frame is stamped with when it was taken, so the pace is true even where the frame rate dips (about 15 to 25 frames a second of video, 75 to 125 a second of game time).

The numbers behind every motion are in `config/fx.json` and ui.md › Motion; these films are for checking a port's feel against them, not for reading values off.

| Film | Shows |
|---|---|
| [deal.mp4](deal.mp4) | The deal: twelve cards in, one every 90 ms, each on a 300 ms spring (the throw needs a tap, so it is not here) |
| [opening.mp4](opening.mp4) | The opening count (r24): the hand, then the crib, rise into the row and count aloud over the empty board, their steps fly to the counter, then the grid deals in |
| [trace.mp4](trace.mp4) | Tracing 8♥ then 7♣: the selected look on each card, the fifteen lighting, then the score pop with the breakdown off, and the board change as new cards fall in |
| [breakdown.mp4](breakdown.mp4) | A breakdown of A♣ A♥ 7♦ 6♦ (a fifteen, a pair, one edge card): every cue in ui.md › Cue sheet, through the hold (the film does not wait) and the fly home |
| [bomb.mp4](bomb.mp4) | A bomb armed, then fired on the top-left card: the bomb pop and the board change |
| [fill-rain.mp4](fill-rain.mp4) | The grid fills, rain: column by column from above (0.21.0) |
| [fill-deal.mp4](fill-deal.mp4) | The grid fills, deal: card by card from the deck pile (0.21.0) |
| [fill-spiral.mp4](fill-spiral.mp4) | The grid fills, spiral: clockwise from the top left, growing in (0.21.0) |
| [fill-wave.mp4](fill-wave.mp4) | The grid fills, wave: diagonals from the corner by the starter (0.21.0) |
| [fill-scatter.mp4](fill-scatter.mp4) | The grid fills, scatter: tossed on in a random order (0.21.0) |
