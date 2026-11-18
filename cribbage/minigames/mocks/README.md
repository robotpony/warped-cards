# Crib RPG mocks

Clickable HTML mocks in an iPhone frame (393 x 852 pt, cards at 64 pt). Open the files straight from disk. Cards come from the shared renderer in `design/cards/cards.js`; scoring comes from `scoring.js`, shared by the mocks, with tests in `scoring.test.js` (run `node --test cribbage/minigames/mocks/` from the repo root).

Every scoring set is a single (exactly one combo, like 7-8) or a multi (two or more, like 4-5-6: a fifteen and a run). Each fifteen counts as its own combo, as when counting aloud, so 5-5-5-J is a multi of 6. The breakdown banner shows SINGLE or MULTI ×N, the match turn feed shows it, and each run records its singles and multis. Scoring works for sets of any size; the tests cover runs and fifteens of 6 and 7 cards, though the match turn still caps sets at 5.

| Mock | What it covers | Status |
|---|---|---|
| [match-turn.html](match-turn.html) | Frozen at r16 (2026-11-15): Noddy Yookerspiel, the beta (`apps/apple`, run `/debug` or `apps/apple/scripts/debug.sh`) is the match turn mock now. One match turn, Boggle-style: trace to score, the score breakdown, set suits, cards left over (warning and cost), lit combos while tracing, joker reveals, special jokers (swapper, bomb), edge power multipliers, prizes, timer and card budget, play-out, and begin and end effects (deal-in, board cleared, wrap-up) | v9, 2026-11-14 |
| [jokers.html](jokers.html) | Joker mechanics on their own: the amber and teal jokers and the title and blank cards, each rolling on a hidden table of chances. Players see a shuffle, wheel or die, the prize revealed (bigger for rarer prizes) and flown to where it goes. Game-maker panels edit the chances and simulate 10,000 games. Outcome logic in `jokers.js`, tests in `jokers.test.js`; the reveal in `reveal.js` and `reveal.css`, shared with the match turn | v3, 2026-11-14 |
| [card-chips.html](card-chips.html) | Where a card's multiplier chip goes so it stops covering the HAND, CRIB and STARTER tags: today's corner chip, then four ways over the suit (a pill on it, a pill under it, a coin on its shoulder, a suit plate), with the made card's ★ moved inside under the rank | v1, 2026-11-17 |
| [joker-inventory.html](joker-inventory.html) | A catalogue of every joker, chip, badge, deck edit, extra card and joker-driven mechanic, built, designed or idea, to ideate from. Card changes last the game (deck building). Filter by type, status, area and how long it lasts. The data is in `joker-inventory.js`: add an idea by adding an entry. Includes a sketch of chips on jokers and a power cap in the footer | v1, 2026-11-15 |
| [maze-board.html](maze-board.html) | Pegging on the maze (concept.md › Phases, 7): every set from a real grid turn (`maze-sets.js`, 180 recorded medium-bot turns) is a play, listed with its cards, steps and suit; players take turns walking one, or spending it to close a door or flip a switch. The board previews where a play lands. Walks go forward; junctions alternate; doors need suit and strength; stars give jokers. Settings for the maze, doors and closing, and bot styles (balanced, racer, timer, door closer, jokers), with a bot-run panel that plays whole games and reports rounds a game, wins by seat and how often each feature is used. On maze-walk's grid maze in the neon look. v1 (a round board) and v2 (play to 31 with a points pool) drifted from the design and were replaced the same day | v11, 2026-11-17. v11: landing on another player starts a duel, fires within 10 steps. v10: one joker set across both phases (reach picks junction ways, burn sets a fire, the key card), the camera fits every token, about 22 doors a maze. v9: a way round every golden door, single walls as a setting, the power jokers tray as on the scoring turn, starting jokers, bombs only through thin walls. v8: one golden path with variants (no short loops), 900 steps, duels with the players' kept hands, bot duels as a result card, golden path in the designer view. v7: the DUEL! screen (classic pegging, then the consequences), no closing in the way of someone who closed in yours. v6: gates merged into card doors, plays as a fan, joker tray (one joker a turn, before or after the play), tap the maze to explain, the maze stirs or a duel when players are stuck. v5: tokens hop, the camera fits each walk then closes in on the next player, doors are slanted cards, quiet junction arrows with the walk's turns in gold, choices laid over the chosen play. v4: zoomed in to about 7 cells across, like maze-walk (a Zoom setting steps out); junctions only at real forks, as gold discs; a key under the maze; plays in maze-walk's tile shape; other players' plays as a count and total |
| [maze-sets.js](maze-sets.js) | Data for the maze mocks: 180 grid turns the medium bot played (`cribmaze-sim record --games 60 --seed 1 --level medium`, match-r27), each a list of plays with cards, steps, suit and what scored, and the 4 cards the player kept (matched from the same recordings) | 2026-11-17 |
| [maze-walk.html](maze-walk.html) | A Labyrinth-style walk to the goal, generated from the game's seed (change the seed, get another maze and other rounds). Bundles of steps with suits, forks you choose at, gated shortcuts, doors on the route that absorb steps, prize cells with items (jump ahead, skeleton key, extra steps), fog. Settings for game length, sets per round, how a set walks, doors, gates and prize triggers. You and 1 or 2 bots take turns making plays, as in pegging. The view shows a quarter of the maze and follows whoever's turn it is (or you), with a pointer to the goal. The sets are stand-ins | v4, 2026-11-14 |
| [maze-tiles.html](maze-tiles.html) | Style guide for the maze's tiles and icons: floor, walls, start, goal, tokens, doors, gates, prizes, fork choices, the route, fog, at game size. Sliders tune sizes live; "Copy values" gives the line for `maze-art.js`, which both maze mocks draw from | v1, 2026-11-14 |
| [maze-retro.html](maze-retro.html) | Three retro looks for the maze tiles and pieces, to pick from: 8-bit cartridge, 70s board game and vector arcade. Standalone; it doesn't change `maze-art.js` | v1, 2026-11-14. Bruce chose C, vector arcade (2026-11-14) |
| [Neon assets](../../../design/neon/index.html) | The chosen look as a full asset set, with a tracker of every asset and its status ([cards](../../../design/neon/cards.html), [maze](../../../design/neon/maze.html)). Code in `design/neon/` with the same calls as `cards.js` and `maze-art.js`; the app reads `palette.json` and `shapes.json`. Tests: `node --test design/neon/`. The mocks still use the felt look until they switch over | v1, 2026-11-14 |
| Score breakdown | Merged into the match turn in v4. The standalone mock (v1, with presets) is in git history | Retired |
| Prize pick | Choosing where a prize goes (deck or power slot), badges | After the engine (PLAN.md Phase 6), with the prize rules |
| Pegging on the maze | Pegging with live token movement | After the engine (PLAN.md Phase 6), with maze design |

