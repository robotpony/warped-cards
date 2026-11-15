// Crib Maze: the maze's tiles and icons, drawn as SVG strings (2026-11-14).
//
// Shared by the maze walk mock (maze-walk.html) and the style guide
// (maze-tiles.html), so what we tune in the guide is what the walk shows.
// Every function takes the cell size (cs) and scales from it. Visual goals:
// mocks/README.md › Maze walk. Plain script, no modules.

(function () {
  const window = typeof globalThis.window !== "undefined" ? globalThis.window : globalThis;
  const GLYPH = { S: "♠", H: "♥", D: "♦", C: "♣" };

  // The palette. Colours are CSS custom properties set on the page, with these as fallbacks.
  const P = {
    felt: "var(--felt, #0E3B2E)", floor: "var(--floor, rgba(243,236,220,.08))", fog: "var(--fogc, rgba(0,0,0,.4))",
    wall: "var(--wall, #F3ECDC)", cream: "var(--felt-text, #F3ECDC)", gold: "var(--gold, #E8B84A)", ink: "#2B2A26",
    door: "var(--door, #A85A00)", doorDark: "#3B1F00", doorBadge: "#5C3100",
    suit: (s) => `var(--${s})`,
  };
  // Sizes, as fractions of the cell. The style guide can change these live.
  const S = {
    floorInset: 0.03, floorRadius: 0.06,
    wall: 0.09, outerWall: 0.12, wallMin: 3,
    plankThick: 0.18, plankOver: 0.04, badge: 0.2,
    gatePlate: 0.36, token: 0.3, tokenOnStart: 0.22, star: 0.62, label: 0.5,
  };
  const n = (v) => Math.round(v * 10) / 10;

  // One floor tile: the cell's ground, slightly lighter than the gaps between tiles.
  function floor(x, y, cs, fogged) {
    const i = Math.max(1, cs * S.floorInset);
    return `<rect x="${n(x + i)}" y="${n(y + i)}" width="${n(cs - 2 * i)}" height="${n(cs - 2 * i)}" rx="${n(cs * S.floorRadius)}" fill="${fogged ? P.fog : P.floor}"/>`;
  }
  // Walls: a path of wall segments ("M x y h len" or "v len"), and the outer wall.
  const wallWidth = (cs) => Math.max(S.wallMin, cs * S.wall);
  function walls(d, cs) { return `<path d="${d}" stroke="${P.wall}" stroke-width="${n(wallWidth(cs))}" stroke-linecap="round" fill="none"/>`; }
  function outerWall(x, y, w, h, cs) { return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="2" fill="none" stroke="${P.wall}" stroke-width="${n(Math.max(S.wallMin + 1, cs * S.outerWall))}"/>`; }

  // The start: a cream pad filling the cell, marked S when the token isn't on it.
  function start(x, y, cs, label = true) {
    return `<rect x="${n(x + 1)}" y="${n(y + 1)}" width="${cs - 2}" height="${cs - 2}" rx="${n(cs * .14)}" fill="${P.cream}"/>` +
      (label ? text(x + cs / 2, y + cs / 2, "S", cs * S.label, P.ink) : "");
  }
  // The goal: a gold pad with a ring, marked G.
  function goal(x, y, cs) {
    return `<rect x="${n(x - 1)}" y="${n(y - 1)}" width="${cs + 2}" height="${cs + 2}" rx="${n(cs * .2)}" fill="none" stroke="${P.gold}" stroke-width="2" opacity=".6"/>` +
      `<rect x="${n(x + 2)}" y="${n(y + 2)}" width="${cs - 4}" height="${cs - 4}" rx="${n(cs * .14)}" fill="${P.gold}"/>` + text(x + cs / 2, y + cs / 2, "G", cs * S.label, P.ink);
  }
  // A plank across a passage. (mx, my) is the middle of the passage; upright when
  // the two cells sit side by side.
  function plank(mx, my, cs, upright) {
    const long = cs * (1 + 2 * S.plankOver), thick = Math.max(7, cs * S.plankThick);
    return { w: upright ? thick : long, h: upright ? long : thick, long, thick };
  }
  // A door: a wooden plank with its strength left on a badge.
  function door(mx, my, cs, upright, left) {
    const p = plank(mx, my, cs, upright), r = Math.max(8, cs * S.badge);
    const seam = upright ? `M${n(mx)} ${n(my - p.long / 2 + 2)}v${n(p.long - 4)}` : `M${n(mx - p.long / 2 + 2)} ${n(my)}h${n(p.long - 4)}`;
    return `<rect x="${n(mx - p.w / 2)}" y="${n(my - p.h / 2)}" width="${n(p.w)}" height="${n(p.h)}" rx="2" fill="${P.door}" stroke="${P.doorDark}" stroke-width="1.5"/>` +
      `<path d="${seam}" stroke="${P.doorDark}" stroke-width="1" opacity=".6"/>` +
      `<circle cx="${n(mx)}" cy="${n(my)}" r="${n(r)}" fill="${P.doorBadge}" stroke="${P.cream}" stroke-width="1.5"/>` + text(mx, my, String(left), r * 1.1, "#fff");
  }
  // A broken door: stubs of the frame stay at each end.
  function brokenDoor(mx, my, cs, upright) {
    const p = plank(mx, my, cs, upright), a = p.thick, b = p.thick * .6;
    const st = upright ? [[mx - a / 2, my - p.long / 2, a, b], [mx - a / 2, my + p.long / 2 - b, a, b]] : [[mx - p.long / 2, my - a / 2, b, a], [mx + p.long / 2 - b, my - a / 2, b, a]];
    return st.map(([x, y, w, h]) => `<rect x="${n(x)}" y="${n(y)}" width="${n(w)}" height="${n(h)}" rx="1" fill="${P.door}"/>`).join("");
  }
  // A suit gate: a cream plate across the passage with the suit on a round badge.
  function gate(mx, my, cs, upright, suit) {
    const p = plank(mx, my, cs, upright), r = cs * S.gatePlate;
    return `<rect x="${n(mx - p.w / 2)}" y="${n(my - p.h / 2)}" width="${n(p.w)}" height="${n(p.h)}" rx="3" fill="${P.cream}" stroke="${P.suit(suit)}" stroke-width="2"/>` +
      `<circle cx="${n(mx)}" cy="${n(my)}" r="${n(r)}" fill="${P.cream}" stroke="${P.suit(suit)}" stroke-width="2"/>` + text(mx, my, GLYPH[suit], r * 1.3, P.suit(suit));
  }
  function prize(x, y, cs) { return text(x + cs / 2, y + cs / 2, "★", cs * S.star, P.gold); }
  // A token. colour defaults to the player's gold; bots get their own.
  function token(cx, cy, cs, opts = {}) {
    return `<circle cx="${n(cx)}" cy="${n(cy)}" r="${n(cs * (opts.small ? S.tokenOnStart : S.token))}" fill="${opts.colour || P.gold}" stroke="${P.ink}" stroke-width="2"/>`;
  }
  // A way to choose at a fork.
  function choice(x, y, cs, cell) {
    return `<g class="choice" data-cell="${cell}"><rect x="${n(x + 3)}" y="${n(y + 3)}" width="${cs - 6}" height="${cs - 6}" rx="${n(cs * .14)}" fill="none" stroke="${P.gold}" stroke-width="3"/><rect x="${x}" y="${y}" width="${cs}" height="${cs}" fill="transparent"/></g>`;
  }
  // The designer's main route line through cell centres.
  function route(points, cells) {
    return `<polyline data-route="${cells.join(",")}" points="${points.map(([x, y]) => `${n(x)},${n(y)}`).join(" ")}" fill="none" stroke="${P.gold}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round" opacity=".35"/>`;
  }
  // An arrow at the edge of the view pointing to something out of sight (the goal).
  function pointer(x, y, angle, label, cs) {
    const r = Math.max(13, cs * .3);
    return `<g transform="translate(${n(x)} ${n(y)})"><circle r="${n(r)}" fill="${P.gold}" stroke="${P.ink}" stroke-width="1.5"/>` +
      `<path d="M0 ${-r - 7}l6 8h-12z" fill="${P.gold}" transform="rotate(${n(angle)})"/>` + text(0, 0, label, r, P.ink) + `</g>`;
  }
  function text(x, y, t, size, fill) {
    return `<text x="${n(x)}" y="${n(y)}" text-anchor="middle" dominant-baseline="central" font-size="${n(size)}" font-weight="700" fill="${fill}">${t}</text>`;
  }

  const api = { P, S, GLYPH, floor, walls, wallWidth, outerWall, start, goal, door, brokenDoor, gate, prize, token, choice, route, pointer, text };
  if (typeof module !== "undefined") module.exports = api;
  window.WarpedMazeArt = api;
})();
