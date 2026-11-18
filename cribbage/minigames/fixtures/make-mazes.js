// Writes mazes.json from the reference maze generator, the browser mock's own (mocks/maze-board.html,
// v12), run with config/maze.json's board numbers. Every port MUST build these mazes exactly
// (engine.md › The maze › The board). Rerun only when the generator or maze.json's board changes, and
// say so in the commit. Run: node cribbage/minigames/fixtures/make-mazes.js
const fs = require("fs");
const path = require("path");

/// The mock's generator, cut from the page: makeMaze and the helpers it calls.
function mockGenerator() {
  global.window = global.window || {};
  const D = require("../mocks/dice.js");
  const html = fs.readFileSync(path.join(__dirname, "../mocks/maze-board.html"), "utf8");
  const src = html.slice(html.indexOf("  function makeMaze("), html.indexOf("  // ---------- Cost to the goal"));
  const SUITS = ["S", "H", "D", "C"], DIRS = [[0, -1], [1, 0], [0, 1], [-1, 0]];
  return new Function("D", "SUITS", "DIRS", src + "\nreturn { makeMaze, liveExits };")(D, SUITS, DIRS);
}

/// One seed's maze, in the fixture's shape.
function maze(gen, seed, board) {
  const c = { length: board.length, doors: board.doors, doorBase: board.doorBase, doorStep: board.doorStep, variants: board.shortcuts, minLoop: board.minLoop, switches: board.switches };
  const M = gen.makeMaze(BigInt(seed), c, null);
  const pair = (k) => k.split(":").map(Number);
  const doors = [];
  for (const [k, e] of M.edges) if (e.kind === "door") doors.push({ cells: pair(k), strength: e.strength, suit: e.suit, variant: !!e.variant, shortcut: !!e.shortcut });
  doors.sort((a, b) => a.cells[0] - b.cells[0] || a.cells[1] - b.cells[1]);
  const kind = (v) => !v.door ? "shortcut" : v.kind.startsWith("round a door") ? "round_door" : "round_free";
  const arrows = [];
  for (let i = 0; i < M.N; i++) if (gen.liveExits(M, i).length >= 2) arrows.push([i, M.ptr[i]]);
  return {
    seed: String(seed), size: M.W, start: M.start, goal: M.goal, route: M.route, doors,
    variants: M.variants.map((v) => ({ door: v.door, from: v.from, to: v.to, len: v.len, span: v.span, kind: kind(v) })),
    switches: M.switches.map((s) => [pair(s.a), pair(s.b)]), stars: [...M.prizes], arrows,
  };
}

const seeds = [1, 2, 3, 7, 42];
if (require.main === module) {
  const board = JSON.parse(fs.readFileSync(path.join(__dirname, "../config/maze.json"), "utf8")).board;
  const gen = mockGenerator();
  const out = {
    version: 1,
    about: "engine.md › The maze › The board. One maze per seed, from config/maze.json's board, made by make-mazes.js from the mock's generator. Cells are y × size + x, y down; doors are by their two cells, lower first, in cell order; switches are [golden passage, wall]; stars in the order placed; arrows are [cell, direction] for every cell with 2 or more exits that aren't pockets (0 up, 1 right, 2 down, 3 left).",
    cases: seeds.map((s) => maze(gen, s, board)),
  };
  fs.writeFileSync(path.join(__dirname, "mazes.json"), JSON.stringify(out) + "\n");
  console.log(`wrote mazes.json: ${seeds.length} mazes`);
}
module.exports = { mockGenerator, maze };
