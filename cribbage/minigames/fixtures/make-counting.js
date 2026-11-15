// Writes counting.json and classic-hands.json (engine.md › Fixtures).
//
// The totals and combo counts below are worked out by hand (shown in each
// note), not by code. The combo lists (kind, size, multiplier, points, card
// indexes) are filled in by the mock counter, which must agree with every
// hand-worked number or this script stops. Run:
//   node cribbage/minigames/fixtures/make-counting.js
const fs = require("fs");
const path = require("path");
const S = require("../mocks/scoring.js");

const RANKS = { A: 1, J: 11, Q: 12, K: 13 };
const parse = (text) => text.split(/\s+/).map(t => {
  const m = t.match(/^(10|[2-9AJQK])([SHDC])$/);
  if (!m) throw new Error("bad card " + t);
  return { r: RANKS[m[1]] || +m[1], s: m[2] };
});

// [cards, hand-worked { total, fifteen, pair, run, flush, nobs, used }, note, options]
const M = { flushMin: 4 };
const counting = [
  ["AS 2H 3D", { total: 3, run: 1 }, "Run of 3 (3). Sum 6."],
  ["AS 2H 3D 4C", { total: 4, run: 1 }, "Run of 4 (4). Sum 10."],
  ["AS 2H 3D 4C 5S", { total: 7, run: 1, fifteen: 1 }, "Run of 5 (5) + all five make 15 (2)."],
  ["AS 2H 4D", { total: 0, used: 0 }, "A gap: no run, no fifteen."],
  ["3S AH 2D", { total: 3, run: 1 }, "Order doesn't matter: still a run of 3."],
  ["AS AH 2D 3C", { total: 8, run: 1, pair: 1 }, "Double run of 3 (6) + pair (2). Sum 7."],
  ["AS 2H 2D 3C 3S", { total: 16, run: 1, pair: 2 }, "Double double run of 3 (12) + 2 pairs (4). Sum 11."],
  ["AS 2H 2D 2C 3S", { total: 15, run: 1, pair: 1 }, "Triple run of 3 (9) + pair royal (6). Sum 10."],
  ["AS 2H 3D 3C 4S", { total: 10, run: 1, pair: 1 }, "Double run of 4 (8) + pair (2). Sum 13."],
  ["7S 8H", { total: 2, fifteen: 1 }, "One fifteen."],
  ["8S 6H AD", { total: 2, fifteen: 1 }, "8 + 6 + 1 = 15."],
  ["2S 3H 4D 6C", { total: 5, fifteen: 1, run: 1 }, "2+3+4+6 = 15 (2) + run 2-3-4 (3); the 6 is in the fifteen."],
  ["AS 4H 5D 5C", { total: 4, fifteen: 1, pair: 1 }, "1+4+5+5 = 15 (2) + pair (2)."],
  ["5S 5H 5D", { total: 8, fifteen: 1, pair: 1 }, "5+5+5 (2) + pair royal (6)."],
  ["5S 5H 5D 10C", { total: 14, fifteen: 4, pair: 1 }, "5+5+5 and 10 with each 5: 4 fifteens (8) + pair royal (6)."],
  ["7S 7H 8D 8C", { total: 12, fifteen: 4, pair: 2 }, "Each 7 with each 8: 4 fifteens (8) + 2 pairs (4)."],
  ["KS QH JD 5C", { total: 9, fifteen: 3, run: 1 }, "Faces count 10: 3 fifteens with the 5 (6) + run K-Q-J (3)."],
  ["AS 2H 3D 4C 5S 6H", { total: 14, fifteen: 4, run: 1 }, "Run of 6 (6). Fifteens are complements of subsets making 6: {6}, {1,5}, {2,4}, {1,2,3} = 4 (8)."],
  ["3S 4H 5D 6C 7S 8H 9D", { total: 17, fifteen: 5, run: 1 }, "Run of 7 (7). Fifteens 6+9, 7+8, 3+4+8, 3+5+7, 4+5+6 = 5 (10)."],
  ["AS AH 2D 2C 3S 3H", { total: 30, run: 1, pair: 3 }, "8 runs of 3 (24) + 3 pairs (6). Sum 12."],
  ["AH 2H 3H 4H 5H 6H 7H", { total: 30, fifteen: 8, run: 1, flush: 1 }, "Run of 7 (7) + flush of 7 (7) + 8 fifteens (16): 2+6+7, 3+5+7, 4+5+6, 1+2+5+7, 1+3+4+7, 1+3+5+6, 2+3+4+6, 1+2+3+4+5."],
  ["AS 2H 3D 7C 8S 9H", { total: 10, fifteen: 2, run: 2 }, "Two runs, A-2-3 and 7-8-9 (3 + 3), fifteens 7+8 and 1+2+3+9 (4)."],
  ["5S 5H KD 2C", { total: 6, fifteen: 2, pair: 1, used: 3 }, "K with each 5 (4) + pair (2). The 2 is left over."],
  ["2H 3H 4H 6H", { total: 9, fifteen: 1, run: 1, flush: 1 }, "Fifteen (2) + run (3) + flush of 4 (4)."],
  ["2H 3H 4H", { total: 3, run: 1 }, "Three of a suit is no flush when flushMin is 4."],
  ["5S 5H 5D 5C 5H", { total: 40, fifteen: 10, pair: 1 }, "Five 5s (one made by a joker): 10 pairs (20) + ten fifteens of three 5s (20)."],
  ["KS KH KD KC KS", { total: 20, pair: 1 }, "Five kings: 10 pairs (20)."],
  ["QS KH AD", { total: 0, used: 0 }, "Ace is low only: Q-K-A is not a run."],
].map(([cards, expect, note]) => ({ cards, options: M, expect, note }));
counting.push({ cards: "5S JS", options: { flushMin: 4, nobs: [0, 1] }, expect: { total: 3, fifteen: 1, nobs: 1 }, note: "Starter 5S (index 0) and the jack of its suit (index 1): fifteen (2) + his nobs (1)." });

