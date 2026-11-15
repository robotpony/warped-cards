// Tests for jokers.js: tables add up, rolls land where the chances say, and the
// "at least once" maths. Run: node --test cribbage/minigames/mocks/

const test = require("node:test");
const assert = require("node:assert/strict");
const J = require("./jokers.js");

test("every table adds up to 100, and every kind and outcome is defined", () => {
  for (const [kind, table] of Object.entries(J.TABLES)) {
    assert.equal(J.total(table), 100, kind);
    assert.ok(J.KINDS[kind], kind);
    for (const o of table) {
      const oc = J.OUTCOMES[o.id];
      assert.ok(oc, `${kind} ${o.id}`);
      assert.ok(["quiet", "glint", "burst"].includes(oc.tier), `${o.id} tier`);
      assert.ok(["board", "stock", "tray", "steps"].includes(oc.goes), `${o.id} goes`);
    }
  }
});

test("rolls land on the right outcome at the edges", () => {
  const amber = J.TABLES.amber; // 90 card, 9 scoring, 1 item
  assert.equal(J.roll(amber, 0), "card");
  assert.equal(J.roll(amber, 0.8999), "card");
  assert.equal(J.roll(amber, 0.90), "scoring");
  assert.equal(J.roll(amber, 0.9899), "scoring");
  assert.equal(J.roll(amber, 0.99), "item");
  assert.equal(J.roll(amber, 0.999999), "item");
});

test("100,000 rolls match the chances within half a percent", () => {
  for (const [kind, table] of Object.entries(J.TABLES)) {
    const r = J.rng(42), n = 100000, seen = {};
    for (let i = 0; i < n; i++) { const o = J.roll(table, r()); seen[o] = (seen[o] || 0) + 1; }
    for (const o of table) assert.ok(Math.abs(seen[o.id] / n * 100 - o.pct) < 0.5, `${kind} ${o.id}: ${seen[o.id] / n * 100}%`);
  }
});

test("scoring cards are 5s and 10-value cards", () => {
  assert.deepEqual([1, 4, 5, 6, 9, 10, 11, 12, 13].filter(r => J.isScoring({ r })), [5, 10, 11, 12, 13]);
});

test("chance of at least once", () => {
  assert.equal(J.atLeastOnce(100, 1), 1);
  assert.ok(Math.abs(J.atLeastOnce(1, 16) - 0.1486) < 0.001); // 1 - 0.99^16
  assert.ok(Math.abs(J.atLeastOnce(5, 16) - 0.5599) < 0.001); // 1 - 0.95^16
});
