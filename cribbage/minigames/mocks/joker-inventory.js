// The joker inventory (joker-inventory.html): every joker, chip, extra card and joker-driven
// mechanic, built or not, so we can ideate from one list. Add an idea by adding an entry.
//
//   type    power   a power joker: sits in the tray, tap to use
//           deck    a joker shuffled into the stock; rolls a hidden table when it turns up
//           hand    a wild joker dealt into a hand, the crib or as the starter, with one power
//           extra   an extra card in the stock (title, blank)
//           chip    sits on a joker and changes what it does
//           mech    a rule on screen that jokers or chips can change
//   status  built (in Noddy Yookerspiel) · designed (in rules.md, not built) · idea
//   area    deal · grid · pegging · maze · any
//   glyph   a stand-in for card art
window.INVENTORY = [
  // Power jokers
  { id: "swapper", name: "Swap", type: "power", status: "built", area: "grid", glyph: "⇄",
    does: "Swap any two cards on the grid, including your edge cards.",
    tune: "Start 2 in the tray; 45% of prize specials.", source: "rules.md › Special jokers" },
  { id: "bomb", name: "Bomb", type: "power", status: "built", area: "grid", glyph: "✹",
    does: "Clear a plus shape of grid cards; the stock refills them.",
    tune: "Start 1; 30% of prize specials. Shape: plus.", source: "rules.md › Special jokers" },
  { id: "reach", name: "Reach", type: "power", status: "built", area: "grid", glyph: "⊞",
    does: "Hand size +1 (sometimes +2) for 10 to 45 seconds, mostly 20. A countdown shows on the card.",
    tune: "Start 1; 25% of prize specials. Cards 85/15; seconds 15/60/20/5.", source: "rules.md › Reach" },
  { id: "freeze", name: "Freeze", type: "power", status: "idea", area: "grid", glyph: "❄",
    does: "Stop the clock for 10 seconds.", notes: "Overlaps the Time hand power; maybe the power joker version is shorter." },
  { id: "peek", name: "Peek", type: "power", status: "idea", area: "grid", glyph: "◉",
    does: "Show the next 4 cards in the stock, in order, until they're drawn." },
  { id: "shuffle", name: "Reshuffle", type: "power", status: "idea", area: "grid", glyph: "↻",
    does: "Shuffle the grid's cards back into the stock and deal a fresh grid.", notes: "A way out when stuck, kinder than a bomb." },
  { id: "paint", name: "Paint", type: "power", status: "idea", area: "grid", glyph: "◐",
    does: "Change one card's suit, for the turn.", notes: "Makes hand flushes reachable. Shows the card as made (★)?" },
  { id: "nudge", name: "Nudge", type: "power", status: "idea", area: "grid", glyph: "±",
    does: "Move one card's rank up or down by 1, for the turn." },
  { id: "lift", name: "Lift", type: "power", status: "idea", area: "grid", glyph: "▲",
    does: "Raise one edge card's power by 2 levels." },
  { id: "overdrive", name: "Overdrive", type: "power", status: "idea", area: "grid", glyph: "⚡",
    does: "Raise the power cap by ×0.5 for the rest of the turn (see Power cap).", links: ["cap"] },
  { id: "recut", name: "Recut", type: "power", status: "idea", area: "grid", glyph: "✂",
    does: "Cut a new starter from the stock. The old one is shuffled back." },
  { id: "cribswap", name: "Crib swap", type: "power", status: "idea", area: "grid", glyph: "⇅",
    does: "Swap a hand card with a crib card. Their power levels go with them." },
  { id: "anchor", name: "Anchor", type: "power", status: "idea", area: "grid", glyph: "⚓",
    does: "Pin a grid card: the next set it's in scores, but it stays on the grid." },
  { id: "clone", name: "Clone", type: "power", status: "idea", area: "grid", glyph: "❏",
    does: "Copy a hand card onto a grid spot, as a made card (★)." },
  { id: "lens", name: "Lens", type: "power", status: "idea", area: "grid", glyph: "⌕",
    does: "Light every set worth 8 or more for 3 seconds.", notes: "A paid hint; ties in with the hint hooks." },

  // Deck jokers and extra cards
  { id: "amber", name: "Amber joker", type: "deck", status: "built", area: "grid", glyph: "★",
    does: "Turns up from the stock and rolls: 90% a card, 9% a scoring card, 1% an item for the tray.",
    tune: "0 to 2 a turn, amber or teal at random.", source: "rules.md › Jokers in the stock" },
  { id: "teal", name: "Teal joker", type: "deck", status: "built", area: "grid", glyph: "★",
    does: "Rolls: 80% a card, 15% a scoring card, 5% a special joker shuffled into the stock.", source: "rules.md › Jokers in the stock" },
  { id: "made", name: "Made card", type: "deck", status: "built", area: "grid", glyph: "★",
    does: "A card a joker makes carries its own multiplier, mostly ×1.05 to ×1.25, rarely up to ×3.",
    tune: "Made cards' product capped at ×3.", source: "rules.md › r20" },
  { id: "title", name: "Title card", type: "extra", status: "built", area: "grid", glyph: "T",
    does: "A third each: a new 5, a special joker for the tray, or 5 steps.", notes: "Placeholder prizes." },
  { id: "blank", name: "Blank card", type: "extra", status: "built", area: "grid", glyph: "□",
    does: "Same table as the title card for now.", notes: "Placeholder prizes; could be the joker you design mid-game." },

  // Hand jokers (designed: wild, one power each, recharged when a set with them scores)
  { id: "h-reach", name: "Reach power", type: "hand", status: "designed", area: "grid", glyph: "⊞",
    does: "Wild. Charged, a tap gives hand size +1 for a while.", source: "rules.md › A joker dealt into a hand" },
  { id: "h-multi", name: "Multiplier power", type: "hand", status: "designed", area: "grid", glyph: "×",
    does: "Wild. Charged, a tap multiplies the next set." },
  { id: "h-time", name: "Time power", type: "hand", status: "designed", area: "grid", glyph: "◷",
    does: "Wild. Charged, a tap adds seconds to the clock." },
  { id: "h-surprise", name: "Surprise power", type: "hand", status: "designed", area: "grid", glyph: "?",
    does: "Wild. Charged, a tap gives a random item or power joker." },
  { id: "h-wild", name: "Wildcard joker", type: "hand", status: "designed", area: "any", glyph: "✦",
    does: "Wild, and rolls one power from any of them when dealt." },

  // Chips: sit on a joker and change it
  { id: "c-charge", name: "Charge chip", type: "chip", status: "idea", area: "any", glyph: "+1",
    does: "The joker gets one more use." },
  { id: "c-echo", name: "Echo chip", type: "chip", status: "idea", area: "any", glyph: "×2",
    does: "The joker fires twice: two swaps, two bombs, double reach time." },
  { id: "c-long", name: "Long chip", type: "chip", status: "idea", area: "any", glyph: "◷",
    does: "Timed effects last 10 seconds longer (Reach, Freeze, Time)." },
  { id: "c-wide", name: "Wide chip", type: "chip", status: "idea", area: "grid", glyph: "▣",
    does: "Area effects grow: a bomb clears a 3 by 3, a lens lights longer." },
  { id: "c-boomerang", name: "Boomerang chip", type: "chip", status: "idea", area: "any", glyph: "↩",
    does: "The joker comes back to the tray once after it's used." },
  { id: "c-gilded", name: "Gilded chip", type: "chip", status: "idea", area: "any", glyph: "$",
    does: "Using the joker also scores 5 steps." },
  { id: "c-suited", name: "Suited chip", type: "chip", status: "idea", area: "grid", glyph: "♠",
    does: "The joker only works on one suit, but twice as strong." },
  { id: "c-lucky", name: "Lucky chip", type: "chip", status: "idea", area: "grid", glyph: "☘",
    does: "A deck joker under it rolls one row rarer on its table." },
  { id: "c-quick", name: "Quick chip", type: "chip", status: "idea", area: "grid", glyph: "»",
    does: "A hand joker's power recharges after any set scores, not just its own." },
  { id: "c-cap", name: "Governor chip", type: "chip", status: "idea", area: "grid", glyph: "⌃",
    does: "Raises the power cap by ×0.25 while it's in the tray.", links: ["cap"] },

  // Mechanics jokers and chips can change
  { id: "cap", name: "Power cap", type: "mech", status: "idea", area: "grid", glyph: "⌃",
    does: "A limit on edge power, shown in the footer beside hand size. Off since r21; it comes back only as something you can see and raise.",
    notes: "Without it, the medium bot scores 540 steps a turn and 65% of turns win epic prizes (sim, r21).", links: ["overdrive", "c-cap"] },
  { id: "handsize", name: "Hand size", type: "mech", status: "built", area: "grid", glyph: "▮▮▮▮",
    does: "How many cards a set may hold: 4, plus any reach. Shown in the footer." },
  { id: "clock", name: "Clock", type: "mech", status: "built", area: "grid", glyph: "◔",
    does: "180 seconds a turn; shows the last 10. Time and Freeze would change it." },
  { id: "edge", name: "Edge power", type: "mech", status: "built", area: "grid", glyph: "▲",
    does: "Hand, crib and starter cards gain ×0.1 each time they score. No limit since r21." },

  // Pegging and the maze
  { id: "p-double", name: "Double peg", type: "power", status: "idea", area: "pegging", glyph: "×2",
    does: "Your next pegging score counts twice." },
  { id: "p-go", name: "Hold", type: "power", status: "idea", area: "pegging", glyph: "✋",
    does: "Say go when you could play, to keep a card for later." },
  { id: "m-key", name: "Gate key", type: "power", status: "idea", area: "maze", glyph: "⚿",
    does: "Pass one suit gate without the suit." },
  { id: "m-lamp", name: "Fog lamp", type: "power", status: "idea", area: "maze", glyph: "☀",
    does: "Clear the fog around your token for the next move." },
];
