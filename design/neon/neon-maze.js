// Warped Cards, neon look: maze tiles and pieces (v1, 2026-11-14).
//
// The same API as cribbage/minigames/mocks/maze-art.js (window.WarpedMazeArt), plus
// defs(): put A.defs() once inside each maze SVG, since the pieces use its glow
// filter and fog scanlines. Every function takes the cell size (cs) and scales from
// it. Needs neon-core.js first.
//
// Look: glowing cyan walls with a bright core, a magenta outer wall, laser doors,
// suit gates as glowing plates, a play-arrow start and a diamond goal, and tokens told
// apart by shape (player disc, bot square, bot triangle) as well as colour.

(function () {
  const window = typeof globalThis.window !== "undefined" ? globalThis.window : globalThis;
  const N = window.WarpedNeon || (typeof require !== "undefined" ? require("./neon-core.js") : null);
  const { P: C, n, shape, text: ntext, star, poly } = N;
  const GLYPH = { S: "♠", H: "♥", D: "♦", C: "♣" };

  // Colours the walk and the guide may read.
  const P = { bg: C.bg, wall: C.cyan, core: C.core, outer: C.magenta, gold: C.gold, door: C.door, cream: C.text, ink: C.bg, suit: (s) => C.suit[s], tokens: C.tokens };
  // Sizes as fractions of the cell; the style guide can change these live. export.js
  // writes them to palette.json.
  const S = {
    floorInset: 0.03, floorRadius: 0.06, floorOpacity: 0.07, dot: 1.1,
    wall: 0.05, outerWall: 0.07, wallMin: 2.2, coreRatio: 0.35, glow: 2.2,
    laser: 0.07, laserLen: 0.96, badgeW: 0.44, badgeH: 0.3,
    gateBadge: 0.5, gateLine: 2.5, token: 0.25, tokenOnStart: 0.16, star: 0.34, startInset: 0.17,
  };
  const G = `filter="url(#nm-glow)"`;
  const defs = () =>
    `<filter id="nm-glow" filterUnits="userSpaceOnUse" x="-200" y="-200" width="6000" height="6000"><feGaussianBlur stdDeviation="${S.glow}" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>` +
    `<pattern id="nm-scan" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="1.2" fill="#7F9CFF" opacity=".12"/></pattern>`;

  function floor(x, y, cs, fogged) {
    if (fogged) return `<rect x="${n(x)}" y="${n(y)}" width="${cs}" height="${cs}" fill="#03050C"/><rect x="${n(x)}" y="${n(y)}" width="${cs}" height="${cs}" fill="url(#nm-scan)"/>`;
    const i = Math.max(1, cs * S.floorInset);
    return `<rect x="${n(x + i)}" y="${n(y + i)}" width="${n(cs - 2 * i)}" height="${n(cs - 2 * i)}" rx="${n(cs * S.floorRadius)}" fill="#5A82FF" opacity="${S.floorOpacity}"/>` +
      `<circle cx="${n(x)}" cy="${n(y)}" r="${S.dot}" fill="#9AB4FF" opacity=".5"/>`;
  }
  const wallWidth = (cs) => Math.max(S.wallMin, cs * S.wall);
  const neonLine = (d, colour, core, w) =>
    `<path d="${d}" stroke="${colour}" stroke-width="${n(w)}" stroke-linecap="round" stroke-linejoin="round" fill="none" ${G}/>` +
    `<path d="${d}" stroke="${core}" stroke-width="${n(w * S.coreRatio)}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>`;
  function walls(d, cs) { return neonLine(d, C.cyan, C.core, wallWidth(cs)); }
  function outerWall(x, y, w, h, cs) {
    const sw = Math.max(S.wallMin + 1, cs * S.outerWall);
    return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="4" fill="none" stroke="${C.magenta}" stroke-width="${n(sw)}" ${G}/>` +
      `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="4" fill="none" stroke="#FFD6F5" stroke-width="${n(sw * S.coreRatio)}"/>`;
  }

  // The start: a cyan pad with a play arrow (the arrow hides under the token).
  function start(x, y, cs, label = true) {
    const i = cs * S.startInset;
    return `<rect x="${n(x + i)}" y="${n(y + i)}" width="${n(cs - 2 * i)}" height="${n(cs - 2 * i)}" rx="${n(cs * .08)}" fill="${C.cyan}" fill-opacity=".14" stroke="${C.cyan}" stroke-width="2" ${G}/>` +
      (label ? shape("play", x + cs / 2 + cs * .02, y + cs / 2, cs * .36, C.core, G) : "");
  }
  // The goal: a gold diamond portal.
  function goal(x, y, cs) {
    const cx = x + cs / 2, cy = y + cs / 2;
    return `<polygon points="${poly(cx, cy, cs * .44, 4)}" fill="none" stroke="${C.gold}" stroke-width="2" ${G}/>` +
      `<polygon points="${poly(cx, cy, cs * .3, 4)}" fill="none" stroke="${C.gold}" stroke-width="1.5" opacity=".7"/>` +
      `<polygon points="${poly(cx, cy, cs * .16, 4)}" fill="${C.gold}" ${G}/>`;
  }
  function badge(mx, my, cs, t, colour) {
    const w = Math.max(18, cs * (String(t).length > 1 ? S.badgeW : S.badgeW * .72)), h = Math.max(13, cs * S.badgeH);
    return `<rect x="${n(mx - w / 2)}" y="${n(my - h / 2)}" width="${n(w)}" height="${n(h)}" rx="4" fill="${C.bg}" stroke="${colour}" stroke-width="1.5" ${G}/>` +
      ntext(mx, my + 1, t, h * .6, colour);
  }
  const across = (mx, my, cs, upright, len) => upright ? [mx, my - len / 2, mx, my + len / 2] : [mx - len / 2, my, mx + len / 2, my];
  // Emitters at each end of a door's passage; they stay when the door breaks.
  function brokenDoor(mx, my, cs, upright) {
    const L = cs * S.laserLen / 2, e = Math.max(3, cs * .09), t = Math.max(4, cs * .1);
    return [-1, 1].map(s => upright
      ? `<rect x="${n(mx - t / 2)}" y="${n(my + s * L - (s > 0 ? e : 0))}" width="${n(t)}" height="${n(e)}" rx="1" fill="${C.door}" ${G}/>`
      : `<rect x="${n(mx + s * L - (s > 0 ? e : 0))}" y="${n(my - t / 2)}" width="${n(e)}" height="${n(t)}" rx="1" fill="${C.door}" ${G}/>`).join("");
  }
  // A door: a laser barrier with its strength on a badge. The dashes thin out below half.
  function door(mx, my, cs, upright, left, max = 20) {
    const a = across(mx, my, cs, upright, cs * S.laserLen), w = Math.max(3, cs * S.laser);
    return `<line x1="${n(a[0])}" y1="${n(a[1])}" x2="${n(a[2])}" y2="${n(a[3])}" stroke="${C.door}" stroke-width="${n(w)}" stroke-dasharray="${left / max < .5 ? "2 6" : "7 3"}" ${G}/>` +
      `<line x1="${n(a[0])}" y1="${n(a[1])}" x2="${n(a[2])}" y2="${n(a[3])}" stroke="#FFE2CC" stroke-width="${n(w * S.coreRatio)}" stroke-dasharray="${left / max < .5 ? "2 6" : "7 3"}"/>` +
      brokenDoor(mx, my, cs, upright) + badge(mx, my, cs, left, C.door);
  }
  // A suit gate: a line in the suit colour with the suit on a glowing plate.
  function gate(mx, my, cs, upright, suit) {
    const a = across(mx, my, cs, upright, cs * S.laserLen), col = C.suit[suit], s = cs * S.gateBadge;
    return `<line x1="${n(a[0])}" y1="${n(a[1])}" x2="${n(a[2])}" y2="${n(a[3])}" stroke="${col}" stroke-width="${S.gateLine}" ${G}/>` +
      `<rect x="${n(mx - s / 2)}" y="${n(my - s / 2)}" width="${n(s)}" height="${n(s)}" rx="${n(cs * .1)}" fill="${C.bg}" stroke="${col}" stroke-width="2" ${G}/>` +
      shape(suit, mx, my, s * .62, col);
  }
  function prize(x, y, cs) {
    const cx = x + cs / 2, cy = y + cs / 2;
    return `<polygon points="${star(cx, cy, cs * S.star, cs * S.star * .44)}" fill="${C.gold}" fill-opacity=".2" stroke="${C.gold}" stroke-width="2" stroke-linejoin="round" ${G}/>`;
  }
  // A token. opts.who: 0 the player (disc), 1 and 2 bots (square, triangle).
  // opts.colour overrides the colour; with a colour and no who, the shape follows the
  // colour's seat in P.tokens, or a disc.
  function token(cx, cy, cs, opts = {}) {
    let who = opts.who;
    if (who === undefined) { const k = C.tokens.indexOf(opts.colour); who = k < 0 ? 0 : k; }
    const r = cs * (opts.small ? S.tokenOnStart : S.token), col = opts.colour || C.tokens[who];
    const body = who === 0 ? `<circle cx="${n(cx)}" cy="${n(cy)}" r="${n(r)}"`
      : who === 1 ? `<rect x="${n(cx - r * .9)}" y="${n(cy - r * .9)}" width="${n(r * 1.8)}" height="${n(r * 1.8)}" rx="2"`
      : `<polygon points="${poly(cx, cy + r * .15, r * 1.2, 3)}"`;
    return `${body} fill="${col}" stroke="#fff" stroke-width="1.5" stroke-linejoin="round" ${G}/>`;
  }
  function choice(x, y, cs, cell) {
    const i = 4, L = cs * .22; let d = "";
    for (const [ax, ay, sx, sy] of [[x + i, y + i, 1, 1], [x + cs - i, y + i, -1, 1], [x + i, y + cs - i, 1, -1], [x + cs - i, y + cs - i, -1, -1]]) d += `M${n(ax + sx * L)} ${n(ay)}H${n(ax)}V${n(ay + sy * L)}`;
    return `<g class="choice" data-cell="${cell}"><path d="${d}" stroke="${C.cyan}" stroke-width="2.5" fill="none" stroke-linecap="round" ${G}/><rect x="${x}" y="${y}" width="${cs}" height="${cs}" fill="transparent"/></g>`;
  }
  function route(points, cells) {
    return `<polyline data-route="${cells.join(",")}" points="${points.map(([x, y]) => `${n(x)},${n(y)}`).join(" ")}" fill="none" stroke="${C.gold}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round" stroke-dasharray="1 6" opacity=".6"/>`;
  }
  // An arrow at the view's edge pointing to the goal. label is drawn as the goal diamond when "G".
  function pointer(x, y, angle, label, cs) {
    const r = Math.max(13, cs * .3);
    return `<g transform="translate(${n(x)} ${n(y)})"><circle r="${n(r)}" fill="${C.bg}" stroke="${C.gold}" stroke-width="2" ${G}/>` +
      `<path d="M0 ${-r - 8}l6 8h-12z" fill="${C.gold}" transform="rotate(${n(angle)})" ${G}/>` +
      (label === "G" ? shape("goal", 0, 0, r * 1.1, C.gold) : ntext(0, 0, label, r, C.gold)) + `</g>`;
  }
  const text = (x, y, t, size, fill) => ntext(x, y, t, size, fill);

  const api = { P, S, GLYPH, defs, floor, walls, wallWidth, outerWall, start, goal, door, brokenDoor, gate, prize, token, choice, route, pointer, text };
  if (typeof module !== "undefined") module.exports = api;
  window.WarpedNeonMaze = api;
})();
