// Crib Maze: joker outcomes for the joker mock (2026-11-14).
//
// The deck's 4 extra cards: 2 jokers (amber and teal), the title card and the blank
// card. Each has a small table of chances to become one of its outcomes. Drawing one
// rolls once on its table. Starting values, to tune:
//
//   Amber joker: 90% a card, 9% a scoring card, 1% an item
//   Teal joker:  80% a card, 15% a scoring card, 5% a special joker for the stock
//   Title card, blank card: a third each a 5 for the board, a special joker, +5 pips
//                           (placeholders until their prizes are designed)
//
// Tests: jokers.test.js. Plain script (no modules) so the mocks open from disk.

(function () {
  const window = typeof globalThis.window !== "undefined" ? globalThis.window : globalThis;

  // Players never see these names, notes or chances; they're for the game maker.
  // tier sets how big the reveal is (quiet, glint, burst), so rarity is felt, not read.
  // goes says where the prize lands: the card's spot on the board, the stock, the tray or pips.
  const OUTCOMES = {
    card:    { name: "A card",         tier: "quiet", goes: "board", note: "A new card of any rank and suit, kept in the deck for the rest of the game" },
    scoring: { name: "A scoring card", tier: "glint", goes: "board", note: "A new 5 or 10-value card (10, J, Q, K), kept in the deck for the rest of the game" },
    item:    { name: "An item",        tier: "burst", goes: "tray",  note: "An item for your tray. Items aren't designed yet" },
    power:   { name: "A special joker", tier: "burst", goes: "stock", note: "A special joker, picked from every known one, is shuffled into this turn's stock" },
    five:    { name: "A 5",            tier: "glint", goes: "board", note: "A new 5, kept in the deck for the rest of the game (placeholder)" },
    named:   { name: "A special joker", tier: "burst", goes: "tray",  note: "A swapper or bomb joins the tray (placeholder)" },
    pips:    { name: "+5 pips",        tier: "glint", goes: "pips",  note: "5 pips (placeholder)" },
  };

  // The extra cards. joker: true for the two jokers (drawn with WarpedCards.joker);
  // the others are drawn with WarpedCards.extra. hint is the first-meeting line, which
  // never mentions odds or outcomes.
  const KINDS = {
    amber: { joker: true, hint: "Jokers turn into something. Let's see what." },
    teal:  { joker: true, hint: "Another kind of joker. It turns into something too." },
    title: { joker: false, hint: "The deck's title card. It turns into something." },
    blank: { joker: false, hint: "A blank card. It could become anything." },
  };

  // Chances in percent; each table MUST add up to 100.
  const TABLES = {
    amber: [{ id: "card", pct: 90 }, { id: "scoring", pct: 9 }, { id: "item", pct: 1 }],
    teal:  [{ id: "card", pct: 80 }, { id: "scoring", pct: 15 }, { id: "power", pct: 5 }],
    title: [{ id: "five", pct: 34 }, { id: "named", pct: 33 }, { id: "pips", pct: 33 }],
    blank: [{ id: "five", pct: 34 }, { id: "named", pct: 33 }, { id: "pips", pct: 33 }],
  };

  const total = (table) => table.reduce((a, o) => a + o.pct, 0);

  // Rolls once on a table. r is a number in [0, 1), Math.random() by default.
  function roll(table, r) {
    if (r === undefined) r = Math.random();
    const x = r * total(table);
    let acc = 0;
    for (const o of table) { acc += o.pct; if (x < acc) return o.id; }
    return table[table.length - 1].id;
  }

  // Scoring cards: the ranks that make the most fifteens (5, and the four 10-value ranks).
  const isScoring = (card) => card.r === 5 || card.r >= 10;

  // The chance of seeing an outcome at least once in n draws.
  const atLeastOnce = (pct, n) => 1 - Math.pow(1 - pct / 100, n);

  // A small seeded generator, so simulations and tests repeat exactly.
  function rng(seed) {
    let s = seed >>> 0 || 1;
    return () => { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
  }

  const api = { OUTCOMES, KINDS, TABLES, total, roll, isScoring, atLeastOnce, rng };
  if (typeof module !== "undefined") module.exports = api;
  window.WarpedJokers = api;
})();
