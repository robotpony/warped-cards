// Checks the shared fixtures and config files against the JS references.
// Run: node --test cribbage/minigames/
// The Swift tests read the same files (engine.md › Fixtures).

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const S = require("../mocks/scoring.js");
const D = require("../mocks/dice.js");

const read = (...p) => JSON.parse(fs.readFileSync(path.join(__dirname, ...p), "utf8"));
const RANKS = { A: 1, J: 11, Q: 12, K: 13 };
const parse = (t) => { const m = t.match(/^(10|[2-9AJQK])([SHDC])$/); return { r: RANKS[m[1]] || +m[1], s: m[2] }; };
const cards = (text) => text.split(/\s+/).map(parse);

test("dice.json matches the reference dice", () => {
  const f = read("dice.json");
  for (const [text, h] of f.vectors.fnv1a64) assert.equal(D.fnv1a64(text).toString(), h);
  for (const c of f.cases) {
    const raw = D.stream(BigInt(c.seed), c.stream);
    assert.deepEqual(c.first64, [1, 2, 3, 4].map(() => raw.next64().toString()), `${c.seed} ${c.stream}`);
    const s = D.stream(BigInt(c.seed), c.stream);
    assert.deepEqual(c.below.values, c.below.n.map(n => s.below(n, "test")));
    const s2 = D.stream(BigInt(c.seed), c.stream);
    assert.deepEqual(c.pick, c.pick.map(() => s2.pick(f.weights, "test")));
    assert.deepEqual([...c.shuffle52].sort((a, b) => a - b), [...Array(52).keys()]);
  }
});

for (const file of ["counting.json", "classic-hands.json"]) test(`${file} matches the counter`, () => {
  for (const c of read(file).cases) {
    const { items, used } = S.count(cards(c.cards), c.options);
    assert.deepEqual(items.map(i => [i.kind, i.pts, i.idx]), c.combos.map(x => [x.kind, x.points, x.cards]), c.cards);
    assert.equal(items.reduce((a, i) => a + i.pts, 0), c.total, c.cards);
    assert.deepEqual([...Array(c.cards.split(" ").length).keys()].filter(i => !used.has(i)), c.leftOver, c.cards);
  }
});

// A reference play (engine.md › Classic cribbage › The play), just enough to check the fixture.
function peg(players, dealer, hands, plays, cfg) {
  const val = (c) => Math.min(c.r, 10);
  const held = hands.map(h => [...h]), out = [], totals = Array(players).fill(0);
  let seat = (dealer + 1) % players, count = 0, run = [], last = null;
  const score = (s, kind, pts) => { totals[s] += pts; return [kind, pts]; };
  const canPlay = (s) => held[s].some(t => count + val(parse(t)) <= cfg.maxCount);
  for (const t of plays) {
    // Skip seats that can't play; when nobody can, the last player scores the go.
    for (;;) {
      if (held.every((_, s) => !canPlay(s))) {
        totals[last] += cfg.go; out.push({ seat: last, go: cfg.go, count });
        count = 0; run = []; seat = (last + 1) % players;
      } else if (!canPlay(seat)) seat = (seat + 1) % players;
      else if (held[seat].includes(t)) break;
      else throw new Error(`out of turn: ${t}, seat ${seat} to play`);
    }
    const c = parse(t);
    held[seat].splice(held[seat].indexOf(t), 1);
    count += val(c); run.push(c); last = seat;
    const sc = [];
    if (count === 15) sc.push(score(seat, "fifteen", cfg.fifteen));
    if (count === cfg.maxCount) sc.push(score(seat, "thirty_one", cfg.thirtyOne));
    let k = 1; while (k < run.length && run[run.length - 1 - k].r === c.r) k++;
    if (k >= 2) sc.push(score(seat, "pair", cfg.pair * k * (k - 1) / 2));
    for (let n = run.length; n >= 3; n--) {
      const rs = run.slice(-n).map(x => x.r).sort((a, b) => a - b);
      if (rs.every((r, i) => i === 0 || r === rs[i - 1] + 1)) { sc.push(score(seat, "run", cfg.runPerCard * n)); break; }
    }
    const done = held.every(h => !h.length);
    if (done && count !== cfg.maxCount) sc.push(score(seat, "last_card", cfg.lastCard));
    if (sc.length) out.push({ seat, card: t, count, scores: sc });
    if (count === cfg.maxCount) { count = 0; run = []; }
    seat = (seat + 1) % players;
  }
  return { out, totals };
}

test("pegging.json plays out as worked by hand", () => {
  const cfg = read("..", "config", "classic.json").peg;
  for (const c of read("pegging.json").cases) {
    const { out, totals } = peg(c.players, c.dealer, c.hands, c.plays, cfg);
    assert.deepEqual(out, c.expect, c.note);
    assert.deepEqual(totals, c.totals, c.note);
  }
});

test("config files pass the load checks", () => {
  const rules = read("..", "config", "rules.json"), jokers = read("..", "config", "jokers.json");
  const bots = read("..", "config", "bots.json"), classic = read("..", "config", "classic.json");
  const weights = (list) => list.forEach(([, w]) => assert.ok(Number.isInteger(w) && w > 0));
  for (const f of [rules, jokers, bots, classic, read("..", "config", "timing.json")]) assert.ok(Number.isInteger(f.version));
  weights(rules.match.prize.special); weights(jokers.kinds);
  rules.match.prize.special.forEach(([k]) => assert.ok(rules.specials.known.includes(k)));
  assert.ok(rules.match.prize.epicAt >= rules.match.prize.rareAt);
  assert.ok(jokers.perRound.min <= jokers.perRound.max);
  for (const [kind, table] of Object.entries(jokers.tables)) {
    weights(table);
    assert.ok(jokers.kinds.some(([k]) => k === kind) || jokers.extras.includes(kind), kind);
    table.forEach(([o]) => assert.ok(jokers.outcomes[o], o));
  }
  for (const d of classic.deal) assert.equal(d.toCrib + d.players * d.discard, 4, "crib holds 4");
  assert.ok(bots.match.length && bots.classic.length);
});

test("mazes.json is the mock generator's mazes", () => {
  const { mockGenerator, maze } = require("./make-mazes.js");
  const board = read("..", "config", "maze.json").board, gen = mockGenerator();
  for (const c of read("mazes.json").cases) assert.deepEqual(maze(gen, Number(c.seed), board), c, `seed ${c.seed}`);
});
