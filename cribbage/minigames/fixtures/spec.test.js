// Spec drift check (PORTING.md › Keeping the spec true). The engine spec is what a port is
// built from, so it MUST name every action and event the Swift engine writes, with their
// fields, and show every config file's shape. Run: node --test cribbage/minigames/
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..', '..', '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const spec = read('cribbage/minigames/engine.md');
const matchTurn = read('swift/Sources/CribMaze/MatchTurn.swift');
const game = read('swift/Sources/CribMaze/CribMazeGame.swift');

// Splits text on commas at bracket depth 0.
function topLevel(text) {
  const out = []; let depth = 0, cur = '';
  for (const ch of text) {
    if ('([{<'.includes(ch)) depth++;
    if (')]}>'.includes(ch)) depth--;
    if (ch === ',' && depth === 0) { out.push(cur); cur = ''; } else cur += ch;
  }
  if (cur.trim()) out.push(cur);
  return out.map((s) => s.trim());
}

// The cases of a Swift enum: [{name, labels}], from `case a(x: T, y: U), b` lines.
function enumCases(source, header) {
  const start = source.indexOf(header);
  assert.ok(start >= 0, `can't find ${header}`);
  const open = source.indexOf('{', start);
  let depth = 0, end = open;
  for (; end < source.length; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}' && --depth === 0) break;
  }
  const body = source.slice(open + 1, end);
  const cases = [];
  for (const line of body.split('\n')) {
    const m = line.match(/^\s*case\s+(.*)$/);
    if (!m) continue;
    for (const decl of topLevel(m[1])) {
      const d = decl.match(/^(\w+)(?:\((.*)\))?$/s);
      if (!d) continue;
      const labels = d[2] ? topLevel(d[2]).map((p) => p.split(':')[0].trim()) : [];
      cases.push({ name: d[1], labels });
    }
  }
  return cases;
}

// The text of a section, from its heading to the next heading of the same level or higher.
function section(heading) {
  const level = heading.match(/^#+/)[0].length;
  const lines = spec.split('\n');
  const start = lines.indexOf(heading);
  assert.ok(start >= 0, `engine.md has no "${heading}"`);
  let end = start + 1;
  while (end < lines.length && !(lines[end].match(/^#+ /) && lines[end].match(/^#+/)[0].length <= level)) end++;
  return lines.slice(start, end);
}

// The spec's text about a name in a section: its table row, or the line naming it with its fields.
function specLine(name, heading) {
  const lines = section(heading);
  return lines.find((l) => l.startsWith(`| \`${name}\` |`))
    || lines.find((l) => l.includes(`\`${name}\` (`));
}

function checkCases(cases, what, heading) {
  for (const { name, labels } of cases) {
    const line = specLine(name, heading);
    assert.ok(line, `engine.md › ${heading.replace(/^#+ /, '')} has no row for the ${what} \`${name}\``);
    for (const label of labels) {
      assert.ok(new RegExp(`\\b${label}\\b`).test(line), `engine.md › \`${name}\` doesn't name its field ${label}`);
    }
  }
}

test('every match turn event is in the spec, with its fields', () => {
  checkCases(enumCases(matchTurn, 'public enum MatchEvent'), 'event', '## Events');
});

test('every match turn action is in the spec, with its fields', () => {
  checkCases(enumCases(matchTurn, 'public enum MatchAction'), 'action', '## Actions');
});

test("every game action and event is in the spec, with its fields", () => {
  const coding = game.slice(game.indexOf('// MARK: - Coding'));
  const action = coding.slice(coding.indexOf('extension CribMazeGame.Action'));
  const event = coding.slice(coding.indexOf('extension CribMazeGame.Event'));
  checkCases(enumCases(action, 'private enum Own'), 'game action', '### The game as steps');
  checkCases(enumCases(event, 'private enum Own'), 'game event', '## Events');
});

// Every object key path in a JSON value: "match.edgePower.capPercent".
function keyPaths(value, prefix = '') {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return [];
  return Object.keys(value).flatMap((k) => {
    const p = prefix ? `${prefix}.${k}` : k;
    return [p, ...keyPaths(value[k], p)];
  });
}

test("the spec's config examples have the config files' shape", () => {
  const blocks = [...spec.matchAll(/^### (\w+\.json)\n[\s\S]*?```json\n([\s\S]*?)```/gm)];
  assert.ok(blocks.length >= 4, 'engine.md › Config shows too few files');
  for (const [, file, json] of blocks) {
    const shown = new Set(keyPaths(JSON.parse(json)));
    const actual = new Set(keyPaths(JSON.parse(read(`cribbage/minigames/config/${file}`))));
    const missing = [...actual].filter((k) => !shown.has(k));
    const extra = [...shown].filter((k) => !actual.has(k));
    assert.deepStrictEqual({ missing, extra }, { missing: [], extra: [] }, `engine.md › ${file} is out of step with config/${file}`);
  }
});

test("the spec's status names the current rules version", () => {
  const rules = JSON.parse(read('cribbage/minigames/config/rules.json'));
  const r = rules.rulesVersion.replace(/^match-/, '');
  const status = spec.split('\n').find((l) => l.startsWith('Status:'));
  assert.ok(new RegExp(`\\b${r}\\b`).test(status), `engine.md's status line should cover ${r}: ${status}`);
});