## Maze walk v1 to v4: from the seed, clear to read, a closer view, turns (2026-11-14)

The maze, the rounds and the prizes all come from the game's seed through the engine's dice (`dice.js`, streams `maze`, `deal` and `prize`), so a seed always gives the same game. Inspiration and generator notes: [maze-inspiration.md](../maze-inspiration.md).

- The maze: a recursive backtracker on a 9 × 9 grid (short game) or 13 × 13 (long), with the goal exactly 61 or 121 steps from the start. Loops that don't shorten the route make forks; shortcuts that do are guarded by suit gates. Doors on the route get stronger as you go. Prize cells sit at dead ends.
- Stand-in sets: each round shuffles the deck and takes the best set of 2 to 5 from each run of 7 cards, every card in a combo. Pegging is 2 or 3 single-card scores.
- Visual goals (Bruce, 2026-11-14), the bar every maze view must meet:
  - Every cell reads as part of a grid, at least subtly.
  - Start and goal are clear at a glance. Doors are clearly doors. Walls are clear.
  - The art style stays simple, but it must be clear.
- v2 meets them: a floor tile per cell, 3.5 pt walls with a heavier outer wall, a cream start pad and a ringed gold goal pad, doors as wooden planks with a strength badge (broken doors leave stubs), gates as cream plates in their suit colour, and a legend under the maze.
- v3 (Bruce's notes): the view shows a quarter of the maze (half its width and height), so cells are twice the size (55 pt in a long game, 80 pt in a short one). The maze scrolls as the token nears the view's edge, or keeps it centred (a setting), and a gold pointer at the edge shows which way the goal is. A designer setting shows the whole maze.
- v4 (Bruce's notes): what you spend are plays, and players take turns making them, as in pegging. Each round deals every player their plays; the seat after the dealer goes first and the deal passes each round; a player with none left says go. Bots make their biggest play first, take the shortest way at forks (through gates their suit or a key opens) and use items at once. The camera follows whoever's turn it is, or you. Tokens sharing a cell sit side by side.
- Fixed in v4: a token boxed in between two gates of other suits bounced forever without spending a step. A bounce now costs a step, so every play ends.
- Headless check, v4 (25 seeds each, your side making plays in dealt order and following the main route at forks): every game finishes. 1 bot: short games 2.3 rounds, long 3.6; 2 bots: 1.6 and 3.1. The bots win most games because they aim for shortcuts their suits open and the test player doesn't.
- The tiles and icons are drawn by `maze-art.js`, shared with the style guide (`maze-tiles.html`), so they're tuned in one place.
- Headless check (60 seeds, following the main route at forks, default settings): every seed builds and finishes. Short games took 1 to 3 rounds (mean 2.8), long games 1 to 5 (mean 4.0). Real match turns score far more than the stand-ins, so real games would end sooner unless the maze absorbs more.

## Match turn v9: one score, edge power multiplies (2026-11-14)

Rules r15, from Bruce's playtest: pips are gone, and the power levels on the hand, crib and starter multiply instead of adding.

- A set's multiplier: add the levels of its edge cards; ×1.5 a level (1 + 0.5 each), capped at ×2, rounded to the nearest step. Cards left over are taken off after, unmultiplied.
- Edge cards show their own multiplier (×1.5, ×2) instead of +1, +2. The breakdown lights each powered edge card, then a Multiplier line takes the running total up.
- The title and blank cards' +5 pips is now +5 steps. The clear-board bonus no longer offers pips.
- Fixed: a set with 5 or more of a kind (possible with cards a joker made) crashed the counter; it now scores every pair in it (five of a kind is 20). Bot batches hit it.
- Settings (Settings tab): the step per level (off, ×1.25, ×1.5, ×2), whether two or more edge cards add their levels or multiply their own multipliers, and the cap (none, ×2, ×3, ×5). Runs record them.

### v9 findings: the cap matters most (2026-11-14)

Bot batches, dealer, whole stock, mean steps per turn (min to max). Small samples: 15 turns for medium, 5 for perfect.

| Edge power | Medium bot | Perfect bot |
|---|---|---|
| Off (×1, what r14 scored in steps) | 151 (113 to 207) | 188 |
| ×1.5 a level, no cap | 1,049 (334 to 3,989) | 3,963 (564 to 9,422) |
| ×1.25 a level, cap ×3 | 322 | |
| ×1.5 a level, cap ×3 | 364 | 496 |
| ×2 a level, cap ×3 | 416 | |
| ×1.5 a level, cap ×2 (default) | 243 (147 to 414) | 353 |
| ×1.5 each card, multiplied, cap ×3 | 381 | |

- Uncapped, levels pile up all turn and scores run away. The step per level matters much less than the cap.
- With the ×2 cap, edge power adds about 60% for a medium bot and 90% for a perfect one. A person's numbers come from playtests on r15.

## Match turn v8: begin and end effects (2026-11-14)

No rules change (still r14). First mock of `concept.md` › Transitions and effects for the match turn.

- Begin: after Start turn, the grid deals in column by column (each card falls and settles), then the hand slides up, the crib slides in and the starter flips over. The board's cards stay hidden until the deal. The timer starts after it.
- End, board cleared: the empty board flashes gold, confetti bursts from the centre and "Board cleared!" lands with its bonus, then the summary.
- End, anything else (timer, no sets left, the player ends): the cards left on the grid dim and settle, and a small banner names why the turn ended and its steps, then the summary.
- Tap to skip either effect. Breakdown tab › Begin and end effects: full (about 1.6 s in, 1.9 s or 1.1 s out), quick (half) or off. Bot batches skip them.
- Each effect is logged (`effect`: name, speed, skipped), so playtests show how often people skip them.
- Fixed: End turn did nothing useful mid-reveal or mid-score; it now waits until they finish.

## Match turn v7 and jokers v3: joker reveals in the match (2026-11-14)

- Rules r12 to r14: the match turn's stock holds 0 to 2 jokers (setting: 0 to 2, 0 to 4, always 2, none), each amber or teal at random, plus the title and blank cards (setting). The plain placeholder joker and the outcome list that explained each card are gone.
- When an extra card lands on the board, play and the timer pause, the card lifts onto the stage and the joker v2 reveal plays. Settings: which animation (or a different one each draw) and reveal speed. Tap the stage to skip.
- Prizes land where they go: a new card in the card's spot, marked ★; a special joker from the teal joker on the stock pile, shuffled into this turn's stock (drawn onto the board later, it waits there until tapped; rules r14); a special joker from the title or blank card in the tray; pips on the pips counter; an item in the tray as an ITEM placeholder that does nothing yet.
- Cards a joker makes are new cards (r14), so a joker can no longer turn into another extra card. Each turn's run records how many jokers it had and the cards they made.
- A special joker on the board: tap it to arm it (it lifts and rings), tap again to cancel. Used, it leaves the board and the stock fills its spot. Bots use board special jokers before the tray's, since those only last the round.
- The title and blank cards now roll on hidden tables too, in `jokers.js` (a third each: a 5, a special joker for the tray, 5 pips; placeholders, 5 steps from r15). The joker mock can draw them.
- Shared code: `reveal.js` and `reveal.css` hold the stage, the three animations, the tiered reveal and the fly. Both mocks use them, so a change to the reveal shows in both.
- Bot batches skip the reveal and apply the prize.
- Card art: the plain joker is removed from `cards.js`; the deck's jokers are the amber and teal ones.

### v7 findings, rules r12 (2026-11-14)

Ten bot turns per level, as the dealer, all four extra cards in the stock (rules r12).

| Bot | Mean steps | Boards cleared |
|---|---|---|
| Perfect | 187 | 10 of 10 |
| Medium | 139 | 9 of 10 |
| Weak | 83 | 5 of 10 |

- With r11's placeholder (every joker a swapper or bomb), the weak bot cleared 10 of 10. Now most jokers become plain cards, special jokers come only from the title and blank cards, and the weak bot clears half as often. The extras were what made clearing easy.
- In 20 turns, the teal joker became a special joker once and the amber joker never became an item, as the chances say.
- Rules r14, medium bot, 10 turns with 0 to 4 jokers and every teal joker forced to a special joker: 133 mean steps, 9 of 10 boards cleared, 0 to 4 jokers a turn, up to 3 cards made and 3 special jokers shuffled in. The forced rolls make this a stress test, not a balance number.

## Jokers v2: chance is felt, not read (2026-11-14)

The chances tables are the game maker's tuning tool. Players never see them, or the list of possible outcomes; they discover the balance by playing.

- Draw: the joker lands on the board and play pauses. It lifts onto a dimmed stage, an animation shows the randomness, the prize is revealed, then it flies to where it goes and lands.
- Three animations, picked at random each draw or fixed in the settings: a shuffle (five jokers swap places and one steps forward), a wheel (eight jokers spin and slow, and the top one comes forward), a die (a cube of joker faces tumbles and lands). More can be added for other cases.
- Reveal size follows rarity (`tier` in `jokers.js`): a card flips quietly, a scoring card flips with a glint, an item or power card swells, flips, glows and throws rays.
- Destinations (`goes`): a card or scoring card lands in the joker's spot on the board; a power card flies to the deck pile, which pulses and counts it; an item flies to the tray. New prize types will say where they go when they're added.
- The first time a player meets each joker type, it's named with a one-line hint that says nothing about odds. After that, animation only. "Meet the jokers again" resets this.
- Tap the phone to skip: a 6-second draw finishes about 1 second after the tap.
- No record of found prizes for players (decided 2026-11-14).

## Jokers v1 (2026-11-14, replaced by v2)

Jokers get their own mock until they feel right; the match turn keeps its placeholder jokers until then.

- Two joker types, told apart by colour and symbol: amber with a star (#A85A00, 4.96:1 on the card face) and teal with a moon (#007C80, 4.88:1). Neither matches a suit colour or the named-joker purple.
- Each type rolls once on its own table when drawn. Starting chances:

| Joker | A card | A scoring card | Rare outcome |
|---|---|---|---|
| Amber | 90% | 9% | 1%: an item for the tray (items not designed yet) |
| Teal | 80% | 15% | 5%: a power card shuffled into the deck, picked from every known power card |

- A card is the next card in the stock. A scoring card is a 5 or a 10-value card (10, J, Q, K). Power cards are the named jokers so far (swapper, bomb).
- Drawing: the joker drops onto a random grid card, play pauses, a card names the joker and lists its outcomes with their chances, the highlight cycles and slows, and lands on the roll. The outcome shows with its card, then the board carries on. Roll speed: slow, normal or quick.
- The chances are editable on the page; draws are disabled until each table adds up to 100.

### Jokers v1 findings (2026-11-14)

10,000 simulated games, 16 draws of each joker per game (a guess: about 8 rounds, 2 players, each match turn drawing the whole stock).

| Outcome | Chance | Share of rolls | Games with at least one |
|---|---|---|---|
| Amber, a card | 90% | 90.07% | 100% |
| Amber, a scoring card | 9% | 8.96% | 77.9% |
| Amber, an item | 1% | 0.97% | 14.5% |
| Teal, a card | 80% | 80.04% | 100% |
| Teal, a scoring card | 15% | 14.96% | 92.6% |
| Teal, a power card | 5% | 5.00% | 55.8% |

- The amber item is rare: about 1 game in 7 sees one. The teal power card turns up in just over half of games.
- How often jokers are drawn matters as much as the chances. If each match turn draws the whole stock, every player draws both jokers every turn, and 16 draws a game is low.

## Match turn v6: left-over cards score against you, lit combos, jokers and extra cards (2026-11-14)

- Rules r10: a set with cards left over scores its combos minus 2 steps per card left over (setting: 0 to 3). The breakdown adds a red "Left over" line per card. A set with no combo at all costs the steps and clears nothing. Steps can go below 0. The first such set still brings the one-time warning, and nothing happens.
- Tracing: every selected card gets a white ring and a small lift; cards in a combo light up more (bigger, brighter, a glow). The message line shows combos, cards left over and the net.
- Swiping: a card is picked only when the finger is inside an oval at its centre (setting: whole card, 85%, 70% by default, 55%), and points between pointer events are filled in so a fast swipe doesn't skip a card. In a test swipe from one card to its diagonal neighbour, the old whole-card target caught the card beside the path with an 8 px wobble; the 70% oval held up to 16 px.
- Rules r11: the stock holds 2 jokers, a title card and a blank card (setting: all four, jokers only, none). When one lands on the board, play pauses with a card that explains it. A joker becomes a swapper or bomb in the tray; the title and blank cards cycle through three outcomes and land on one: a 5 from the stock takes its place, a named joker, or +5 pips. All placeholders. In this mock the extra cards go only into the stock, never the deal.
- How to play is rewritten to match the rules doc: the turn in five steps, then tables for what scores, cards left over, and special and extra cards, with mock-only notes kept apart at the end.
- Page layout: the panels beside the phone sit on tabs (How to play, Settings, Breakdown, Runs, Log), so one shows at a time next to the board. New turn and Watch a bot stay above the tabs. The last tab is remembered in the browser; arrow keys move between tabs.
- Card art: `design/cards/cards.js` draws the plain joker, the title card and the blank card (`extra()`), placeholder art like the swapper and bomb.
- Fix: the bot ran its swap search twice, and lower levels search from random starts, so the second search could come back empty and crash a batch.

### v6 findings, rules r11 (2026-11-14)

Ten bot turns per level, as the dealer, 90-second timer (bot batches skip it), all four extra cards in the stock.

| Bot | Mean steps | Range | Boards cleared | Extra cards per turn | Left-over cost per turn |
|---|---|---|---|---|---|
| Perfect | 182 | 159 to 218 | 10 of 10 | 4 | 0.4 |
| Medium | 136 | 119 to 150 | 10 of 10 | 4 | 1.2 |
| Weak | 86 | 69 to 97 | 10 of 10 | 4 | 0 |

- Every turn draws the whole stock, so all four extra cards turn up every turn, adding 2 to 3 jokers to the tray each time. Even the weak bot now clears the board every turn, with the extra bombs.
- Bots rarely take a set with a card left over (rules r10 alone: perfect 191, medium 139, weak 80 mean steps, with 0 to 1.6 steps of left-over cost per turn). The rule matters for people, who guess.

## Match turn v5: left-over cards cost steps (2026-11-14, replaced by r10)

- A set with a card left over (not part of any combo) doesn't score. The first time, a card on the phone explains what a valid set is, rings the left-over cards in red and charges nothing. After that, each card left over costs 2 steps (setting: nothing, 1, 2 or 3), with a red float over each one. A turn's steps never go below 0.
- The warning shows once per player, remembered in the browser. "Show the left-over warning again" resets it.
- While tracing, the message line names the cards left over and the cost.
- Sets rejected for other reasons (one card, no grid card, already scored) cost nothing.
- Runs record `penalty` (steps taken) and `leftovers` (cards); the summary shows both. Bots never trace a set with a card left over, so bot numbers don't change.

## Match turn v4: score breakdown, suits, play-out (2026-11-14)

- The score breakdown now plays on every score in the match turn, over the live board. Its settings (speed, tally placement, fifteens, floating points) sit in their own panel and apply at once. "Quick flash only" brings back the old 0.4 s flash. Tap the phone to skip to the end; "Replay the last score" plays it again on the board as it was. Each score's event records `breakdown_ms`, its time on screen.
- Each set shows its suit (or "no suit" on a tie) in the breakdown banner and total line, the feed and the event log. The turn summary adds steps by suit. The suit rule lives in `scoring.js` (`suitOf`), with a test of the rules doc's examples.
- Rules r8: when the stock or card budget runs out, nothing refills and you play out the grid. Clearing every grid card ends the turn with the clear-board bonus (setting: none, 5 or 10 steps, or 10 pips) and a "Board cleared!" summary. The turn no longer ends on an empty stock.
- When no set can score, the message line says so and End turn pulses. The check grows every connected set up to the max size after each action.
- Special cards and pips carry over between turns in the rules; this mock still resets the tray on New turn.
- Fixes: the bot bombs the cell with the biggest blast instead of a random centre cell, which could be empty and loop forever once the grid stopped refilling. Removed dead timer code.

### v4 findings, rules r8 (2026-11-14)

Ten bot turns per level, as the dealer, max 5 cards per set, clear-board bonus +10 steps. Bot batches skip the timer, so these are upper bounds for clearing.

| Bot | Mean steps | Range | Boards cleared | Steps with no suit |
|---|---|---|---|---|
| Perfect | 183 | 147 to 229 | 9 of 10 | 40% |
| Medium | 132 | 103 to 179 | 10 of 10 | 23% |
| Weak | 79 | 59 to 95 | 7 of 10 | 52% |

- Play-out adds about half again to a turn (perfect was 123 on r7), since the last 16 grid cards now score too.
- Bots clear the board almost every time, using bombs on cards left alone. A clear-board bonus won't feel special until a person under the timer clears it rarely; human playtests will tell us.
- Ties are common: a quarter to a half of all steps carry no suit, so suit gates will be strict.

## Score breakdown v1 (2026-11-14, now in the match turn)

- Order: the set lifts and the board dims; a banner names the set (its biggest combo); each combo plays one at a time, like counting a hand aloud ("Fifteen +2 → 2, Fifteen +2 → 4, Pair royal +6 → 14"), lighting its cards and floating its points; then bonuses (placeholders for prize cells, gates and badges), then edge power, each powered card lit blue; then power up, where every edge card in the set gains a level and its chip ticks up; then the total flies up to the step counter.
- Timing: steps start slow and speed up. The first step takes 1.2 s, each later step is 15% quicker, and no step is quicker than 0.4 s. An 8-step score takes about 5.8 s plus about 2.9 s to open and close. These are tuning settings in the mock for now; in the game, the first-step time becomes a player setting that quickens as they learn.
- The tally panel sits away from the set (over the top of the board when the set is low, over the bottom when it's high). Options: fifteens one line each or grouped, floating points on or off.
- The standalone mock had presets for a fifteen, a pair with fifteens, a double double run, a pair royal with his nobs, a bonus and edge power, and a run with a flush. They went with it; bonus lines come back when prize cells, gates and badges exist.

## Match turn rules versions

Every playtest run and event log carries `rules`, the match turn rules version, so stats from old rules stay apart from new ones. Bump `RULES` in the mock and add a line here whenever a rule changes. Runs saved before versioning started have no `rules` field and show as `r?`.

| Rules | Date | What changed |
|---|---|---|
| r1 | 2026-11-14 | Match-3 style: swap to make lines, cascades, automatic matching (mock v1) |
| r2 | 2026-11-14 | Boggle style: trace touching cards, Score and Swap buttons, combos must use every card (mock v2) |
| r3 | 2026-11-14 | Automatic scoring, swapper and bomb special cards, every set needs a grid card, starter apart (mock v3) |
| r4 | 2026-11-14 | Sets count like cribbage hands (every fifteen, pair, run inside the set); max cards per set setting |
| r5 | 2026-11-14 | Hand and crib cards touch only their real neighbours, like grid cards |
| r6 | 2026-11-14 | The starter sits in the corner where the hand row and crib column meet, touching only its real neighbours (last hand card, bottom crib card, grid corner). Tilted, with a light ring and a STARTER tag; the hand and crib get gold HAND and CRIB tags. Setting: keep it apart at the top, touching every hand and crib card (the r5 rule) |
| r7 | 2026-11-14 | Edge power pays into a separate tally (pips), not steps. One prize per turn, for the best score, at the end of the turn. Special cards are kept all game. The timer pauses while a score plays. Bot skill setting (perfect, strong, medium, weak) |
| r8 | 2026-11-14 | Play out the grid when the stock or budget runs out (no refills); clearing the board ends the turn with a bonus (setting). Each set's suit is recorded. Score breakdown plays on every score (mock v4) |
| r9 | 2026-11-14 | A set with a card left over doesn't score; after a one-time warning, each card left over costs 2 steps (mock v5) |
| r10 | 2026-11-14 | A set with cards left over scores its combos minus 2 steps per card left over; a set with no combo costs the steps; steps can go below 0 (mock v6) |
| r11 | 2026-11-14 | 2 jokers, a title card and a blank card in the stock; drawing one pauses play and explains its outcome (placeholders) (mock v6) |
| r12 | 2026-11-14 | The amber and teal jokers replace the placeholder joker. Each extra card plays the hidden-table reveal (shuffle, wheel or die; prize; fly to its place) instead of explaining its outcomes. A teal special card joins the deck for the next round (mock v7) |
| r13 | 2026-11-14 | A special joker from the teal joker is shuffled into this turn's stock; drawn onto the board, it joins the tray (mock v7) |
| r14 | 2026-11-14 | 0 to n jokers a round, decided at the shuffle (setting; 0 to 2 by default), each amber or teal. Cards a joker makes are new cards, marked ★, kept for the game. A special joker drawn onto the board waits until tapped, can't be part of a set, and is used up where it lies (mock v7) |
| r20 | 2026-11-15 | Joker-made cards carry a small multiplier (mostly ×1.05 to ×1.25, up to ×3). Edge power grows 10% a level (was 50%), still capped at ×1.5. Noddy Yookerspiel only; the web mock stays at r16 |
| r21 | 2026-11-15 | Edge power has no cap (was ×1.5). A cap may return as a visible mechanic jokers can change. Noddy Yookerspiel only |
| r22 | 2026-11-15 | Prizes retuned for no cap: rare from a best set of 40 steps, epic from 70 (were 25 and 31). Config gains `deck.shared` (on), for deck building. Noddy Yookerspiel only |
| r23 | 2026-11-15 | A game of 3 turns (`game.turns`). The deck lasts the game: made cards join it and burned cards leave it. New burn joker (start 1, prize weight 20), down to `deck.minSize` 40. Power jokers and each turn's prize carry over. Noddy Yookerspiel only |
| r24 | 2026-11-16 | The hand, and the dealer's crib, are counted as a classic show before the grid deals in (`opening`). A set picks at most one hand or crib card (`maxEdgeCards` 1). The hand row keeps the order you sorted it in the deal. Noddy Yookerspiel only |
| r25 | 2026-11-17 | Prizes retuned for r24's lower scores: rare from a best set of 28 steps, epic from 34 (were 40 and 70). Noddy Yookerspiel only |
| r26 | 2026-11-17 | The opening bonus: a hand or crib count wins a power joker for every 5 points past 10 (`opening.bonus`), picked like a prize, into the tray for this turn. Noddy Yookerspiel only |
| r27 | 2026-11-17 | The opening bonus starts at 6 (was 10): 11 wins 1 power joker, 16 wins 2. Noddy Yookerspiel only |
| r19 | 2026-11-15 | New power joker, the reach: sets pick 1 or 2 more cards for 10 to 45 seconds. Everyone starts with 1. Noddy Yookerspiel only; the web mock stays at r16 |
| r18 | 2026-11-15 | Flushes count like a classic hand: 4 picked cards of one suit score whatever the starter's suit. The starter never costs a set points. Crib Maze Beta only; the web mock stays at r16 |
| r17 | 2026-11-15 | A set picks 2 to 4 cards (was 5), plus the starter. Crib Maze Beta only; the web mock stays at r16 |
| r16 | 2026-11-15 | The starter counts with every set, like the starter in a cribbage hand: it isn't traced and doesn't count toward the set's cards. In a combo, its power multiplies and it powers up; otherwise it's ignored, never left over (setting) |
| r15 | 2026-11-14 | One score: no pips. Edge power multiplies a set's combos (levels added, ×1.5 a level, capped at ×2; settings). The title and blank cards' pips prize is 5 steps (mock v9) |

## Match turn v3: automatic scoring and special cards (2026-11-14)

- Sets are 2 to 5 cards (a setting can cap them at 3 or 4).
- Trace touching cards (or tap them, then tap the last one again). The set scores at once, counted like a cribbage hand: every fifteen, pair, run (double runs too), flush and his nobs inside it. 8-6-A scores a fifteen; 7-8-8 scores two fifteens and a pair. Every card must be part of at least one combo, or nothing happens. There are no Score or Swap buttons.
- Swapping is no longer free. It needs a swapper joker (⇄) from the tray at the bottom: tap it to arm it, then trace a straight line of 2 to 4 grid cards to reverse it.
- The bomb joker: tap it to arm it, then tap a grid card. That card and its neighbours (a plus shape, or a 3 x 3 square in settings) clear and refill, scoring nothing.
- The tray holds small cards stacked by type, with a count. Start with 2 swappers and 1 bomb (settings). Each prize adds a random special card.
- Every scoring set needs at least one grid card; the hand, crib and starter can't score on their own.
- Layout: a wider gap separates the hand row and crib column from the grid, and the corner where they would meet stays empty. The deck (face down) and the starter sit side by side at the top right, unlabelled, and the starter still counts as touching the hand and crib.
- Hand and crib cards touch only their real neighbours, like grid cards (diagonals count), instead of every other edge card. The last hand card and the last crib card touch diagonally across the empty corner. The starter touches every hand and crib card. The score breakdown under the step counter is gone; the end-of-turn summary keeps it.
- The bot scores the best set it can; when nothing scores it uses a swapper, then a bomb, then stops. Add `?auto&specials` to the URL to make it use one of each first (a test hook).

### Playtest runs

Every finished turn (yours or the bot's) is saved in the browser with its settings, hand, crib, starter, each set scored (cards, combos, points, time) and the totals. The Playtest runs panel shows mean steps by settings next to the classic count of the same hand and crib, and "Copy runs to clipboard" copies every run as one JSON line, ready to paste into a session. "Run 10 bot turns (fast)" adds a batch of bot runs with the current settings. Pasted runs go in `../playtests/` so the simulator can use them later.

Test hooks: `?batch=10` runs a bot batch on load; `&max=4` sets the max cards per set.

### Bot skill, rules r7 (2026-11-14)

Ten bot turns per level, as the dealer, max 5 cards per set. Edge power no longer adds steps. Lower levels trace paths like a person: from a share of the starting cards, to a set depth.

| Bot | Search | Mean steps | Range |
|---|---|---|---|
| Perfect | every set | 123 | 100 to 159 |
| Strong | depth 5, 15% of starts | 110 | 83 to 122 |
| Medium | depth 4, 50% of starts | 77 | 64 to 98 |
| Weak | depth 3, 25% of starts | 55 | 46 to 71 |

Depth matters far more than starts: depth 5 from 40% of starts scored like perfect (120), and depth 4 from 70% scored like medium (80). Test hook: `?batch=10&bot=medium`.

### Max cards per set, bot batches (2026-11-14)

Ten greedy-bot turns per setting, as the dealer, prize at 8, hand-style counting. The classic count is the same hand and crib scored as plain cribbage, for scale.

| Max cards per set | Mean steps | Range | Classic count (mean) |
|---|---|---|---|
| 3 | 68 | 39 to 125 | 7.1 |
| 4 | 93 | 74 to 131 | 9.0 |
| 5 | 145 | 115 to 184 | 8.8 |

After hand and crib cards switched to real neighbours (another 10 bot turns each):

| Max cards per set | Mean steps | Range | Classic count (mean) |
|---|---|---|---|
| 3 | 52 | 36 to 80 | 10.4 |
| 4 | 85 | 68 to 130 | 10.6 |
| 5 | 124 | 82 to 216 | 9.8 |

With the starter in the corner (r6, another 10 bot turns each): max 4, mean 73 (60 to 91), classic 9.3; max 5, mean 111 (86 to 119), classic 7.9.

Before the fix, even 3-card sets score about 9 times the classic count. Set size alone won't bring a turn near a classic hand; the grid gives too many chances. Steps per point, or fewer sets per turn, are the next levers.

### v3 findings, hand-style counting

Six greedy-bot turns, as the dealer, no timer, with the grid-card rule and sets counted like cribbage hands. Smoke test only.

| Steps per turn | Scores per turn | Prizes per turn |
|---|---|---|
| 111 to 198 | 6 to 9 | 6 to 9 (every score) |

Counting sets like hands roughly triples the score. The bot builds 5-card sets around the hand worth 15 to 25 steps each, so one turn could nearly finish a 121-step game, and every score wins a prize. Hand counting needs a lever before it can work: a cap on set size (3 or 4 cards), steps scaled down, or a prize threshold well above 8.

### v3 findings, combos using every card (before hand-style counting)

Five greedy-bot turns, as the dealer, no timer, with the grid-card rule. Smoke test only.

| Steps per turn | Scores per turn | Steps from sets with hand, crib or starter |
|---|---|---|
| 29 to 83 | 5 to 9 | 17% to 92% (varies a lot by hand) |

The hand now matters much more in good hands (a strong hand drives most of the score), but steps per turn are still far too high for a 121-step game.

## Match turn v2: Boggle-style with Score and Swap buttons (2026-11-14, replaced)

v1 matched lines automatically, like a match-3 game. v2 plays like Boggle: nothing clears on its own, and you score only what you find.

- Select up to 5 cards by tapping, or by dragging across them like tracing a Boggle word. Selected cards must touch (diagonals count); the hand, crib and starter all count as touching each other.
- Score: enabled when the selection is a classic cribbage combo that uses every selected card (fifteen, pair, pair royal, double pair royal, run, flush of 4 or 5, his nobs). Combos add up. Scored grid cards clear and refill from the stock; edge cards stay and power up. The same set can't be scored twice.
- Swap: enabled when the selection is a straight line of 2 to 4 grid cards (row, column or diagonal). It mirrors the line, reversing its order; 2 cards simply trade places.
- Prize: one score of 8 or more steps (setting), with rarer tiers at 1.5x and 2x.
- Settings: dealer, strong preset hand, timer, card budget, prize threshold, and whether selections must touch. A greedy bot can play the turn, and every action is logged with its time.

Known gaps: the hand and crib can double count against classic rules (a pair, then the pair royal that contains it; a run of 3 inside a run of 4).

### v2 findings

Six greedy-bot turns, as the dealer, no timer. The bot always takes the highest-scoring set. A smoke test, not a balance result.

| Swaps per turn | Scores per turn | Steps per turn | Prizes per turn |
|---|---|---|---|
| 0 | 7 to 10 | 44 to 81 | 1 to 5 |

- Turns now last 7 to 10 scores instead of 2 or 3 swaps, and nothing happens that the player didn't choose.
- A perfect bot never needs to swap: on a 4 x 4 grid of open cards there's always a 5 or 6 point set touching. Swap will matter more for people, and less if scoring needs bigger or rarer sets.
- Steps per turn are still far too high, about 50 against a 121-step game. The bot mostly scores 5-card grid sets, which also use up the stock fastest.
- A human under a 90-second timer will score much less than this bot; real playthroughs will tell us how much.

## Match turn v1: what the mock had (match-3 style, replaced)

- Tap or swipe to swap. A swap that makes no match bounces back.
- Settings for dealer or not, a strong preset hand, timer, card budget, and each match type on or off.
- "Watch a bot play this turn": a greedy bot that marks every pattern, then always makes the highest-scoring swap.
- An event log with times from the start of the turn, downloadable as JSON, to give the simulator real human timings.
- Add `?auto` to the URL to run the bot on load, and `&types=kind,run,flush` to choose match types.

### v1 findings (2026-11-14)

Six greedy-bot turns per setting, as the dealer. This is a smoke test, not a balance result; the real numbers come from the simulator.

| Setting | Swaps per turn | Steps per turn | Prizes per turn |
|---|---|---|---|
| All match types | 2 to 3 | 39 to 88 | 1 to 3 |
| No fifteens | 4 to 6 | 37 to 64 | 2 to 4 |

What it suggests:

1. Turns are far too short. Cascades use up the 23-card stock in 2 or 3 swaps, because 3-card fifteens and runs are everywhere in a random grid.
2. Match turns score far too much. About 50 steps per turn, against a 121-step game; a classic hand is worth about 4 to 8 points.
3. Prizes come almost every swap, so they won't feel special.

Levers to try, in the mock first and then in the simulator:

- Fifteens need 4 or more cards, or are dropped from grid matches and kept for marking only.
- Cascades score less (or nothing), and only the first matches of a swap count toward a prize.
- Fewer refills: a smaller stock, or gaps that stay empty.
- Scale grid match points down, so marking your hand stays a real share of the turn.
- Prizes need 3 or more matches from one swap.
