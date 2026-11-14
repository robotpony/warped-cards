// Crib Maze: shared scoring for the mocks (2026-11-14).
//
// Works for sets of any size (2 to 7 cards and more), so long runs and big
// fifteens from small cards count correctly. Tests: scoring.test.js.
//
// Counts a set of cards the way a cribbage hand is counted, and lists every
// combo separately with the cards it uses, in the order a player says them
// aloud: fifteens, pairs, runs, flush, his nobs. The match turn uses this to
// score; the score breakdown mock uses it to animate each part.
//
// Plain script (no modules) so the mocks open straight from disk.

(function () {
  const window = typeof globalThis.window !== "undefined" ? globalThis.window : globalThis;
  const val = (c) => Math.min(c.r, 10);
  const RUN_NAMES = { 1: "Run", 2: "Double run", 3: "Triple run", 4: "Double double run" };
  const PAIR_NAMES = { 2: "Pair", 3: "Pair royal", 4: "Double pair royal" };

  // cards: [{ r: 1..13, s: "S"|"H"|"D"|"C" }]
  // o: { flushMin: 4 or 5, flush4: true to allow a 4-card flush in the first four
  //      (a classic hand), nobs: [starterIndex, jackIndex] or null }
  // Returns { items: [{ kind, name, pts, idx }], used: Set of card indexes in a combo }.
  function count(cards, o) {
    o = o || { flushMin: 4 };
    const n = cards.length, items = [], used = new Set();
    const add = (kind, name, pts, idx) => { items.push({ kind, name, pts, idx: [...idx] }); idx.forEach(i => used.add(i)); };

    // Fifteens: every subset of 2 or more cards that adds to 15, each one separately.
    for (let m = 1; m < (1 << n); m++) {
      let sum = 0; const idx = [];
      for (let i = 0; i < n; i++) if (m >> i & 1) { sum += val(cards[i]); idx.push(i); }
      if (sum === 15 && idx.length >= 2) add("fifteen", "Fifteen", 2, idx);
    }
    // Pairs, grouped by rank.
    const byRank = {};
    cards.forEach((c, i) => (byRank[c.r] = byRank[c.r] || []).push(i));
    for (const idx of Object.values(byRank)) if (idx.length >= 2)
      add("pair", PAIR_NAMES[idx.length], [0, 0, 2, 6, 12][idx.length], idx);
    // Runs of 3 or more distinct ranks; repeated ranks make double runs.
    const ranks = Object.keys(byRank).map(Number).sort((a, b) => a - b);
    let run = null;
    for (let i = 0; i < ranks.length;) {
      let j = i;
      while (j + 1 < ranks.length && ranks[j + 1] === ranks[j] + 1) j++;
      if (j - i + 1 >= 3) run = ranks.slice(i, j + 1);
      i = j + 1;
    }
    if (run) {
      const mult = run.reduce((a, r) => a * byRank[r].length, 1);
      add("run", `${RUN_NAMES[mult] || mult + " runs"} of ${run.length}`, mult * run.length, run.flatMap(r => byRank[r]));
    }
    // Flush: o.flushMin cards or more, all one suit.
    if (n >= o.flushMin && cards.every(c => c.s === cards[0].s)) add("flush", `Flush of ${n}`, n, cards.map((_, i) => i));
    else if (o.flush4 && n === 5 && cards.slice(0, 4).every(c => c.s === cards[0].s)) add("flush", "Flush of 4", 4, [0, 1, 2, 3]);
    // His nobs: a hand or crib jack with the starter, same suit.
    if (o.nobs) add("nobs", "His nobs", 1, o.nobs);
    return { items, used };
  }

  // A short headline for the set: its biggest combo that isn't a fifteen,
  // or the fifteens when that's all there is.
  function headline(items) {
    const f = items.filter(i => i.kind === "fifteen").length;
    const rest = items.filter(i => i.kind !== "fifteen").sort((a, b) => b.pts - a.pts);
    const fifteens = f === 1 ? "Fifteen" : f ? `${["", "", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"][f] || f} fifteens` : "";
    if (!rest.length) return fifteens;
    return rest[0].name;
  }

  // A single is a set worth exactly one combo (7-8: one fifteen). A multi holds
  // two or more (4-5-6: a fifteen and a run). Returns { type, combos } or null.
  function kind(items) {
    if (!items.length) return null;
    return { type: items.length === 1 ? "single" : "multi", combos: items.length };
  }

  // The suit a set's steps carry at suit gates: the suit that appears most often
  // among its cards. A tie for most means no suit (null). Rules: rules.md › Suit gates.
  function suitOf(cards) {
    const n = {};
    cards.forEach(c => n[c.s] = (n[c.s] || 0) + 1);
    const most = Math.max(...Object.values(n)), top = Object.keys(n).filter(s => n[s] === most);
    return top.length === 1 ? top[0] : null;
  }

  if (typeof module !== "undefined") module.exports = { val, count, headline, kind, suitOf };
  window.WarpedScore = { val, count, headline, kind, suitOf };
})();
