# Crib RPG: Maze Inspiration

Status: research notes, 2026-11-14. What maze and race games do well that Crib RPG could borrow, gathered before the maze walk mock. Decisions stay in [concept.md](concept.md); this doc only feeds them. Rule summaries come mostly from fan wikis and rules sites (linked), so check numbers against official rulebooks before a spec quotes them.

## Summary

Labyrinth is the model (decided 2026-11-14): you move through the maze until you reach the goal. The other games each answer one of our open questions:

| Game | Borrow | Helps with |
|---|---|---|
| Labyrinth | Shifts move a whole line, with a spare piece; a line can't be shifted straight back | Shifting walls (removed for now, 2026-11-14) |
| Mario Party | Movement and the win currency are separate; prizes you trigger by passing | Prize cells, the shop |
| Slay the Spire | Show what kind each fork is before you reach it; a repair pass after generation | Forks, fog, generator |
| Balatro | Thresholds that rise by zone (×1.5, ×2), and a rare ×4 "Wall" on a shortcut | Door strength |
| Karuba | One resource, two uses: spend a bundle as steps or as an action | The scale problem |
| Game of the Goose | Bounce back on overshoot at the goal | The scale problem |
| Brogue | Flood-fill check after every feature; loops only between far-apart areas | Generator, open route |
| Formula D | A speed cap per move that rises as you go; overflow becomes something else | The scale problem |

## The games

### Labyrinth (Ravensburger)

Each turn you push the spare tile into an edge slot, shifting a whole row or column; the tile pushed out is the next spare. You can't push it straight back where it came from. A token pushed off one side wraps to the other ([Wikipedia](https://en.wikipedia.org/wiki/Labyrinth_(board_game)), [rules](https://officialgamerules.org/game-rules/labyrinth/)).

The fun: every shift helps you and hurts someone else, and the board is never the same twice. Borrow the line shift and the no-undo rule, so a bot and the player can't shift the same line back and forth. Avoid the wrap-around; on a phone it reads as teleporting.

### Mario Party

A 1 to 10 dice block moves you. Coins come from spaces; you buy a Star as you pass a Star Space, and in some games the Star then moves ([MarioWiki](https://www.mariowiki.com/Space_(Mario_Party_series))). The fun is landing on things, with the currency that wins kept apart from the movement. Borrow prizes you trigger by passing. Avoid luck swings that erase skill; cribbage already has the deal's luck.

### Slay the Spire's map

A branching map of about 15 floors, all visible, each node marked by type. Generation keeps some types off early floors and stops them repeating back to back; the sequel checks and repairs the map afterwards ([generation guide](https://kosgames.com/slay-the-spire-map-generation-guide-26769/)). The fun is planning a route through known risk. Borrow fork labels (door, gate, prize) that show through fog while contents stay hidden, and a repair pass after generation.

### Balatro

Each ante has three blinds: the big blind needs 1.5 times the small blind's score, most boss blinds 2 times, and The Wall 4 times ([Dot Esports](https://dotesports.com/indies/news/balatro-antes-blinds-explained)). Rising thresholds keep the target feeling close. Borrow door strength that scales by zone, with a rare strong door guarding a shortcut.

### Karuba

Each turn you place the tile you drew or discard it to move an explorer one step per path exit on it ([Wikipedia](https://www.wikipedia.org/wiki/Karuba_(board_game))). One resource, two uses, and a tense choice. Borrow: a bundle could be spent as steps or as an action (damage a door from afar, shift a wall, lift fog). This is the strongest answer found to the scale problem.

### Cribbage, Game of the Goose, Snakes and Ladders

The cribbage board's back peg shows your last score; skunk lines sit at 91 and 61. In the Game of the Goose you must land exactly on 63 and overshoot counts back; the Bridge jumps you ahead and Death sends you to the start ([Wikipedia](https://en.wikipedia.org/wiki/Game_of_the_Goose)). Borrow a ghost marker for each token's last position, and bounce on overshoot at the goal. Avoid resets to the start; after a 300-step match turn they'd feel cruel.

### Fog and generated mazes

Betrayal at House on the Hill draws its house as you explore ([rules](https://gamerules.com/rules/betrayal-at-house-on-the-hill/)). Brogue grows levels as a tree from the start, so everything is reachable, flood-fills after placing hazards, and adds loops only between areas far apart by path ([Brogue wiki](https://brogue.fandom.com/wiki/Level_Generation)). Borrow: generate the whole maze up front and let fog only hide it (we do); flood-fill after every gate, door and wall shift.

### Points to movement when points vary a lot

Formula D's gear sets the die, from a d4 in first to a d30 in sixth, and you shift up one gear a turn ([Wikipedia](https://en.wikipedia.org/wiki/Formula_D_(board_game))). Camel Up moves 1 to 3 a die, and the excitement comes from stacking and betting ([rules](https://officialgamerules.org/game-rules/camel-up/)). Borrow a speed cap per move that rises by zone, with steps over the cap going somewhere useful.

## Ideas for Crib RPG

1. **Spend or convert.** Spend a bundle as steps, or turn it into door damage, a wall shift or a fog reveal. *Scale problem.*
2. **Speed cap per zone.** At most 15, then 20, then 31 steps a move; overflow goes to a bank that can only be converted. *Scale problem.*
3. **Doors scale by zone.** Base, ×1.5, ×2, with rare ×4 doors on shortcuts only. Set the numbers by simulation. *Door strength.*
4. **Bounce at the goal.** Finish on an exact count; overshoot counts back. *Scale problem, but watch that the end doesn't stall.*
5. **Fork labels.** A fork's gate suit, door or prize shows through fog; strength and contents stay hidden. *Forks, fog.*
6. **No-undo shifts.** A shifted line can't shift back next turn, and every shift passes a flood-fill check. *Shifting walls, fairness.* (Shifting walls are removed for now, 2026-11-14.)
7. **Pass-through prizes**, claimed once, by whoever gets there first. *Prize cells.*
8. **Ghost marker** on each token's last cell, so bot moves are easy to read. *Readability.*
9. **Short gate bounce.** A wrong-suit gate bounces one cell, and the rest of the bundle isn't lost. *Gates, dragging.*
10. **Fair starts.** Check each seed so every token's start has the same route length and features nearby. *Bots and fairness.*

## Seeded maze generation

The pattern that fits: route first, then fill, then braid.

1. Lay a route of exactly the game's length with a seeded self-avoiding walk (121 cells fits a 13 × 13 grid, or 9 × 15 in portrait).
2. Fill the rest: a growing tree from the route (long, readable side paths; about 70% newest, 30% random), or Wilson's algorithm (every maze equally likely, but busy with short stubs; suits fog).
3. Braid: open some dead ends to make loops. No loop may shorten the route below its length unless a gate or door charges at least the steps it saves. Flood-fill after each feature.

Mock v1 does a simpler version: a recursive backtracker until some cell sits exactly the game's length from the start, loops that don't shorten the route, and gated shortcuts that do. Route-first generation is the next step if the mazes feel too samey or too busy. Whatever we pick, the engine spec MUST fix the generator, the dice stream and the neighbour order, so ports build the same maze.
