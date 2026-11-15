// Neon look checks: contrast rules and that the JSON for the app is current.
// Run: node --test design/neon/
const test = require("node:test"), assert = require("node:assert");
const fs = require("fs"), path = require("path");
const { P, contrast, SHAPES } = require("./neon-core.js");
const cards = require("./neon-cards.js");
const maze = require("./neon-maze.js");
const { build } = require("./export.js");

test("suits and joker colours reach 4.5:1 on the card face", () => {
  for (const [k, c] of Object.entries({ ...P.suit, ...P.joker, gold: P.gold, cyan: P.cyan, muted: P.muted }))
    assert.ok(contrast(c, P.face) >= 4.5, `${k} ${c} is ${contrast(c, P.face).toFixed(2)}:1`);
});
test("maze lines, pieces and tokens reach 3:1 on the screen", () => {
  for (const [k, c] of Object.entries({ cyan: P.cyan, magenta: P.magenta, gold: P.gold, door: P.door, ...P.suit, t0: P.tokens[0], t1: P.tokens[1], t2: P.tokens[2] }))
    assert.ok(contrast(c, P.bg) >= 3, `${k} ${c} is ${contrast(c, P.bg).toFixed(2)}:1`);
});
test("numbers on door badges and the screen reach 4.5:1", () => {
  for (const c of [P.door, P.gold, P.text]) assert.ok(contrast(c, P.bg) >= 4.5);
});
test("every card renders without gaps", () => {
  const all = [];
  for (const s of "SHDC") for (const r of cards.RANKS) for (const form of ["standard", "abbrev"]) all.push(cards.front({ rank: r, suit: s, form }));
  all.push(cards.back(), cards.joker("amber"), cards.joker("teal"), cards.special("swap"), cards.special("bomb"), cards.extra("title"), cards.extra("blank"),
    cards.prize("steps"), cards.prize("item"), cards.prize("none"), ...Object.keys(cards.ITEMS).map(k => cards.itemIcon(k)));
  for (const svg of all) assert.ok(!/undefined|NaN/.test(svg), svg.slice(0, 120));
});
test("every shape has path data", () => {
  for (const [k, parts] of Object.entries(SHAPES)) for (const p of parts) {
    assert.match(p.d, /^M/, k); assert.ok(p.mode === "fill" || p.mode === "stroke", k);
    if (p.tint !== "main") assert.ok(typeof P[p.tint] === "string", `${k} tint ${p.tint}`);
  }
});
test("maze pieces render", () => {
  const s = maze.door(10, 10, 55, true, 7) + maze.gate(10, 10, 55, false, "S") + maze.token(5, 5, 55, { who: 2 }) + maze.pointer(0, 0, 45, "G", 40);
  assert.ok(!/undefined|NaN/.test(s));
});
test("palette.json and shapes.json are current (run node design/neon/export.js)", () => {
  for (const [f, s] of Object.entries(build())) assert.strictEqual(fs.readFileSync(path.join(__dirname, f), "utf8"), s, f);
});