const HAND = { flushMin: 5, handFlush4: true }, CRIB = { flushMin: 5, handFlush4: false };
// Classic hands: four cards, then the starter (index 4).
const classic = [
  ["5H 5C 5S JD 5D", "hand", { total: 29, fifteen: 8, pair: 1, nobs: 1 }, "The 29: J with each 5 (4) and each three 5s (4) = 8 fifteens (16), 6 pairs (12), his nobs (1)."],
  ["5H 5C 5S 5D KS", "hand", { total: 28, fifteen: 8, pair: 1 }, "K with each 5 (4) and each three 5s (4) = 8 fifteens (16), 6 pairs (12)."],
  ["7H 7S 8D 8C 9H", "hand", { total: 24, fifteen: 4, pair: 2, run: 1 }, "Each 7 with each 8 (8), 2 pairs (4), 4 runs of 7-8-9 (12)."],
  ["2S 4H 6D 8C 10S", "hand", { total: 0, used: 0 }, "All even, no 15; gaps, no run; no pairs; mixed suits."],
  ["JH 2C 4D 9S 3H", "hand", { total: 8, fifteen: 2, run: 1, nobs: 1 }, "J+2+3 and 2+4+9 (4), run 2-3-4 (3), his nobs: jack of hearts with a heart starter (1)."],
  ["2S 4H 6D 8C JS", "hand", { total: 0, used: 0 }, "A jack cut as the starter is his heels (pegged at the cut), never his nobs."],
  ["2H 4H 6H 8H KC", "hand", { total: 4, flush: 1, used: 4 }, "Four hearts in hand, starter a club: flush of 4."],
  ["2H 4H 6H 8H KH", "hand", { total: 5, flush: 1 }, "Five hearts: flush of 5."],
  ["2H 4H 6H 8H KC", "crib", { total: 0, used: 0 }, "The crib only scores a flush of 5."],
  ["2H 4H 6H 8H KH", "crib", { total: 5, flush: 1 }, "Five hearts in the crib: flush of 5."],
  ["JD 2C 4D 9S 3D", "crib", { total: 8, fifteen: 2, run: 1, nobs: 1 }, "His nobs counts in the crib too."],
].map(([cards, as, expect, note]) => {
  const c = parse(cards);
  const ji = c.slice(0, 4).findIndex(x => x.r === 11 && x.s === c[4].s);
  const options = { ...(as === "hand" ? HAND : CRIB), ...(ji >= 0 ? { nobs: [ji, 4] } : {}) };
  return { cards, as, options, expect, note };
});

function build(c) {
  const { items, used } = S.count(parse(c.cards), c.options);
  const combos = items.map(i => {
    const out = { kind: i.kind, points: i.pts, cards: i.idx };
    if (i.kind === "run") { out.size = new Set(i.idx.map(k => parse(c.cards)[k].r)).size; out.multiplier = i.pts / out.size; }
    if (i.kind === "pair") out.size = i.idx.length;
    if (i.kind === "flush") out.size = i.idx.length;
    return out;
  });
  const total = combos.reduce((a, x) => a + x.points, 0);
  const n = k => combos.filter(x => x.kind === k).length;
  const e = c.expect, nCards = c.cards.split(/\s+/).length;
  const want = { total: e.total, fifteen: e.fifteen || 0, pair: e.pair || 0, run: e.run || 0, flush: e.flush || 0, nobs: e.nobs || 0, used: e.used ?? nCards };
  const got = { total, fifteen: n("fifteen"), pair: n("pair"), run: n("run"), flush: n("flush"), nobs: n("nobs"), used: used.size };
  if (JSON.stringify(want) !== JSON.stringify(got)) throw new Error(`${c.cards}: hand ${JSON.stringify(want)} vs counter ${JSON.stringify(got)}`);
  const leftOver = [...Array(nCards).keys()].filter(i => !used.has(i));
  const out = { cards: c.cards };
  if (c.as) out.as = c.as;
  return { ...out, options: c.options, total, combos, leftOver, note: c.note };
}

const fmt = (o) => JSON.stringify(o, null, 2).replace(/\[\s*([^\[\]{}]*?)\s*\]/g, (_, inner) => "[" + inner.replace(/\s*\n\s*/g, " ") + "]")
  .replace(/\{\s*("kind"[^{}]*?)\s*\}/g, (_, inner) => "{ " + inner.replace(/\s*\n\s*/g, " ") + " }") + "\n";
const about = "engine.md › Counting a set. Cards are in fixture notation; options are the count options; combos come in count order with card indexes ascending; leftOver lists the indexes in no combo. Totals and combo counts were worked out by hand (see note).";
fs.writeFileSync(path.join(__dirname, "counting.json"), fmt({ version: 1, about, scoring: { fifteen: 2, pair: 2, runPerCard: 1, flushPerCard: 1, nobs: 1 }, cases: counting.map(build) }));
fs.writeFileSync(path.join(__dirname, "classic-hands.json"), fmt({ version: 1, about: about + " Classic hands: the hand or crib's four cards, then the starter (index 4); options are classic.json › show, with nobs set when a hand jack matches the starter's suit.", cases: classic.map(build) }));
console.log("wrote", counting.length, "counting cases and", classic.length, "classic hands");
