// Tests for scoring.js: straights and fifteens with small cards, singles and
// multis, and sets longer than 5 cards. Run: node --test cribbage/minigames/mocks/
// Expected counts are worked out by hand (shown in each comment), not by the code.

const test = require("node:test");
const assert = require("node:assert/strict");
const S = require("./scoring.js");

const RANKS = { A: 1, J: 11, Q: 12, K: 13 };
// "A 2 3" or with suits "2H 3H"; cards without a suit get mixed suits so no flush forms.
function cards(text) {
  return text.split(/\s+/).map((t, i) => {
    const m = t.match(/^(10|[2-9AJQK])([SHDC])?$/);
    if (!m) throw new Error("bad card " + t);
    return { r: RANKS[m[1]] || +m[1], s: m[2] || "SHDC"[i % 4] };
  });
}
function score(text, o) {
  const { items, used } = S.count(cards(text), o || { flushMin: 4 });
  const by = (k) => items.filter(i => i.kind === k);
  return {
    total: items.reduce((a, i) => a + i.pts, 0),
    fifteens: by("fifteen").length,
    runs: by("run").map(i => i.name + " " + i.pts),
    pairs: by("pair").map(i => i.name),
    flush: by("flush").map(i => i.pts)[0] || 0,
    kind: S.kind(items),
    used: used.size,
  };
}

test("straights with small cards", () => {
  // A-2-3: run of 3 (3). Sum 6, no fifteen.
  assert.deepEqual(score("A 2 3").runs, ["Run of 3 3"]);
  assert.equal(score("A 2 3").total, 3);
  // A-2-3-4: run of 4 (4). Sum 10.
  assert.equal(score("A 2 3 4").total, 4);
  // A-2-3-4-5: run of 5 (5) + all five make 15 (2) = 7.
  const r5 = score("A 2 3 4 5");
  assert.deepEqual([r5.runs, r5.fifteens, r5.total], [["Run of 5 5"], 1, 7]);
  // A-2-4: a gap, no run, no fifteen, nothing.
  assert.equal(score("A 2 4").total, 0);
  assert.equal(score("A 2 4").kind, null);
  // Order doesn't matter: 3-A-2 is still a run of 3.
  assert.equal(score("3 A 2").total, 3);
});

test("double runs with small cards", () => {
  // A-A-2-3: double run of 3 (6) + pair (2) = 8. Sum 7.
  const d = score("A A 2 3");
  assert.deepEqual([d.runs, d.pairs, d.total], [["Double run of 3 6"], ["Pair"], 8]);
  // A-2-2-3-3: double double run of 3 (12) + 2 pairs (4) = 16. Sum 11.
  const dd = score("A 2 2 3 3");
  assert.deepEqual([dd.runs, dd.pairs.length, dd.total], [["Double double run of 3 12"], 2, 16]);
  // A-2-2-2-3: triple run of 3 (9) + pair royal (6) = 15. Sum 10.
  const t = score("A 2 2 2 3");
  assert.deepEqual([t.runs, t.pairs, t.total], [["Triple run of 3 9"], ["Pair royal"], 15]);
  // A-2-3-3-4: double run of 4 (8) + pair (2) = 10. Sum 13.
  assert.equal(score("A 2 3 3 4").total, 10);
});

test("fifteens with small cards", () => {
  // 7-8: one fifteen (2).
  assert.deepEqual([score("7 8").fifteens, score("7 8").total], [1, 2]);
  // 8-6-A: 8+6+1 = 15 (2).
  assert.equal(score("8 6 A").total, 2);
  // 2-3-4-6: 2+3+4+6 = 15 (2) + run 2-3-4 (3) = 5.
  assert.deepEqual([score("2 3 4 6").fifteens, score("2 3 4 6").total], [1, 5]);
  // A-4-5-5: 1+4+5+5 = 15 (2) + pair (2) = 4. No other subset makes 15.
  assert.deepEqual([score("A 4 5 5").fifteens, score("A 4 5 5").total], [1, 4]);
  // 5-5-5: 15 (2) + pair royal (6) = 8.
  assert.equal(score("5 5 5").total, 8);
  // 5-5-5-10: 5+5+5, and 10 with each 5 (3) = 4 fifteens (8) + pair royal (6) = 14.
  assert.deepEqual([score("5 5 5 10").fifteens, score("5 5 5 10").total], [4, 14]);
  // 7-7-8-8: each 7 with each 8 = 4 fifteens (8) + 2 pairs (4) = 12.
  assert.deepEqual([score("7 7 8 8").fifteens, score("7 7 8 8").total], [4, 12]);
  // Face cards count 10: K-5 is a fifteen, K-Q-J is a run of 3. K-Q-J-5: 3 fifteens (6) + run (3) = 9.
  assert.deepEqual([score("K Q J 5").fifteens, score("K Q J 5").total], [3, 9]);
});

test("sets longer than 5 cards", () => {
  // A-2-3-4-5-6: run of 6 (6). Fifteens are the complements of subsets making 6
  // ({6}, {1,5}, {2,4}, {1,2,3}): 4 fifteens (8). Total 14.
  const r6 = score("A 2 3 4 5 6");
  assert.deepEqual([r6.runs, r6.fifteens, r6.total], [["Run of 6 6"], 4, 14]);
  // 3 to 9: run of 7 (7). Fifteens: 6+9, 7+8, 3+4+8, 3+5+7, 4+5+6 (no 4-card set is small enough) = 5 (10). Total 17.
  const r7 = score("3 4 5 6 7 8 9");
  assert.deepEqual([r7.runs, r7.fifteens, r7.total], [["Run of 7 7"], 5, 17]);
  // A-A-2-2-3-3: 8 runs of 3 (24) + 3 pairs (6) = 30. Sum 12, no fifteen.
  const big = score("A A 2 2 3 3");
  assert.deepEqual([big.runs, big.total], [["8 runs of 3 24"], 30]);
  // A-2-3-4-5-6-7 hearts: run of 7 (7) and flush of 7 (7). Its fifteens are counted in the next test.
  const f7 = score("AH 2H 3H 4H 5H 6H 7H");
  assert.equal(f7.flush, 7);
  assert.deepEqual(f7.runs, ["Run of 7 7"]);
});

test("fifteens from 1 to 7 count by hand", () => {
  // Subsets of {1..7} that make 15, listed by hand:
  // 2 cards: none (max 6+7 = 13).
  // 3 cards: 1+7+7 no; 2+6+7, 3+5+7, 4+5+6 = 3.
  // 4 cards: 1+2+5+7, 1+3+4+7, 1+3+5+6, 2+3+4+6, 1+2+... (1+2+6+6 no) = 4.
  // 5 cards: 1+2+3+4+5 = 1.
  // Total 8.
  assert.equal(score("A 2 3 4 5 6 7").fifteens, 8);
});

test("singles and multis", () => {
  assert.deepEqual(score("7 8").kind, { type: "single", combos: 1 });
  assert.deepEqual(score("5 5").kind, { type: "single", combos: 1 });
  assert.deepEqual(score("A 2 3").kind, { type: "single", combos: 1 });
  assert.deepEqual(score("4 5 6").kind, { type: "multi", combos: 2 }); // fifteen + run
  assert.deepEqual(score("7 8 8").kind, { type: "multi", combos: 3 }); // 2 fifteens + pair
  assert.deepEqual(score("2H 3H 4H 6H").kind, { type: "multi", combos: 3 }); // fifteen + run + flush
});

test("every card must be part of a combo", () => {
  // 5-5-K-2: the 2 is in nothing (5+5 = 10, K+5 = 15 twice, pair). 3 of 4 cards used.
  assert.equal(score("5 5 K 2").used, 3);
  assert.equal(score("A 2 3 4 5").used, 5);
});

test("flushes and his nobs", () => {
  // Flush needs 4 or more in a set (flushMin 4): 2H 3H 4H 6H = fifteen (2) + run (3) + flush (4) = 9.
  assert.equal(score("2H 3H 4H 6H").total, 9);
  assert.equal(score("2H 3H 4H").flush, 0);
  // Classic hand flush: 4 in hand, starter (last) a different suit, flush4 on = 4.
  assert.equal(score("2H 4H 6H 8H KS", { flushMin: 5, flush4: true }).flush, 4);
  // His nobs: starter (index 0) and the jack of its suit (index 1): +1.
  const n = S.count(cards("5S JS"), { flushMin: 4, nobs: [0, 1] });
  assert.deepEqual(n.items.map(i => i.name), ["Fifteen", "His nobs"]);
});
